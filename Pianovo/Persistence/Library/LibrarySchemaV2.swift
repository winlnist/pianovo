import Foundation
import SwiftData

enum LibrarySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        LibrarySchemaV1.models + [TemplateModel.self, TemplateRevisionModel.self]
    }

    @Model final class TemplateModel {
        @Attribute(.unique) var id: UUID
        var ownerID: UUID
        var currentRevisionID: UUID
        var isArchived: Bool
        init(_ template: LibraryExerciseTemplate) {
            id = template.id.rawValue
            ownerID = template.ownerID.rawValue
            currentRevisionID = template.currentRevision.id.rawValue
            isArchived = template.isArchived
        }
    }

    @Model final class TemplateRevisionModel {
        @Attribute(.unique) var id: UUID
        var templateID: UUID
        var payload: Data
        init(_ revision: LibraryExerciseTemplateRevision) throws {
            id = revision.id.rawValue
            templateID = revision.templateID.rawValue
            payload = try JSONEncoder().encode(revision)
        }
    }
}
