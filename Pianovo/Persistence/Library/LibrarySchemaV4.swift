import Foundation
import SwiftData

enum LibrarySchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        LibrarySchemaV3.models + [LearnerPlanModel.self, LearnerRevisionModel.self, SelectionModel.self, ReceiptModel.self]
    }
    @Model final class LearnerPlanModel {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ plan: LearnerPlan) throws { id = plan.id.rawValue; payload = try JSONEncoder().encode(plan) }
    }
    @Model final class LearnerRevisionModel {
        @Attribute(.unique) var id: UUID
        var planID: UUID
        var payload: Data
        init(_ revision: LearnerPlanRevision) throws {
            id = revision.id.rawValue; planID = revision.planID.rawValue; payload = try JSONEncoder().encode(revision)
        }
    }
    @Model final class SelectionModel {
        @Attribute(.unique) var key: String
        var payload: Data
        init(_ selection: TodayProgrammeSelection) throws { key = "today-programme"; payload = try JSONEncoder().encode(selection) }
    }
    @Model final class ReceiptModel {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ request: LearnerProgrammeRequest) throws { id = request.id; payload = try JSONEncoder().encode(request) }
    }
}
