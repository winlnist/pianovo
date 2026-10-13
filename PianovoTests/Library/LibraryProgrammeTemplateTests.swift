import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct LibraryProgrammeTemplateTests {
    @Test func structureValidationAndLongerStarterPolicies() {
        #expect(LibraryProgrammeDraft().validationIssues == [.nameRequired, .invalidShape])
        var draft = LibraryProgrammeDraft.starter(weekCount: 104)
        draft.name = "Two year structure"
        #expect(draft.validationIssues.isEmpty)
        #expect(draft.weeks.count == 104 && draft.weeks[0].days.count == 7)
        #expect(draft.weeks[0].days[6].isRecovery && draft.weeks[0].days[6].sections.isEmpty)
        #expect(draft.weeks[0].days[0].sections.map(\.name) == ["Morning", "Evening"])
        draft.weeks.append(draft.weeks[0])
        #expect(draft.validationIssues.contains(.duplicateIdentity))
        #expect(draft.validationIssues.contains(.invalidShape))
        draft = ProgrammeFixtures.draft(reference: ProgrammeFixtures.missingReference)
        draft.weeks[0].days[0].sections[0].name = " "
        draft.weeks[0].days[0].sections[0].placements[0].goal = "\n"
        draft.weeks[0].days[0].sections[0].placements[0].minutes = 0
        #expect(draft.validationIssues == [.sectionNameRequired, .goalRequired, .invalidDuration])
    }

    @Test(arguments: [false, true])
    func immutablePinnedVersionsIndependentCopiesAndArchive(swiftData: Bool) async throws {
        let (exercises, programmes) = try repositories(swiftData: swiftData)
        let firstExercise = LibraryFixtures.revision()
        let exercise = try await exercises.apply(.create(firstExercise))
        let first = ProgrammeFixtures.revision(content: ProgrammeFixtures.draft(reference: LibraryExerciseReference(exerciseID: exercise.id, revisionID: firstExercise.id)))
        let template = try await programmes.apply(.create(first))
        #expect(try await programmes.apply(.create(first)) == template)
        let updatedExercise = LibraryFixtures.revision(exerciseID: exercise.id, parent: firstExercise.id, title: "New instructions")
        _ = try await exercises.apply(.revise(updatedExercise, replacing: firstExercise.id))
        _ = try await exercises.apply(.setArchived(exercise.id, expectedRevision: updatedExercise.id, archived: true))
        let copied = first.content.independentCopy()
        #expect(copied.references == first.content.references)
        #expect(copied.weeks[0].id != first.content.weeks[0].id)
        #expect(copied.weeks[0].days[0].sections[0].placements[0].id != first.content.weeks[0].days[0].sections[0].placements[0].id)
        let origin = LibraryProgrammeOrigin(templateID: first.templateID, revisionID: first.id, name: first.content.name, creatorAttribution: nil)
        let copy = ProgrammeFixtures.revision(content: copied, origin: origin)
        let savedCopy = try await programmes.apply(.create(copy))
        #expect(savedCopy.id != template.id)
        var editedContent = first.content
        editedContent.name = "Changed programme"
        let edited = ProgrammeFixtures.revision(templateID: first.templateID, parent: first.id, content: editedContent)
        _ = try await programmes.apply(.revise(edited, replacing: first.id))
        #expect(try await programmes.apply(.revise(edited, replacing: first.id)).currentRevision == edited)
        let stale = ProgrammeFixtures.revision(templateID: first.templateID, parent: first.id, content: first.content)
        await #expect(throws: LibraryRepositoryError.conflict) { try await programmes.apply(.revise(stale, replacing: first.id)) }
        _ = try await programmes.apply(.setArchived(first.templateID, expectedRevision: edited.id, archived: true))
        let illegal = ProgrammeFixtures.revision(templateID: first.templateID, parent: edited.id, content: first.content)
        await #expect(throws: LibraryRepositoryError.archived) { try await programmes.apply(.revise(illegal, replacing: edited.id)) }
        #expect(try await programmes.revisionHistory(for: savedCopy.id) == [copy])
        #expect(try await programmes.revisionHistory(for: first.templateID) == [first, edited])
        let restored = try await programmes.apply(.setArchived(first.templateID, expectedRevision: edited.id, archived: false))
        #expect(!restored.isArchived && restored.currentRevision == edited)
    }

    @Test(arguments: [false, true])
    func rejectsMissingOrMismatchedExerciseVersions(swiftData: Bool) async throws {
        let (exercises, programmes) = try repositories(swiftData: swiftData)
        let first = try await exercises.apply(.create(LibraryFixtures.revision()))
        let reference = LibraryExerciseReference(exerciseID: first.id, revisionID: LibraryRevisionID(rawValue: UUID()))
        await #expect(throws: LibraryProgrammeError.self) {
            try await programmes.apply(.create(ProgrammeFixtures.revision(content: ProgrammeFixtures.draft(reference: reference))))
        }
        let other = try await exercises.apply(.create(LibraryFixtures.revision()))
        let mismatched = LibraryExerciseReference(exerciseID: first.id, revisionID: other.currentRevision.id)
        await #expect(throws: LibraryProgrammeError.self) {
            try await programmes.apply(.create(ProgrammeFixtures.revision(content: ProgrammeFixtures.draft(reference: mismatched))))
        }
        #expect(try await programmes.templates().isEmpty)
    }

    @Test func programmeSaveRollbackAmbiguousRetryAndDurableVerification() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        var before = true
        var after = false
        let repository = SwiftDataLibraryProgrammeRepository(container: container, save: { context in
            if before { throw LibraryTestError() }; try context.save(); if after { throw LibraryTestError() }
        })
        let first = ProgrammeFixtures.revision()
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.create(first)) }
        #expect(try await repository.templates().isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).isEmpty)
        before = false; after = true
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.create(first)) }
        let saved = try await repository.apply(.create(first))
        #expect(saved.currentRevision == first)
        before = true; after = false
        let next = ProgrammeFixtures.revision(templateID: first.templateID, parent: first.id)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.revise(next, replacing: first.id)) }
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.setArchived(first.templateID, expectedRevision: first.id, archived: true)) }
        #expect(try await repository.templates() == [saved])
        #expect(try await repository.revisionHistory(for: first.templateID) == [first])
        let noOp = SwiftDataLibraryProgrammeRepository(container: container, save: { _ in })
        await #expect(throws: LibraryRepositoryError.verificationFailed) { try await noOp.apply(.create(ProgrammeFixtures.revision())) }
        #expect(try await repository.templates() == [saved])
    }

    @Test func v2DiskMigrationRetainsExercisesTemplatesOwnerAndReopensProgrammes() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Library.store")
        let exerciseRevision = LibraryFixtures.revision()
        let nextExercise = LibraryFixtures.revision(exerciseID: exerciseRevision.exerciseID, parent: exerciseRevision.id, title: "Edited exercise")
        let templateRevision = TemplateFixtures.revision()
        let nextTemplate = TemplateFixtures.revision(templateID: templateRevision.templateID, parent: templateRevision.id, name: "Edited template")
        let owner = LibraryOwnerID(rawValue: UUID())
        let exercise = LibraryExercise(id: exerciseRevision.exerciseID, ownerID: owner, currentRevision: nextExercise, isArchived: true)
        let template = LibraryExerciseTemplate(id: templateRevision.templateID, ownerID: owner, currentRevision: nextTemplate, isArchived: true)
        try autoreleasepool {
            // Reproduce the exact 6F.8 container schema and migration plan.
            let schema = Schema(versionedSchema: LibrarySchemaV2.self)
            let config = ModelConfiguration("PianovoLibrary", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, migrationPlan: LegacyV2ProgrammeTestPlan.self, configurations: [config])
            let writer = ModelContext(container); writer.autosaveEnabled = false
            writer.insert(LibrarySchemaV1.IdentityModel(ownerID: owner))
            writer.insert(LibrarySchemaV1.ExerciseModel(exercise))
            writer.insert(try LibrarySchemaV1.RevisionModel(exerciseRevision))
            writer.insert(try LibrarySchemaV1.RevisionModel(nextExercise))
            writer.insert(LibrarySchemaV2.TemplateModel(template))
            writer.insert(try LibrarySchemaV2.TemplateRevisionModel(templateRevision))
            writer.insert(try LibrarySchemaV2.TemplateRevisionModel(nextTemplate))
            try writer.save()
        }
        let current = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        let exercises = SwiftDataLibraryExerciseRepository(container: current)
        let templates = SwiftDataLibraryTemplateRepository(container: current)
        #expect(try await exercises.exercises() == [exercise])
        #expect(try await exercises.revisionHistory(for: exercise.id) == [exerciseRevision, nextExercise])
        #expect(try await templates.templates() == [template])
        #expect(try await templates.revisionHistory(for: template.id) == [templateRevision, nextTemplate])
        let programmes = SwiftDataLibraryProgrammeRepository(container: current)
        let reference = LibraryExerciseReference(exerciseID: exercise.id, revisionID: exerciseRevision.id)
        let saved = try await programmes.apply(.create(ProgrammeFixtures.revision(content: ProgrammeFixtures.draft(reference: reference))))
        #expect(saved.ownerID == owner)
        let reopened = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataLibraryProgrammeRepository(container: reopened).templates() == [saved])
        #expect(try await SwiftDataLibraryExerciseRepository(container: reopened).exercises() == [exercise])
        #expect(try await SwiftDataLibraryTemplateRepository(container: reopened).templates() == [template])
    }

    @Test func invalidShapeDuplicateRevisionAndProvenanceCannotBeOverwritten() async throws {
        let repository = SwiftDataLibraryProgrammeRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true))
        await #expect(throws: LibraryProgrammeError.self) { try await repository.apply(.create(ProgrammeFixtures.revision(content: LibraryProgrammeDraft()))) }
        let first = ProgrammeFixtures.revision()
        let original = try await repository.apply(.create(first))
        let other = try await repository.apply(.create(ProgrammeFixtures.revision()))
        let collision = LibraryProgrammeTemplateRevision(id: first.id, templateID: other.id, parentRevisionID: other.currentRevision.id,
            content: first.content, createdAt: first.createdAt, origin: nil)
        await #expect(throws: LibraryRepositoryError.duplicateID) { try await repository.apply(.revise(collision, replacing: other.currentRevision.id)) }
        let forged = ProgrammeFixtures.revision(templateID: first.templateID, parent: first.id,
            origin: LibraryProgrammeOrigin(templateID: other.id, revisionID: other.currentRevision.id, name: "Invented origin", creatorAttribution: nil))
        await #expect(throws: LibraryRepositoryError.conflict) { try await repository.apply(.revise(forged, replacing: first.id)) }
        #expect(try await repository.revisionHistory(for: original.id) == [first])
    }

    private func repositories(swiftData: Bool) throws -> (any LibraryExerciseRepository, any LibraryProgrammeTemplateRepository) {
        if swiftData {
            let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
            return (SwiftDataLibraryExerciseRepository(container: container), SwiftDataLibraryProgrammeRepository(container: container))
        }
        let exercises = InMemoryLibraryExerciseRepository()
        return (exercises, InMemoryLibraryProgrammeTemplateRepository(exerciseRepository: exercises))
    }
}
nonisolated enum ProgrammeFixtures {
    static var missingReference: LibraryExerciseReference { LibraryExerciseReference(exerciseID: LibraryExerciseID(rawValue: UUID()), revisionID: LibraryRevisionID(rawValue: UUID())) }
    static func draft(reference: LibraryExerciseReference) -> LibraryProgrammeDraft {
        LibraryProgrammeDraft(name: "My programme", weeks: [LibraryProgrammeWeek(id: UUID(), days: [LibraryProgrammeDay(id: UUID(), sections: [
            LibraryProgrammeSection(id: UUID(), name: "Morning", placements: [LibraryProgrammePlacement(id: UUID(), exercise: reference, goal: "Even tone", minutes: 10)])
        ])])])
    }
    static func revision(templateID: LibraryProgrammeTemplateID = LibraryProgrammeTemplateID(rawValue: UUID()),
                         parent: LibraryProgrammeRevisionID? = nil,
                         content: LibraryProgrammeDraft? = nil, origin: LibraryProgrammeOrigin? = nil) -> LibraryProgrammeTemplateRevision {
        var blank = LibraryProgrammeDraft.starter(weekCount: 1); blank.name = "My programme"
        return LibraryProgrammeTemplateRevision(id: LibraryProgrammeRevisionID(rawValue: UUID()), templateID: templateID,
            parentRevisionID: parent, content: content ?? blank, createdAt: Date(timeIntervalSince1970: 100), origin: origin)
    }
}
private enum LegacyV2ProgrammeTestPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self)] }
}
