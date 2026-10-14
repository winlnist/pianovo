import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct CloudSyncMigrationTests {
    @Test func v5GuestDataAndStableIDsSurviveMigrationAndQueueReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Library.store")
        let legacy = try await createV5(url)
        let container = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        let exercises = SwiftDataLibraryExerciseRepository(container: container)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first?.ownerID == legacy.owner.rawValue)
        #expect(try await exercises.exercises() == [legacy.exercise])
        #expect(try await SwiftDataLearnerProgrammeRepository(container: container).snapshot() == legacy.plan)
        #expect(try await SwiftDataPrivateLearnerNoteRepository(container: container).notes() == [legacy.note])
        let cloud = SwiftDataCloudSyncRepository(container: container)
        #expect(try await cloud.snapshot() == .initial)
        let account = CloudAccountID(rawValue: UUID())
        let session = try await cloud.apply(.session(account, UUID()), expectedVersion: CloudSyncSnapshot.initial.version, newVersion: UUID())
        #expect(session.links.isEmpty && session.sendableOperations.isEmpty)
        let linked = try await cloud.apply(.consent(CloudOwnerLink(localOwnerID: legacy.owner, accountID: account, consentID: UUID(),
            scopes: [.authoredContent], consentedAt: LearnerFixtures.timestamp)), expectedVersion: session.version, newVersion: UUID())
        let envelope = CloudEnvelope(id: UUID(), accountID: account, localOwnerID: legacy.owner, kind: .exerciseRevision,
            resourceID: legacy.exercise.id.rawValue, revisionID: legacy.exercise.currentRevision.id.rawValue, expectedRevisionID: nil,
            payloadSchemaVersion: 1, payload: Data("{\"synthetic\":true}".utf8), createdAt: LearnerFixtures.timestamp)
        let queued = try await cloud.apply(.enqueue(envelope), expectedVersion: linked.version, newVersion: UUID())
        let reopened = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataCloudSyncRepository(container: reopened).snapshot() == queued)
        #expect(try await SwiftDataLibraryExerciseRepository(container: reopened).exercises() == [legacy.exercise])
        #expect(try await SwiftDataLearnerProgrammeRepository(container: reopened).snapshot() == legacy.plan)
        #expect(try await SwiftDataPrivateLearnerNoteRepository(container: reopened).notes() == [legacy.note])
        #expect(PracticeHistorySchemaV1.models.count == 6)
    }
    private func createV5(_ url: URL) async throws -> LegacyData {
        let schema = Schema(versionedSchema: LibrarySchemaV5.self)
        let container = try ModelContainer(for: schema, migrationPlan: LegacyCloudV5Plan.self,
            configurations: [ModelConfiguration("PianovoLibrary", schema: schema, url: url, cloudKitDatabase: .none)])
        let fixture = try await LearnerFixtures.seed(container)
        let plan = try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
        let note = PrivateLearnerNote(id: UUID(), context: .session(try Fixtures.session(), "Synthetic session"),
            text: "Synthetic private note", createdAt: LearnerFixtures.timestamp, audience: .privateLearner)
        _ = try await SwiftDataPrivateLearnerNoteRepository(container: container).save(note)
        return LegacyData(owner: fixture.exercise.ownerID, exercise: fixture.exercise, plan: plan, note: note)
    }
    private struct LegacyData {
        let owner: LibraryOwnerID
        let exercise: LibraryExercise
        let plan: LearnerProgrammeSnapshot
        let note: PrivateLearnerNote
    }
}
private enum LegacyCloudV5Plan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self, LibrarySchemaV3.self, LibrarySchemaV4.self, LibrarySchemaV5.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self),
         .lightweight(fromVersion: LibrarySchemaV2.self, toVersion: LibrarySchemaV3.self),
         .lightweight(fromVersion: LibrarySchemaV3.self, toVersion: LibrarySchemaV4.self),
         .lightweight(fromVersion: LibrarySchemaV4.self, toVersion: LibrarySchemaV5.self)]
    }
}
