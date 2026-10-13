import Foundation

@MainActor
protocol LearnerProgrammeRepository {
    func snapshot() async throws -> LearnerProgrammeSnapshot
    func revisions(for id: LearnerPlanID) async throws -> [LearnerPlanRevision]
    func apply(_ request: LearnerProgrammeRequest) async throws -> LearnerProgrammeSnapshot
}

@MainActor
final class InMemoryLearnerProgrammeRepository: LearnerProgrammeRepository {
    private var value = LearnerProgrammeSnapshot()
    private var history: [LearnerPlanID: [LearnerPlanRevision]] = [:]
    private var receipts: [UUID: LearnerProgrammeRequest] = [:]
    private let ownerID: LibraryOwnerID
    private let exercises: any LibraryExerciseRepository
    private let templates: any LibraryProgrammeTemplateRepository
    init(ownerID: LibraryOwnerID = LibraryOwnerID(rawValue: UUID()), exercises: any LibraryExerciseRepository,
         templates: any LibraryProgrammeTemplateRepository) {
        self.ownerID = ownerID; self.exercises = exercises; self.templates = templates
    }
    func snapshot() async throws -> LearnerProgrammeSnapshot { value }
    func revisions(for id: LearnerPlanID) async throws -> [LearnerPlanRevision] {
        guard let revisions = history[id] else { throw LearnerProgrammeError.missingReference }; return revisions
    }
    func apply(_ request: LearnerProgrammeRequest) async throws -> LearnerProgrammeSnapshot {
        if let previous = receipts[request.id] {
            guard previous == request else { throw LearnerProgrammeError.conflict }; return value
        }
        var resolved: [LibraryExerciseRevision] = []
        var content: LibraryProgrammeDraft?
        switch request.command {
        case .create(_, _, let draft, let origin, _):
            let revisions = try await templates.revisionHistory(for: origin.templateID)
            guard let source = revisions.first(where: { $0.id == origin.revisionID && $0.content.name == origin.name && $0.origin?.creatorAttribution == origin.creatorAttribution }) else { throw LearnerProgrammeError.missingReference }
            guard draft.structuralIDs.isDisjoint(with: source.content.structuralIDs) else { throw LearnerProgrammeError.unsupportedChange }
            content = draft
        case .edit(_, _, _, let draft, _, _): content = draft
        default: break
        }
        if let content {
            for reference in content.references {
                let revisions = try await exercises.revisionHistory(for: reference.exerciseID)
                guard let revision = revisions.first(where: { $0.id == reference.revisionID }) else { throw LearnerProgrammeError.missingReference }
                resolved.append(revision)
            }
        }
        if let previous = receipts[request.id] {
            guard previous == request else { throw LearnerProgrammeError.conflict }; return value
        }
        let result = try LearnerProgrammeRules.applying(request, to: value, ownerID: ownerID, exercises: resolved)
        for plan in result.plans where !(history[plan.id] ?? []).contains(plan.revision) { history[plan.id, default: []].append(plan.revision) }
        value = result; receipts[request.id] = request
        return value
    }
}
