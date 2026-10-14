import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct CloudSyncTests {
    private let account = CloudAccountID(rawValue: UUID())
    private let otherAccount = CloudAccountID(rawValue: UUID())
    private let owner = LibraryOwnerID(rawValue: UUID())
    private func envelope(kind: CloudResourceKind = .exerciseRevision) -> CloudEnvelope {
        CloudEnvelope(id: UUID(), accountID: account, localOwnerID: owner, kind: kind,
                      resourceID: UUID(), revisionID: UUID(), expectedRevisionID: nil,
                      payloadSchemaVersion: 1, payload: Data("{\"title\":\"Synthetic fixture\"}".utf8), createdAt: LearnerFixtures.timestamp)
    }
    private func link(scopes: Set<CloudConsentScope> = [.authoredContent]) -> CloudOwnerLink {
        CloudOwnerLink(localOwnerID: owner, accountID: account, consentID: UUID(), scopes: scopes, consentedAt: LearnerFixtures.timestamp)
    }
    private func step(_ repository: SwiftDataCloudSyncRepository, _ command: CloudSyncCommand) async throws -> CloudSyncSnapshot {
        let previous = try await repository.snapshot()
        return try await repository.apply(command, expectedVersion: previous.version, newVersion: UUID())
    }
    private func repository() throws -> SwiftDataCloudSyncRepository {
        SwiftDataCloudSyncRepository(container: try LibraryModelContainerFactory.makeContainer(inMemory: true))
    }
    @Test func guestAndEachDataScopeRequireExplicitConsent() async throws {
        let repository = try repository()
        #expect(try await repository.snapshot() == .initial)
        await #expect(throws: CloudSyncError.accountMismatch) { try await step(repository, .enqueue(envelope())) }
        _ = try await step(repository, .session(account, UUID()))
        await #expect(throws: CloudSyncError.consentRequired) { try await step(repository, .enqueue(envelope())) }
        _ = try await step(repository, .consent(link()))
        _ = try await step(repository, .enqueue(envelope()))
        for kind in [CloudResourceKind.privateNote, .learnerRevision, .completion, .legacySession] {
            await #expect(throws: CloudSyncError.consentRequired) { try await step(repository, .enqueue(envelope(kind: kind))) }
        }
        _ = try await step(repository, .consent(link(scopes: [.privateNotes])))
        let state = try await step(repository, .enqueue(envelope(kind: .privateNote)))
        #expect(state.operations.count == 2 && state.sendableOperations.count == 1)
        #expect(state.sendableOperations.first?.envelope.kind == .privateNote)
    }
    @Test func accountSwitchAndSignOutFenceRequestsWithoutRelinkingGuestIDs() async throws {
        let repository = try repository()
        _ = try await step(repository, .session(account, UUID()))
        _ = try await step(repository, .consent(link()))
        let operation = envelope()
        let queued = try await step(repository, .enqueue(operation))
        let session = try #require(queued.session)
        _ = try await step(repository, .claim(operation.id, session))
        _ = try await step(repository, .cursor(session, nil, "a-cursor"))
        let other = try await step(repository, .session(otherAccount, UUID()))
        #expect(other.sendableOperations.isEmpty && other.currentCursor == nil)
        #expect(other.operations.first?.status == .queued && other.operations.first?.lease == nil)
        await #expect(throws: CloudSyncError.staleLease) { try await step(repository, .acknowledge(operation.id, session, operation.revisionID)) }
        let falseLink = CloudOwnerLink(localOwnerID: owner, accountID: otherAccount, consentID: UUID(), scopes: [.authoredContent], consentedAt: LearnerFixtures.timestamp)
        await #expect(throws: CloudSyncError.ownerAlreadyLinked) { try await step(repository, .consent(falseLink)) }
        let signedOut = try await step(repository, .session(nil, UUID()))
        #expect(signedOut.sendableOperations.isEmpty && signedOut.currentCursor == nil)
        let restored = try await step(repository, .session(account, UUID()))
        #expect(restored.sendableOperations.count == 1 && restored.currentCursor == "a-cursor")
        #expect(restored.links.first?.localOwnerID == owner)
    }
    @Test func revokedConsentParksSendingPrivateNotes() async throws {
        let repository = try repository()
        _ = try await step(repository, .session(account, UUID()))
        _ = try await step(repository, .consent(link(scopes: [.privateNotes])))
        let operation = envelope(kind: .privateNote)
        let queued = try await step(repository, .enqueue(operation))
        let session = try #require(queued.session)
        _ = try await step(repository, .claim(operation.id, session))
        let revoked = try await step(repository, .consent(link(scopes: [])))
        #expect(revoked.sendableOperations.isEmpty && revoked.operations.first?.lease == nil)
        await #expect(throws: CloudSyncError.staleLease) { try await step(repository, .acknowledge(operation.id, session, operation.revisionID)) }
    }
    @Test func failedSendsRetryButConflictsAreNotAutomaticallyResent() async throws {
        let repository = try repository()
        _ = try await step(repository, .session(account, UUID()))
        _ = try await step(repository, .consent(link()))
        let operation = envelope()
        let queued = try await step(repository, .enqueue(operation))
        let session = try #require(queued.session)
        _ = try await step(repository, .claim(operation.id, session))
        #expect(try await step(repository, .fail(operation.id, session, false)).sendableOperations.count == 1)
        _ = try await step(repository, .claim(operation.id, session))
        let conflict = try await step(repository, .fail(operation.id, session, true))
        #expect(conflict.sendableOperations.isEmpty && conflict.operations.first?.status == .conflict)
    }
    @Test func ambiguousSaveRetriesDoNotRegressLaterSessionOrDuplicateOperations() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        var failBefore = true; var failAfter = false
        let repository = SwiftDataCloudSyncRepository(container: container, save: { writer in
            if failBefore { throw LibraryTestError() }
            try writer.save()
            if failAfter { throw LibraryTestError() }
        })
        let sessionCommand = CloudSyncCommand.session(account, UUID())
        let transition = UUID()
        await #expect(throws: LibraryTestError.self) {
            try await repository.apply(sessionCommand, expectedVersion: CloudSyncSnapshot.initial.version, newVersion: transition)
        }
        #expect(try await repository.snapshot() == .initial)
        failBefore = false; failAfter = true
        await #expect(throws: LibraryTestError.self) {
            try await repository.apply(sessionCommand, expectedVersion: CloudSyncSnapshot.initial.version, newVersion: transition)
        }
        failAfter = false
        _ = try await step(repository, .consent(link()))
        let operation = envelope()
        let queued = try await step(repository, .enqueue(operation))
        let session = try #require(queued.session)
        let claimVersion = UUID()
        failAfter = true
        await #expect(throws: LibraryTestError.self) {
            try await repository.apply(.claim(operation.id, session), expectedVersion: queued.version, newVersion: claimVersion)
        }
        failAfter = false
        let retry = try await repository.apply(.claim(operation.id, session), expectedVersion: queued.version, newVersion: claimVersion)
        #expect(retry.operations.count == 1 && retry.operations.first?.status == .sending)
        let ack = try await step(repository, .acknowledge(operation.id, session, operation.revisionID))
        #expect(ack.operations.first?.status == .acknowledged)
        let switched = try await step(repository, .session(otherAccount, UUID()))
        #expect(try await repository.apply(sessionCommand, expectedVersion: CloudSyncSnapshot.initial.version, newVersion: transition) == switched)
        #expect(try await repository.apply(.claim(operation.id, session), expectedVersion: queued.version, newVersion: claimVersion) == switched)
        await #expect(throws: CloudSyncError.conflict) {
            try await repository.apply(.session(account, UUID()), expectedVersion: CloudSyncSnapshot.initial.version, newVersion: transition)
        }
    }
    @Test func staleWritesAndPhantomSavesDoNotSucceed() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let repository = SwiftDataCloudSyncRepository(container: container)
        _ = try await step(repository, .session(account, UUID()))
        await #expect(throws: CloudSyncError.staleState) {
            try await repository.apply(.consent(link()), expectedVersion: CloudSyncSnapshot.initial.version, newVersion: UUID())
        }
        let current = try await repository.snapshot()
        await #expect(throws: CloudSyncError.staleState) {
            try await repository.apply(.consent(link()), expectedVersion: current.version, newVersion: CloudSyncSnapshot.initial.version)
        }
        let noSave = SwiftDataCloudSyncRepository(container: container, save: { _ in })
        await #expect(throws: CloudSyncError.verificationFailed) { try await step(noSave, .consent(link())) }
        #expect(try await repository.snapshot().links.isEmpty)
    }
    @Test func cursorAndAcknowledgementRequireTheCapturedSessionAndRevision() async throws {
        let repository = try repository()
        _ = try await step(repository, .session(account, UUID()))
        _ = try await step(repository, .consent(link()))
        let operation = envelope()
        let queued = try await step(repository, .enqueue(operation))
        let session = try #require(queued.session)
        _ = try await step(repository, .claim(operation.id, session))
        await #expect(throws: CloudSyncError.staleLease) { try await step(repository, .acknowledge(operation.id, session, UUID())) }
        _ = try await step(repository, .cursor(session, nil, "first"))
        await #expect(throws: CloudSyncError.staleState) { try await step(repository, .cursor(session, nil, "second")) }
        #expect(try await step(repository, .cursor(session, "first", "second")).currentCursor == "second")
    }
    @Test func invalidPayloadsAndCorruptStoreAreRejected() async throws {
        let valid = envelope()
        for payload in [Data("[]".utf8), Data("null".utf8), Data("invalid".utf8)] {
            let invalid = CloudEnvelope(id: valid.id, accountID: account, localOwnerID: owner, kind: valid.kind, resourceID: valid.resourceID,
                revisionID: valid.revisionID, expectedRevisionID: nil, payloadSchemaVersion: 1, payload: payload, createdAt: valid.createdAt)
            #expect(throws: CloudSyncError.invalid) { try invalid.validate() }
        }
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        var corrupt = CloudSyncSnapshot.initial
        corrupt.operations = [CloudOperation(envelope: valid, status: .sending)]
        let writer = ModelContext(container); writer.insert(try LibrarySchemaV6.CloudStateModel(corrupt)); try writer.save()
        await #expect(throws: CloudSyncError.corruptStore) { try await SwiftDataCloudSyncRepository(container: container).snapshot() }
    }
}
