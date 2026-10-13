import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct LibraryTemplateTests {
    @Test func defaultsAndNameAreValidatedAndStarterPatternsDoNotSeedStorage() async throws {
        #expect(LibraryTemplateDraft().validationIssues == [.templateNameRequired, .titleRequired, .instructionsRequired, .purposeRequired])
        for starter in LibraryStarterPattern.allCases {
            #expect(starter.draft.validationIssues.isEmpty)
            #expect(starter.draft.defaults.referenceMaterialID == nil)
        }
        let repository = SwiftDataLibraryTemplateRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true))
        #expect(try await repository.templates().isEmpty)
        var draft = TemplateFixtures.draft
        draft.name = "  Pattern \n"
        #expect(draft.normalised.name == "Pattern")
    }

    @Test(arguments: [false, true])
    func editsRetriesArchiveAndRestorePreserveAllVersions(swiftData: Bool) async throws {
        let repository = try repository(swiftData)
        let first = TemplateFixtures.revision(starter: .relaxedWarmUpV1)
        let original = try await repository.apply(.create(first))
        #expect(try await repository.apply(.create(first)) == original)
        let second = TemplateFixtures.revision(templateID: first.templateID, parent: first.id, name: "Updated", starter: first.starterPattern)
        let edited = try await repository.apply(.revise(second, replacing: first.id))
        #expect(try await repository.apply(.revise(second, replacing: first.id)) == edited)
        let stale = TemplateFixtures.revision(templateID: first.templateID, parent: first.id)
        await #expect(throws: LibraryRepositoryError.conflict) { try await repository.apply(.revise(stale, replacing: first.id)) }
        let archived = try await repository.apply(.setArchived(first.templateID, expectedRevision: second.id, archived: true))
        #expect(archived.isArchived)
        #expect(try await repository.revisionHistory(for: first.templateID) == [first, second])
        let illegalEdit = TemplateFixtures.revision(templateID: first.templateID, parent: second.id, starter: first.starterPattern)
        await #expect(throws: LibraryRepositoryError.archived) { try await repository.apply(.revise(illegalEdit, replacing: second.id)) }
        #expect(try await repository.apply(.setArchived(first.templateID, expectedRevision: second.id, archived: false)) == edited)
    }

    @Test func failedTemplateTransactionsRollbackAndAmbiguousRetryKeepsDurableRevision() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        var failBefore = true
        var failAfter = false
        let repository = SwiftDataLibraryTemplateRepository(container: container, save: { writer in
            if failBefore { throw LibraryTestError() }
            try writer.save()
            if failAfter { throw LibraryTestError() }
        })
        let first = TemplateFixtures.revision()
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.create(first)) }
        #expect(try await repository.templates().isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).isEmpty)
        failBefore = false
        failAfter = true
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.create(first)) }
        let original = try await repository.apply(.create(first))
        #expect(original.currentRevision == first)
        failAfter = false
        failBefore = true
        let next = TemplateFixtures.revision(templateID: first.templateID, parent: first.id)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.revise(next, replacing: first.id)) }
        #expect(try await repository.revisionHistory(for: first.templateID) == [first])
        await #expect(throws: LibraryTestError.self) {
            try await repository.apply(.setArchived(first.templateID, expectedRevision: first.id, archived: true))
        }
        #expect(try await repository.templates() == [original])
    }

    @Test func noOpTemplateSaveIsNotDurableAndExerciseAndTemplateShareLocalOwner() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let noOp = SwiftDataLibraryTemplateRepository(container: container, save: { _ in })
        let revision = TemplateFixtures.revision()
        await #expect(throws: LibraryRepositoryError.verificationFailed) { try await noOp.apply(.create(revision)) }
        #expect(try await noOp.templates().isEmpty)
        let templates = SwiftDataLibraryTemplateRepository(container: container)
        let template = try await templates.apply(.create(revision))
        let exercise = try await SwiftDataLibraryExerciseRepository(container: container).apply(.create(LibraryFixtures.revision()))
        #expect(exercise.ownerID == template.ownerID)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).count == 1)
    }

    @Test func v1DiskMigrationPreservesOwnerExerciseArchiveHistoryAndLegacyPayload() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Library.store")
        let first = LibraryFixtures.revision(origin: LibraryFixtures.origin)
        let second = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id, title: "Existing edit", origin: first.origin)
        let owner = LibraryOwnerID(rawValue: UUID())
        let original = LibraryExercise(id: first.exerciseID, ownerID: owner, currentRevision: second, isArchived: true)
        try autoreleasepool {
            // Exact 6F.7 schema construction, without any V2 template model.
            let schema = Schema(LibrarySchemaV1.models)
            let configuration = ModelConfiguration("PianovoLibrary", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, migrationPlan: LegacyLibraryTestMigrationPlan.self, configurations: [configuration])
            let writer = ModelContext(container)
            writer.autosaveEnabled = false
            writer.insert(LibrarySchemaV1.IdentityModel(ownerID: owner))
            writer.insert(LibrarySchemaV1.ExerciseModel(original))
            writer.insert(try LibrarySchemaV1.RevisionModel(first))
            writer.insert(try LibrarySchemaV1.RevisionModel(second))
            try writer.save()
        }
        let current = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        let exercises = SwiftDataLibraryExerciseRepository(container: current)
        #expect(try await exercises.exercises() == [original])
        #expect(try await exercises.revisionHistory(for: first.exerciseID) == [first, second])
        #expect(original.currentRevision.templateOrigin == nil)
        let templates = SwiftDataLibraryTemplateRepository(container: current)
        #expect(try await templates.templates().isEmpty)
        let created = try await templates.apply(.create(TemplateFixtures.revision()))
        #expect(created.ownerID == owner)
        #expect(try await exercises.exercises() == [original])
        let reopened = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataLibraryTemplateRepository(container: reopened).templates() == [created])
        #expect(try await SwiftDataLibraryExerciseRepository(container: reopened).exercises() == [original])
    }

    @Test func legacyRevisionJSONWithoutTemplateOriginStillDecodes() throws {
        let revision = LibraryFixtures.revision()
        let data = try JSONEncoder().encode(revision)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "templateOrigin")
        let decoded = try JSONDecoder().decode(LibraryExerciseRevision.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded == revision && decoded.templateOrigin == nil)
    }

    @Test func invalidTemplatesAndCollidingRevisionIdentityCannotWrite() async throws {
        let repository = SwiftDataLibraryTemplateRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true))
        let invalid = LibraryExerciseTemplateRevision(id: LibraryTemplateRevisionID(rawValue: UUID()), templateID: LibraryTemplateID(rawValue: UUID()),
            parentRevisionID: nil, content: LibraryTemplateDraft(), createdAt: Date(), starterPattern: nil)
        await #expect(throws: LibraryRepositoryError.self) { try await repository.apply(.create(invalid)) }
        #expect(try await repository.templates().isEmpty)
        let first = TemplateFixtures.revision()
        let second = TemplateFixtures.revision()
        _ = try await repository.apply(.create(first))
        _ = try await repository.apply(.create(second))
        let collision = LibraryExerciseTemplateRevision(id: first.id, templateID: second.templateID, parentRevisionID: second.id,
            content: first.content, createdAt: first.createdAt, starterPattern: nil)
        await #expect(throws: LibraryRepositoryError.duplicateID) { try await repository.apply(.revise(collision, replacing: second.id)) }
        #expect(try await repository.revisionHistory(for: second.templateID) == [second])
    }

    private func repository(_ swiftData: Bool) throws -> any LibraryExerciseTemplateRepository {
        if swiftData { return SwiftDataLibraryTemplateRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true)) }
        return InMemoryLibraryExerciseTemplateRepository()
    }
}

nonisolated enum TemplateFixtures {
    static var draft: LibraryTemplateDraft { LibraryTemplateDraft(name: "Warm-up pattern", defaults: LibraryFixtures.draft) }
    static func revision(templateID: LibraryTemplateID = LibraryTemplateID(rawValue: UUID()),
                         parent: LibraryTemplateRevisionID? = nil, name: String = "Warm-up pattern",
                         starter: LibraryStarterPattern? = nil) -> LibraryExerciseTemplateRevision {
        var content = draft
        content.name = name
        return LibraryExerciseTemplateRevision(id: LibraryTemplateRevisionID(rawValue: UUID()), templateID: templateID,
            parentRevisionID: parent, content: content, createdAt: Date(timeIntervalSince1970: 100), starterPattern: starter)
    }
}

private enum LegacyLibraryTestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
