import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct HistoryAndNotesTests {
    private var context: FixedPracticeLocalContextProvider { .init(timeZone: TimeZone(identifier: "Europe/London")!, calendarIdentifier: .gregorian) }
    private var noteContext: LearnerNoteContext { get throws { .session(try Fixtures.session(), "Saved sight-reading") } }
    private func note(_ text: String = "Relax shoulders") throws -> PrivateLearnerNote {
        PrivateLearnerNote(id: UUID(), context: try noteContext, text: text, createdAt: LearnerFixtures.timestamp, audience: .privateLearner)
    }
    @Test(arguments: [false, true])
    func privateNotesValidateAndExactRetriesDoNotDuplicate(swiftData: Bool) async throws {
        let repository: any PrivateLearnerNoteRepository = swiftData
            ? SwiftDataPrivateLearnerNoteRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true))
            : InMemoryPrivateLearnerNoteRepository()
        let saved = try note()
        #expect(try await repository.save(saved) == saved)
        #expect(try await repository.save(saved) == saved)
        #expect(try await repository.notes() == [saved])
        let conflicting = PrivateLearnerNote(id: saved.id, context: saved.context, text: "Different", createdAt: saved.createdAt, audience: .privateLearner)
        await #expect(throws: PrivateLearnerNoteError.conflict) { try await repository.save(conflicting) }
        let invalid = try note(" \n ")
        await #expect(throws: PrivateLearnerNoteError.invalid) { try await repository.save(invalid) }
    }
    @Test func failedTransactionsRollbackAndAmbiguousRetriesVerifyDurableNotes() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        var before = true; var after = false
        let repository = SwiftDataPrivateLearnerNoteRepository(container: container, save: { writer in
            if before { throw LibraryTestError() }; try writer.save(); if after { throw LibraryTestError() }
        })
        let saved = try note()
        await #expect(throws: LibraryTestError.self) { try await repository.save(saved) }
        #expect(try await repository.notes().isEmpty)
        before = false; after = true
        await #expect(throws: LibraryTestError.self) { try await repository.save(saved) }
        #expect(try await repository.save(saved) == saved)
        let noOp = SwiftDataPrivateLearnerNoteRepository(container: container, save: { _ in })
        let different = try note("Next focus")
        await #expect(throws: PrivateLearnerNoteError.verificationFailed) { try await noOp.save(different) }
        #expect(try await repository.notes() == [saved])
    }
    @Test func editorFreezesFailedSaveTextContextIdentityAndTimestamp() async throws {
        let repository = NoteDouble()
        let clock = AssignmentTestTime()
        let model = PrivateNoteEditorViewModel(context: try noteContext, repository: repository, clock: clock, localContext: context)
        #expect(await model.save() == false && model.canEdit)
        #expect(repository.requests.isEmpty)
        model.text = " My private reflection "
        repository.failAfter = true
        #expect(await model.save() == false && !model.canEdit)
        let request = try #require(repository.requests.first)
        clock.advance(1000); model.text = "Not in pending note"
        repository.failAfter = false
        #expect(await model.save())
        #expect(repository.requests == [request, request])
        #expect(request.text == "My private reflection" && request.audience == .privateLearner)
        #expect(try await repository.notes().count == 1)
        #expect(await model.save() == false)
    }
    @Test func savedHistoryContainsRealDurationsReportsAndNotesWithoutInventingMetrics() async throws {
        let legacy = InMemoryPracticeHistoryRepository()
        try await legacy.recordSession(try Fixtures.session())
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        var snapshot = try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
        let plan = try #require(snapshot.selectedPlan)
        let assignment = try #require(plan.currentDay?.sections.first?.placements.first)
        snapshot = try await fixture.plans.apply(LearnerFixtures.completion(plan, snapshot.selection, assignment: assignment.id, completed: true))
        let notes = InMemoryPrivateLearnerNoteRepository()
        _ = try await notes.save(note())
        let model = HistoryViewModel(dependencies: dependencies(legacy: legacy, learner: fixture.plans, notes: notes))
        await model.load()
        #expect(model.issues.isEmpty && model.entries.count == 3)
        let session = try #require(model.entries.first { $0.id == "session-session-1" })
        #expect(session.detail.contains("45.0 minutes"))
        #expect(session.detail.contains("statistics were not saved"))
        #expect(session.timestamp.localDay.dayKey == "2026-09-01")
        #expect(model.entries.contains { $0.title == "Reported complete" && $0.detail.contains("Learner report") })
        #expect(model.entries.contains { $0.title == "Private learner note" })
        #expect(model.currentDayContext?.title.contains("Week 1, Day 1") == true)
        #expect(try await legacy.chronologicalHistory().count == 1)
    }
    @Test func failuresRetainKnownRowsAndUnavailableSourcesAreExplicit() async throws {
        let notes = NoteDouble(); _ = try await notes.save(note())
        let legacy = InMemoryPracticeHistoryRepository()
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let model = HistoryViewModel(dependencies: dependencies(legacy: legacy, learner: fixture.plans, notes: notes))
        await model.load(); let known = model.entries
        notes.failRead = true; await model.load()
        #expect(model.entries == known && model.issues.count == 1)
        let missing = HistoryViewModel(dependencies: .unavailablePersistence())
        await missing.load()
        #expect(missing.issues.count == 3 && missing.currentDayContext == nil)
        let editor = PrivateNoteEditorViewModel(context: try noteContext, repository: nil, clock: AssignmentTestTime(), localContext: context)
        editor.text = "Private"; #expect(await editor.save() == false)
    }
    @Test func originalDayNotesUseAuthoritativeSavedPosition() async throws {
        let legacy = InMemoryPracticeHistoryRepository()
        try await legacy.saveActiveProgress(try Fixtures.activeProgress(currentWeekID: "week-02", currentDayID: "week-02-day-03"))
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let model = HistoryViewModel(dependencies: dependencies(legacy: legacy, learner: fixture.plans, notes: InMemoryPrivateLearnerNoteRepository()))
        await model.load()
        #expect(model.currentDayContext?.title.contains("Week 2, Day 3") == true)
        #expect(model.entries.isEmpty)
    }
    @Test func v4DiskMigrationPreservesLearnerPlansAndNotesReopen() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Library.store")
        let legacy = try await createV4(url)
        let upgraded = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataLearnerProgrammeRepository(container: upgraded).snapshot() == legacy)
        let saved = try note()
        _ = try await SwiftDataPrivateLearnerNoteRepository(container: upgraded).save(saved)
        let reopened = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataPrivateLearnerNoteRepository(container: reopened).notes() == [saved])
        #expect(try await SwiftDataLearnerProgrammeRepository(container: reopened).snapshot() == legacy)
        #expect(PracticeHistorySchemaV1.models.count == 6)
    }
    private func createV4(_ url: URL) async throws -> LearnerProgrammeSnapshot {
        let schema = Schema(versionedSchema: LibrarySchemaV4.self)
        let container = try ModelContainer(for: schema, migrationPlan: LegacyNotesV4Plan.self,
            configurations: [ModelConfiguration("PianovoLibrary", schema: schema, url: url, cloudKitDatabase: .none)])
        let fixture = try await LearnerFixtures.seed(container)
        return try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
    }
    private func dependencies(legacy: InMemoryPracticeHistoryRepository, learner: any LearnerProgrammeRepository, notes: any PrivateLearnerNoteRepository) -> AppDependencies {
        AppDependencies(progressRepository: legacy, practiceHistoryRepository: legacy, referenceMaterialResolver: PianovoReferenceMaterialCatalogue.resolver(),
            clock: AssignmentTestTime(), localContextProvider: context, persistenceStatus: .available,
            learnerProgrammeRepository: learner, privateNoteRepository: notes)
    }
}
@MainActor
private final class NoteDouble: PrivateLearnerNoteRepository {
    let backing = InMemoryPrivateLearnerNoteRepository()
    var requests: [PrivateLearnerNote] = []
    var failAfter = false
    var failRead = false
    func notes() async throws -> [PrivateLearnerNote] { if failRead { throw LibraryTestError() }; return try await backing.notes() }
    func save(_ note: PrivateLearnerNote) async throws -> PrivateLearnerNote {
        requests.append(note); let saved = try await backing.save(note)
        if failAfter { throw LibraryTestError() }; return saved
    }
}
private enum LegacyNotesV4Plan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self, LibrarySchemaV3.self, LibrarySchemaV4.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self), .lightweight(fromVersion: LibrarySchemaV2.self, toVersion: LibrarySchemaV3.self), .lightweight(fromVersion: LibrarySchemaV3.self, toVersion: LibrarySchemaV4.self)] }
}
