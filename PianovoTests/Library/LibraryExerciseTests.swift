import Foundation
import SwiftData
import Testing
@testable import Pianovo

struct LibraryExerciseTests {
    @Test func requiredFieldsRejectWhitespaceAndNormalisationKeepsMeaningfulText() {
        var draft = LibraryExerciseDraft()
        #expect(draft.validationIssues == [.titleRequired, .instructionsRequired, .purposeRequired])
        draft.title = "  Scale warm-up \n"
        draft.instructions = "\nPlay slowly.\nRelax the wrists.  "
        draft.learningPurpose = "  Evenness  "
        #expect(draft.validationIssues.isEmpty)
        #expect(draft.normalised.title == "Scale warm-up")
        #expect(draft.normalised.instructions == "Play slowly.\nRelax the wrists.")
        #expect(draft.normalised.learningPurpose == "Evenness")
    }

    @Test func assignmentProgressIsNotPartOfReusableExerciseContent() throws {
        let revision = LibraryFixtures.revision()
        let data = try JSONEncoder().encode(revision)
        #expect(try JSONDecoder().decode(LibraryExerciseRevision.self, from: data) == revision)
        let encoded = String(decoding: data, as: UTF8.self)
        for forbidden in ["completedAt", "masteryState", "programmeID", "sessionID", "rawMIDI"] {
            #expect(!encoded.contains(forbidden))
        }
    }
}

@MainActor
struct LibraryRepositoryTests {
    @Test(arguments: [false, true])
    func createEditArchiveRestoreRetainIdentityOriginAndAllVersions(swiftData: Bool) async throws {
        let repository = try makeRepository(swiftData: swiftData)
        let first = LibraryFixtures.revision(origin: LibraryFixtures.origin)
        let created = try await repository.apply(.create(first))
        let second = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id, title: "Adapted warm-up", origin: first.origin)
        let changed = try await repository.apply(.revise(second, replacing: first.id))
        #expect(changed.id == created.id && changed.ownerID == created.ownerID)
        #expect(changed.currentRevision.origin == first.origin)
        #expect(try await repository.revisionHistory(for: created.id) == [first, second])
        let archived = try await repository.apply(.setArchived(created.id, expectedRevision: second.id, archived: true))
        #expect(archived.isArchived)
        #expect(try await repository.revisionHistory(for: created.id) == [first, second])
        let restored = try await repository.apply(.setArchived(created.id, expectedRevision: second.id, archived: false))
        #expect(restored == changed)
        #expect(try await repository.exercises() == [changed])
    }

    @Test(arguments: [false, true])
    func retriesDoNotCreateDuplicatesOrOverwriteNewerEdits(swiftData: Bool) async throws {
        let repository = try makeRepository(swiftData: swiftData)
        let first = LibraryFixtures.revision()
        let original = try await repository.apply(.create(first))
        #expect(try await repository.apply(.create(first)) == original)
        let second = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id)
        let updated = try await repository.apply(.revise(second, replacing: first.id))
        #expect(try await repository.apply(.revise(second, replacing: first.id)) == updated)
        let stale = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id)
        await #expect(throws: LibraryRepositoryError.conflict) { try await repository.apply(.revise(stale, replacing: first.id)) }
        await #expect(throws: LibraryRepositoryError.conflict) {
            try await repository.apply(.setArchived(first.exerciseID, expectedRevision: first.id, archived: true))
        }
        #expect(try await repository.revisionHistory(for: first.exerciseID) == [first, second])
    }

    @Test(arguments: [false, true])
    func sameTitleHasIndependentIdentityAndRevisionIDCollisionIsRejected(swiftData: Bool) async throws {
        let repository = try makeRepository(swiftData: swiftData)
        let first = LibraryFixtures.revision()
        let second = LibraryFixtures.revision()
        let a = try await repository.apply(.create(first))
        let b = try await repository.apply(.create(second))
        #expect(a.id != b.id && a.ownerID == b.ownerID)
        let collision = LibraryExerciseRevision(id: first.id, exerciseID: second.exerciseID, parentRevisionID: second.id,
            content: first.content, createdAt: first.createdAt, origin: nil)
        await #expect(throws: LibraryRepositoryError.self) { try await repository.apply(.revise(collision, replacing: second.id)) }
        #expect(try await repository.revisionHistory(for: second.exerciseID) == [second])
    }

    @Test(arguments: [false, true])
    func archivePreventsEditUntilRestoredAndIsIdempotent(swiftData: Bool) async throws {
        let repository = try makeRepository(swiftData: swiftData)
        let first = LibraryFixtures.revision()
        _ = try await repository.apply(.create(first))
        let mutation = LibraryMutation.setArchived(first.exerciseID, expectedRevision: first.id, archived: true)
        let archived = try await repository.apply(mutation)
        #expect(try await repository.apply(mutation) == archived)
        let edit = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id)
        await #expect(throws: LibraryRepositoryError.archived) { try await repository.apply(.revise(edit, replacing: first.id)) }
        #expect(try await repository.revisionHistory(for: first.exerciseID) == [first])
    }

    @Test(arguments: [false, true])
    func invalidContentAndMissingTargetsNeverWrite(swiftData: Bool) async throws {
        let repository = try makeRepository(swiftData: swiftData)
        let invalid = LibraryExerciseRevision(id: LibraryRevisionID(rawValue: UUID()), exerciseID: LibraryExerciseID(rawValue: UUID()),
            parentRevisionID: nil, content: LibraryExerciseDraft(), createdAt: Date(), origin: nil)
        await #expect(throws: LibraryRepositoryError.invalid([.titleRequired, .instructionsRequired, .purposeRequired])) {
            try await repository.apply(.create(invalid))
        }
        await #expect(throws: LibraryRepositoryError.notFound) { try await repository.revisionHistory(for: invalid.exerciseID) }
        await #expect(throws: LibraryRepositoryError.notFound) {
            try await repository.apply(.setArchived(invalid.exerciseID, expectedRevision: invalid.id, archived: true))
        }
        #expect(try await repository.exercises().isEmpty)
    }

    @Test func failedInsertUpdateAndArchiveRollbackAndRetryWithoutTouchingOtherContext() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let other = ModelContext(container)
        other.autosaveEnabled = false
        other.insert(LibrarySchemaV1.IdentityModel(ownerID: LibraryOwnerID(rawValue: UUID())))
        var fail = true
        let repository = SwiftDataLibraryExerciseRepository(container: container, save: { context in
            if fail { throw LibraryTestError() }
            try context.save()
        })
        let first = LibraryFixtures.revision()
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.create(first)) }
        #expect(try await repository.exercises().isEmpty)
        #expect(other.hasChanges)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).isEmpty)
        fail = false
        let created = try await repository.apply(.create(first))
        fail = true
        let second = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.revise(second, replacing: first.id)) }
        #expect(try await repository.exercises() == [created])
        #expect(try await repository.revisionHistory(for: first.exerciseID) == [first])
        fail = false
        let edited = try await repository.apply(.revise(second, replacing: first.id))
        fail = true
        let archive = LibraryMutation.setArchived(first.exerciseID, expectedRevision: second.id, archived: true)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(archive) }
        #expect(try await repository.exercises() == [edited])
        fail = false
        #expect(try await repository.apply(archive).isArchived)
        #expect(other.hasChanges)
    }

    @Test func noOpSaveIsNotSuccessAndAmbiguousSaveRetriesSameRecord() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        var saves = 0
        let repository = SwiftDataLibraryExerciseRepository(container: container, save: { writer in
            saves += 1
            if saves == 1 { return }
            try writer.save()
            throw LibraryTestError()
        })
        let revision = LibraryFixtures.revision()
        await #expect(throws: LibraryRepositoryError.verificationFailed) { try await repository.apply(.create(revision)) }
        #expect(try await repository.exercises().isEmpty)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(.create(revision)) }
        let restored = try await repository.apply(.create(revision))
        #expect(restored.currentRevision == revision)
        #expect(saves == 2)
        #expect(try await repository.revisionHistory(for: revision.exerciseID) == [revision])
    }

    @Test func corruptPayloadIsAnErrorRatherThanAnEmptyLibrary() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let repository = SwiftDataLibraryExerciseRepository(container: container)
        let revision = LibraryFixtures.revision()
        _ = try await repository.apply(.create(revision))
        let writer = ModelContext(container)
        let model = try #require(try writer.fetch(FetchDescriptor<LibrarySchemaV1.RevisionModel>()).first)
        model.payload = Data("invalid".utf8)
        try writer.save()
        await #expect(throws: LibraryRepositoryError.corruptStore) { try await repository.exercises() }
    }

    @Test func freshContainersRestoreDiskContentAndLeaveProgressStoreUnchanged() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Library.store")
        let historyContainer = try PracticeHistoryModelContainerFactory.makeContainer(inMemory: true)
        let history = SwiftDataPracticeHistoryRepository(context: ModelContext(historyContainer))
        let progress = try Fixtures.activeProgress()
        try await history.saveActiveProgress(progress)
        try await history.recordSession(try Fixtures.session())
        let before = try await history.chronologicalHistory()
        let first = LibraryFixtures.revision()
        let second = LibraryFixtures.revision(exerciseID: first.exerciseID, parent: first.id)
        var expected: LibraryExercise?
        do {
            let container = try LibraryModelContainerFactory.makeContainer(storeURL: url)
            let library = SwiftDataLibraryExerciseRepository(container: container)
            _ = try await library.apply(.create(first))
            _ = try await library.apply(.revise(second, replacing: first.id))
            expected = try await library.apply(.setArchived(first.exerciseID, expectedRevision: second.id, archived: true))
        }
        let reopened = SwiftDataLibraryExerciseRepository(container: try LibraryModelContainerFactory.makeContainer(storeURL: url))
        #expect(try await reopened.exercises() == [try #require(expected)])
        #expect(try await reopened.revisionHistory(for: first.exerciseID) == [first, second])
        #expect(try await history.loadProgress(programmeID: progress.programme.programmeID)?.activeProgress == progress)
        #expect(try await history.chronologicalHistory() == before)
        #expect(LibraryModelContainerFactory.configuration().url != ModelConfiguration(schema: Schema(PracticeHistorySchemaV1.models)).url)
    }

    @Test func libraryHasItsOwnVersionedSchemaAndNoProgressModels() {
        #expect(LibrarySchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(LibrarySchemaV1.models.count == 3)
        #expect(LibraryMigrationPlan.schemas.count == 6)
        #expect(LibraryMigrationPlan.stages.count == 5)
        #expect(PracticeHistorySchemaV1.models.count == 6)
    }

    private func makeRepository(swiftData: Bool) throws -> any LibraryExerciseRepository {
        if swiftData { return SwiftDataLibraryExerciseRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true)) }
        return InMemoryLibraryExerciseRepository()
    }
}

nonisolated enum LibraryFixtures {
    static var draft: LibraryExerciseDraft {
        LibraryExerciseDraft(title: "Scale warm-up", category: .warmUp, instructions: "Play slowly with relaxed movement.", learningPurpose: "Evenness", referenceMaterialID: nil)
    }
    static var origin: LibraryExerciseOrigin {
        LibraryExerciseOrigin(exerciseID: LibraryExerciseID(rawValue: UUID()), revisionID: LibraryRevisionID(rawValue: UUID()), creatorAttribution: "Original author")
    }
    static func revision(exerciseID: LibraryExerciseID = LibraryExerciseID(rawValue: UUID()),
                         parent: LibraryRevisionID? = nil, title: String = "Scale warm-up", origin: LibraryExerciseOrigin? = nil) -> LibraryExerciseRevision {
        var content = draft
        content.title = title
        return LibraryExerciseRevision(id: LibraryRevisionID(rawValue: UUID()), exerciseID: exerciseID, parentRevisionID: parent,
                                       content: content, createdAt: Date(timeIntervalSince1970: 100), origin: origin)
    }
}

struct LibraryTestError: Error {}
