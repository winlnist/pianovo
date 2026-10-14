import Foundation
import SwiftData

/// Unwired foundation: caller session events must come from a real authenticated broker in 6F.12B.
@MainActor
final class SwiftDataCloudSyncRepository: CloudSyncRepository {
    private let container: ModelContainer
    private let save: (ModelContext) throws -> Void
    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) { self.container = container; self.save = save }
    func snapshot() async throws -> CloudSyncSnapshot { try read(ModelContext(container)) }
    func apply(_ command: CloudSyncCommand, expectedVersion: UUID, newVersion: UUID) async throws -> CloudSyncSnapshot {
        let writer = ModelContext(container); writer.autosaveEnabled = false
        do {
            let previous = try read(writer)
            let receipt = CloudTransitionReceipt(id: newVersion, expectedVersion: expectedVersion, command: command)
            // Return current state rather than replaying a transition over later account/session work.
            if let saved = previous.receipts.first(where: { $0.id == newVersion }) {
                guard saved == receipt else { throw CloudSyncError.conflict }
                return previous
            }
            guard previous.version == expectedVersion, newVersion != expectedVersion,
                  newVersion != CloudSyncSnapshot.initial.version else { throw CloudSyncError.staleState }
            var result = try CloudSyncRules.applying(command, to: previous, version: newVersion)
            result.version = newVersion
            result.receipts.append(receipt)
            if let row = try writer.fetch(FetchDescriptor<LibrarySchemaV6.CloudStateModel>()).first(where: { $0.key == "cloud-sync" }) {
                row.payload = try JSONEncoder().encode(result)
            } else { writer.insert(try LibrarySchemaV6.CloudStateModel(result)) }
            try save(writer)
            let durable = try read(ModelContext(container))
            guard durable == result else { throw CloudSyncError.verificationFailed }
            return durable
        } catch { writer.rollback(); throw error }
    }
    private func read(_ context: ModelContext) throws -> CloudSyncSnapshot {
        guard let row = try context.fetch(FetchDescriptor<LibrarySchemaV6.CloudStateModel>()).first(where: { $0.key == "cloud-sync" }) else { return .initial }
        let value = try JSONDecoder().decode(CloudSyncSnapshot.self, from: row.payload)
        guard Set(value.operations.map(\.id)).count == value.operations.count,
              Set(value.links.map(\.localOwnerID)).count == value.links.count,
              Set(value.cursors.map(\.accountID)).count == value.cursors.count,
              Set(value.receipts.map(\.id)).count == value.receipts.count else { throw CloudSyncError.corruptStore }
        for operation in value.operations {
            try operation.envelope.validate()
            guard (operation.status == .sending) == (operation.lease != nil),
                  (operation.status == .acknowledged) == (operation.acknowledgedRevisionID != nil),
                  operation.lease == nil || (operation.lease == value.session && value.canSend(operation.envelope)),
                  operation.acknowledgedRevisionID == nil || operation.acknowledgedRevisionID == operation.envelope.revisionID
            else { throw CloudSyncError.corruptStore }
        }
        return value
    }
}
