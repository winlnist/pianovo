import Foundation
import SwiftData

@MainActor
final class SwiftDataLearnerProgrammeRepository: LearnerProgrammeRepository {
    private let container: ModelContainer
    private let save: (ModelContext) throws -> Void
    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.container = container; self.save = save
    }
    func snapshot() async throws -> LearnerProgrammeSnapshot { try read(ModelContext(container)) }
    func revisions(for id: LearnerPlanID) async throws -> [LearnerPlanRevision] { try history(id, in: ModelContext(container)) }
    func apply(_ request: LearnerProgrammeRequest) async throws -> LearnerProgrammeSnapshot {
        let writer = ModelContext(container); writer.autosaveEnabled = false
        do {
            if let receipt = try writer.fetch(FetchDescriptor<LibrarySchemaV4.ReceiptModel>()).first(where: { $0.id == request.id }) {
                guard try JSONDecoder().decode(LearnerProgrammeRequest.self, from: receipt.payload) == request else { throw LearnerProgrammeError.conflict }
                return try read(writer)
            }
            let previous = try read(writer)
            let identity = try writer.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first { $0.key == "local-owner" }
            let owner = identity.map { LibraryOwnerID(rawValue: $0.ownerID) } ?? LibraryOwnerID(rawValue: UUID())
            var resolved: [LibraryExerciseRevision] = []
            var content: LibraryProgrammeDraft?
            switch request.command {
            case .create(_, _, let draft, let origin, _):
                let rows = try writer.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeRevisionModel>())
                guard let row = rows.first(where: { $0.id == origin.revisionID.rawValue && $0.templateID == origin.templateID.rawValue }),
                      let revision = try? JSONDecoder().decode(LibraryProgrammeTemplateRevision.self, from: row.payload),
                      revision.id == origin.revisionID, revision.templateID == origin.templateID,
                      revision.content.name == origin.name, revision.origin?.creatorAttribution == origin.creatorAttribution else { throw LearnerProgrammeError.missingReference }
                guard draft.structuralIDs.isDisjoint(with: revision.content.structuralIDs) else { throw LearnerProgrammeError.unsupportedChange }
                content = draft
            case .edit(_, _, _, let draft, _, _): content = draft
            default: break
            }
            if let content {
                let rows = try writer.fetch(FetchDescriptor<LibrarySchemaV1.RevisionModel>())
                for reference in content.references {
                    guard let row = rows.first(where: { $0.id == reference.revisionID.rawValue && $0.exerciseID == reference.exerciseID.rawValue }),
                          let revision = try? JSONDecoder().decode(LibraryExerciseRevision.self, from: row.payload),
                          revision.id == reference.revisionID, revision.exerciseID == reference.exerciseID else { throw LearnerProgrammeError.missingReference }
                    resolved.append(revision)
                }
            }
            let result = try LearnerProgrammeRules.applying(request, to: previous, ownerID: owner, exercises: resolved)
            let heads = try writer.fetch(FetchDescriptor<LibrarySchemaV4.LearnerPlanModel>())
            let revisions = try writer.fetch(FetchDescriptor<LibrarySchemaV4.LearnerRevisionModel>())
            for plan in result.plans {
                if let head = heads.first(where: { $0.id == plan.id.rawValue }) {
                    let encoded = try JSONEncoder().encode(plan)
                    if head.payload != encoded { head.payload = encoded }
                }
                else { writer.insert(try LibrarySchemaV4.LearnerPlanModel(plan)) }
                if let row = revisions.first(where: { $0.id == plan.revision.id.rawValue }) {
                    guard try JSONDecoder().decode(LearnerPlanRevision.self, from: row.payload) == plan.revision else { throw LearnerProgrammeError.conflict }
                } else { writer.insert(try LibrarySchemaV4.LearnerRevisionModel(plan.revision)) }
            }
            if identity == nil && !result.plans.isEmpty { writer.insert(LibrarySchemaV1.IdentityModel(ownerID: owner)) }
            if let selection = try writer.fetch(FetchDescriptor<LibrarySchemaV4.SelectionModel>()).first(where: { $0.key == "today-programme" }) {
                selection.payload = try JSONEncoder().encode(result.selection)
            } else { writer.insert(try LibrarySchemaV4.SelectionModel(result.selection)) }
            writer.insert(try LibrarySchemaV4.ReceiptModel(request))
            try save(writer)
            let durable = try read(ModelContext(container))
            guard durable == result else { throw LearnerProgrammeError.verificationFailed }
            return durable
        } catch { writer.rollback(); throw error }
    }
    private func read(_ context: ModelContext) throws -> LearnerProgrammeSnapshot {
        var result = LearnerProgrammeSnapshot()
        let identity = try context.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first { $0.key == "local-owner" }
        for row in try context.fetch(FetchDescriptor<LibrarySchemaV4.LearnerPlanModel>()) {
            let plan = try JSONDecoder().decode(LearnerPlan.self, from: row.payload)
            try plan.validate()
            guard plan.id.rawValue == row.id, plan.ownerID.rawValue == identity?.ownerID,
                  try history(plan.id, in: context).last == plan.revision else { throw LearnerProgrammeError.corruptStore }
            let revisions = try history(plan.id, in: context)
            for completion in plan.completions {
                guard let revision = revisions.first(where: { $0.id == completion.revisionID }),
                      let day = revision.content.weeks.flatMap(\.days).first(where: { $0.id == completion.dayID }),
                      day.sections.flatMap(\.placements).contains(where: { $0.id == completion.assignmentID && $0.exercise == completion.exercise }),
                      completion.timestamp.instant.timeIntervalSince1970.isFinite else { throw LearnerProgrammeError.corruptStore }
            }
            result.plans.append(plan)
        }
        result.plans.sort { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
        if let row = try context.fetch(FetchDescriptor<LibrarySchemaV4.SelectionModel>()).first(where: { $0.key == "today-programme" }) {
            result.selection = try JSONDecoder().decode(TodayProgrammeSelection.self, from: row.payload)
        }
        guard result.selection.planID == nil || result.selectedPlan != nil else { throw LearnerProgrammeError.corruptStore }
        return result
    }
    private func history(_ id: LearnerPlanID, in context: ModelContext) throws -> [LearnerPlanRevision] {
        let rows = try context.fetch(FetchDescriptor<LibrarySchemaV4.LearnerRevisionModel>()).filter { $0.planID == id.rawValue }
        var values: [LearnerPlanRevision] = []
        for row in rows {
            let value = try JSONDecoder().decode(LearnerPlanRevision.self, from: row.payload); try value.validate()
            guard value.id.rawValue == row.id, value.planID == id else { throw LearnerProgrammeError.corruptStore }
            values.append(value)
        }
        // Parent links determine order; wall-clock changes do not reorder immutable revisions.
        var ordered: [LearnerPlanRevision] = []
        var next = values.first { $0.parentID == nil }
        while let current = next {
            guard !ordered.contains(where: { $0.id == current.id }) else { throw LearnerProgrammeError.corruptStore }
            ordered.append(current)
            let children = values.filter { $0.parentID == current.id }
            guard children.count <= 1 else { throw LearnerProgrammeError.corruptStore }
            next = children.first
        }
        guard ordered.count == values.count else { throw LearnerProgrammeError.corruptStore }
        return ordered
    }
}
