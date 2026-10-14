import Foundation

nonisolated struct CloudAccountID: Codable, Hashable { let rawValue: UUID }
nonisolated struct CloudSession: Codable, Equatable {
    let accountID: CloudAccountID
    let generation: UUID
}
nonisolated enum CloudConsentScope: String, Codable, Hashable {
    case authoredContent, learnerPlans, practiceHistory, privateNotes
}
nonisolated enum CloudResourceKind: String, Codable {
    case exerciseRevision, exerciseTemplateRevision, programmeTemplateRevision, learnerRevision, completion, legacySession, privateNote
    var scope: CloudConsentScope {
        switch self {
        case .exerciseRevision, .exerciseTemplateRevision, .programmeTemplateRevision: .authoredContent
        case .learnerRevision, .completion: .learnerPlans
        case .legacySession: .practiceHistory
        case .privateNote: .privateNotes
        }
    }
}
nonisolated struct CloudOwnerLink: Codable, Equatable {
    let localOwnerID: LibraryOwnerID
    let accountID: CloudAccountID
    let consentID: UUID
    let scopes: Set<CloudConsentScope>
    let consentedAt: PracticeTimestamp
}
nonisolated struct CloudEnvelope: Codable, Equatable, Identifiable {
    let id: UUID
    let accountID: CloudAccountID
    let localOwnerID: LibraryOwnerID
    let kind: CloudResourceKind
    let resourceID: UUID
    let revisionID: UUID
    let expectedRevisionID: UUID?
    let payloadSchemaVersion: Int
    let payload: Data
    let createdAt: PracticeTimestamp
    func validate() throws {
        guard payloadSchemaVersion == 1, createdAt.instant.timeIntervalSince1970.isFinite,
              (try? JSONSerialization.jsonObject(with: payload)) is [String: Any] else { throw CloudSyncError.invalid }
    }
}
nonisolated enum CloudOperationStatus: String, Codable { case queued, sending, failed, conflict, acknowledged }
nonisolated struct CloudOperation: Codable, Equatable, Identifiable {
    let envelope: CloudEnvelope
    var status: CloudOperationStatus = .queued
    var lease: CloudSession?
    var acknowledgedRevisionID: UUID?
    var id: UUID { envelope.id }
}
nonisolated struct CloudCursor: Codable, Equatable {
    let accountID: CloudAccountID
    let value: String
}
nonisolated struct CloudSyncSnapshot: Codable, Equatable {
    static let initial = Self(version: UUID(uuidString: "2BE0A4AA-B23B-44B3-83C0-3915107B8672")!)
    var version: UUID
    var session: CloudSession?
    var links: [CloudOwnerLink] = []
    var operations: [CloudOperation] = []
    var cursors: [CloudCursor] = []
    var receipts: [CloudTransitionReceipt] = []
    func canSend(_ envelope: CloudEnvelope) -> Bool {
        session?.accountID == envelope.accountID && links.contains {
            $0.accountID == envelope.accountID && $0.localOwnerID == envelope.localOwnerID && $0.scopes.contains(envelope.kind.scope)
        }
    }
    var sendableOperations: [CloudOperation] {
        operations.filter { ($0.status == .queued || $0.status == .failed) && canSend($0.envelope) }
    }
    var currentCursor: String? { cursors.first { $0.accountID == session?.accountID }?.value }
}
nonisolated enum CloudSyncError: Error, Equatable {
    case invalid, staleState, accountMismatch, consentRequired, ownerAlreadyLinked, conflict, staleLease, corruptStore, verificationFailed
}
nonisolated enum CloudSyncCommand: Codable, Equatable {
    case session(CloudAccountID?, UUID)
    case consent(CloudOwnerLink)
    case enqueue(CloudEnvelope)
    case claim(UUID, CloudSession)
    case acknowledge(UUID, CloudSession, UUID)
    case fail(UUID, CloudSession, Bool)
    case cursor(CloudSession, String?, String)
}
/// Durable local transition receipt, distinct from a server acceptance receipt.
nonisolated struct CloudTransitionReceipt: Codable, Equatable, Identifiable {
    let id: UUID
    let expectedVersion: UUID
    let command: CloudSyncCommand
}
nonisolated enum CloudSyncRules {
    static func applying(_ command: CloudSyncCommand, to value: CloudSyncSnapshot, version: UUID) throws -> CloudSyncSnapshot {
        var result = value
        switch command {
        case .session(let account, let generation):
            result.session = account.map { CloudSession(accountID: $0, generation: generation) }
            for index in result.operations.indices where result.operations[index].status == .sending {
                result.operations[index].status = .queued; result.operations[index].lease = nil
            }
        case .consent(let link):
            guard value.session?.accountID == link.accountID else { throw CloudSyncError.accountMismatch }
            guard link.consentedAt.instant.timeIntervalSince1970.isFinite else { throw CloudSyncError.invalid }
            if let old = value.links.first(where: { $0.localOwnerID == link.localOwnerID }), old.accountID != link.accountID { throw CloudSyncError.ownerAlreadyLinked }
            result.links.removeAll { $0.localOwnerID == link.localOwnerID }; result.links.append(link)
            for index in result.operations.indices where !result.canSend(result.operations[index].envelope) && result.operations[index].status == .sending {
                result.operations[index].status = .queued; result.operations[index].lease = nil
            }
        case .enqueue(let envelope):
            try envelope.validate()
            guard value.session?.accountID == envelope.accountID else { throw CloudSyncError.accountMismatch }
            guard value.canSend(envelope) else { throw CloudSyncError.consentRequired }
            if let existing = value.operations.first(where: { $0.id == envelope.id }) {
                guard existing.envelope == envelope else { throw CloudSyncError.conflict }; return value
            }
            result.operations.append(CloudOperation(envelope: envelope))
        case .claim(let id, let session):
            guard value.session == session else { throw CloudSyncError.staleLease }
            guard let index = result.operations.firstIndex(where: { $0.id == id }), result.canSend(result.operations[index].envelope),
                  [.queued, .failed].contains(result.operations[index].status) else { throw CloudSyncError.consentRequired }
            result.operations[index].status = .sending; result.operations[index].lease = session
        case .acknowledge(let id, let session, let revision):
            guard let index = result.operations.firstIndex(where: { $0.id == id }), value.session == session,
                  result.canSend(result.operations[index].envelope) else { throw CloudSyncError.staleLease }
            if result.operations[index].status == .acknowledged {
                guard result.operations[index].acknowledgedRevisionID == revision else { throw CloudSyncError.conflict }; return value
            }
            guard result.operations[index].status == .sending, result.operations[index].lease == session,
                  result.operations[index].envelope.revisionID == revision else { throw CloudSyncError.staleLease }
            result.operations[index].status = .acknowledged; result.operations[index].acknowledgedRevisionID = revision
            result.operations[index].lease = nil
        case .fail(let id, let session, let conflict):
            guard value.session == session, let index = result.operations.firstIndex(where: { $0.id == id }),
                  result.operations[index].status == .sending, result.operations[index].lease == session else { throw CloudSyncError.staleLease }
            result.operations[index].status = conflict ? .conflict : .failed; result.operations[index].lease = nil
        case .cursor(let session, let expected, let next):
            guard value.session == session else { throw CloudSyncError.staleLease }
            guard value.currentCursor == expected, !next.isEmpty else { throw CloudSyncError.staleState }
            result.cursors.removeAll { $0.accountID == session.accountID }; result.cursors.append(CloudCursor(accountID: session.accountID, value: next))
        }
        result.version = version
        return result
    }
}
@MainActor
protocol CloudSyncRepository {
    func snapshot() async throws -> CloudSyncSnapshot
    func apply(_ command: CloudSyncCommand, expectedVersion: UUID, newVersion: UUID) async throws -> CloudSyncSnapshot
}
