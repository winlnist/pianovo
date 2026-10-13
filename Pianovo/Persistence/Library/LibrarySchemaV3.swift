import Foundation
import SwiftData

enum LibrarySchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        LibrarySchemaV2.models + [ProgrammeModel.self, ProgrammeRevisionModel.self]
    }

    @Model final class ProgrammeModel {
        @Attribute(.unique) var id: UUID
        var ownerID: UUID
        var currentRevisionID: UUID
        var isArchived: Bool
        init(_ template: LibraryProgrammeTemplate) {
            id = template.id.rawValue
            ownerID = template.ownerID.rawValue
            currentRevisionID = template.currentRevision.id.rawValue
            isArchived = template.isArchived
        }
    }

    @Model final class ProgrammeRevisionModel {
        @Attribute(.unique) var id: UUID
        var templateID: UUID
        var payload: Data
        init(_ revision: LibraryProgrammeTemplateRevision) throws {
            id = revision.id.rawValue
            templateID = revision.templateID.rawValue
            payload = try JSONEncoder().encode(revision)
        }
    }
}
