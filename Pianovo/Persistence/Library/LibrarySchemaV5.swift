import Foundation
import SwiftData

enum LibrarySchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] { LibrarySchemaV4.models + [PrivateNoteModel.self] }
    @Model final class PrivateNoteModel {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ note: PrivateLearnerNote) throws { id = note.id; payload = try JSONEncoder().encode(note) }
    }
}
