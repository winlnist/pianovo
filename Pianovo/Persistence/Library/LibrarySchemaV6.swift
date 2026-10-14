import Foundation
import SwiftData

enum LibrarySchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] { LibrarySchemaV5.models + [CloudStateModel.self] }
    @Model final class CloudStateModel {
        @Attribute(.unique) var key: String
        var payload: Data
        init(_ state: CloudSyncSnapshot) throws { key = "cloud-sync"; payload = try JSONEncoder().encode(state) }
    }
}
