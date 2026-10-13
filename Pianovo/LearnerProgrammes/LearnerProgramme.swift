import Foundation

nonisolated struct LearnerPlanID: Hashable, Codable { let rawValue: UUID }
nonisolated struct LearnerPlanRevisionID: Hashable, Codable { let rawValue: UUID }
nonisolated struct LearnerPlanRevision: Identifiable, Equatable, Codable {
    let id: LearnerPlanRevisionID
    let planID: LearnerPlanID
    let parentID: LearnerPlanRevisionID?
    let content: LibraryProgrammeDraft
    let exercises: [LibraryExerciseRevision]
    let origin: LibraryProgrammeOrigin
    let createdAt: PracticeTimestamp
    func exercise(_ reference: LibraryExerciseReference) -> LibraryExerciseRevision? {
        exercises.first { $0.exerciseID == reference.exerciseID && $0.id == reference.revisionID }
    }
}
nonisolated struct LearnerCompletionRecord: Identifiable, Equatable, Codable {
    let id: UUID
    let revisionID: LearnerPlanRevisionID
    let dayID: UUID
    let assignmentID: UUID
    let exercise: LibraryExerciseReference
    let completed: Bool
    let timestamp: PracticeTimestamp
}
nonisolated struct LearnerPlan: Identifiable, Equatable, Codable {
    let id: LearnerPlanID
    let ownerID: LibraryOwnerID
    var revision: LearnerPlanRevision
    var version: UUID
    var currentDayID: UUID
    var reachedEnd = false
    var completions: [LearnerCompletionRecord] = []
    var days: [LibraryProgrammeDay] { revision.content.weeks.flatMap(\.days) }
    var currentDay: LibraryProgrammeDay? { days.first { $0.id == currentDayID } }
    func isCompleted(_ assignmentID: UUID) -> Bool { completions.last { $0.assignmentID == assignmentID }?.completed == true }
    var unfinishedCount: Int { currentDay?.sections.flatMap(\.placements).filter { !isCompleted($0.id) }.count ?? 0 }
    var currentDayIndex: Int? { days.firstIndex { $0.id == currentDayID } }
    func validate() throws {
        try revision.validate()
        guard revision.planID == id, currentDay != nil,
              Set(completions.map(\.id)).count == completions.count else { throw LearnerProgrammeError.corruptStore }
    }
}
nonisolated struct TodayProgrammeSelection: Equatable, Codable {
    // A stable read-only initial value. Missing selection means the existing programme, not a newly started plan.
    static let initial = Self(version: UUID(uuidString: "76CD918A-825E-46FB-BD18-E987A2699938")!, planID: nil)
    let version: UUID
    let planID: LearnerPlanID?
}
nonisolated struct LearnerProgrammeSnapshot: Equatable {
    var selection: TodayProgrammeSelection = .initial
    var plans: [LearnerPlan] = []
    var selectedPlan: LearnerPlan? { plans.first { $0.id == selection.planID } }
}
nonisolated enum LearnerProgrammeError: Error, Equatable {
    case invalid([LibraryProgrammeIssue]), missingReference, conflict, corruptStore, verificationFailed
    case unfinishedWork, invalidPosition, currentDayRemoved, unsupportedChange, unavailable
    var message: String {
        switch self {
        case .invalid(let issues): issues.map(\.message).joined(separator: " ")
        case .missingReference: "A saved template or exercise version is unavailable. Refresh before trying again."
        case .conflict: "The saved programme or selection changed. Refresh before making another change."
        case .corruptStore, .invalidPosition: "The saved programme could not be read safely. No position or progress has been reset."
        case .verificationFailed: "The change could not be confirmed in storage. Retry the same change or refresh to check."
        case .unfinishedWork: "There is unfinished work on this day. Confirm before continuing; its status will be kept."
        case .currentDayRemoved: "Keep the current saved day when editing this programme. You can move to another day before removing it."
        case .unsupportedChange: "The edit changes an existing structural identity in an unsupported way. Close and refresh before editing again."
        case .unavailable: "Saved learner programmes are unavailable. Reopen Pianovo or retry loading."
        }
    }
}
nonisolated enum LearnerProgrammeCommand: Equatable, Codable {
    case create(LearnerPlanID, LearnerPlanRevisionID, LibraryProgrammeDraft, LibraryProgrammeOrigin, PracticeTimestamp)
    case edit(LearnerPlanID, UUID, LearnerPlanRevisionID, LibraryProgrammeDraft, [UUID: UUID], PracticeTimestamp)
    case select(LearnerPlanID?)
    case complete(LearnerPlanID, UUID, UUID, UUID, Bool, PracticeTimestamp)
    case move(LearnerPlanID, UUID, UUID, Int, Bool)
}
nonisolated struct LearnerProgrammeRequest: Equatable, Codable {
    let id: UUID
    let expectedSelection: UUID?
    let command: LearnerProgrammeCommand
}

nonisolated extension LearnerPlanRevision {
    func validate() throws {
        let issues = content.validationIssues
        guard issues.isEmpty else { throw LearnerProgrammeError.invalid(issues) }
        guard createdAt.instant.timeIntervalSince1970.isFinite else { throw LearnerProgrammeError.corruptStore }
        let references = Set(exercises.map { LibraryExerciseReference(exerciseID: $0.exerciseID, revisionID: $0.id) })
        guard references == content.references, references.count == exercises.count,
              exercises.allSatisfy({ $0.content.validationIssues.isEmpty }) else { throw LearnerProgrammeError.missingReference }
    }
}

/// Shared transaction rules. Storage resolves immutable exercises; views cannot invent practice evidence.
nonisolated enum LearnerProgrammeRules {
    static func applying(_ request: LearnerProgrammeRequest, to snapshot: LearnerProgrammeSnapshot,
                         ownerID: LibraryOwnerID, exercises: [LibraryExerciseRevision] = []) throws -> LearnerProgrammeSnapshot {
        if let expected = request.expectedSelection, expected != snapshot.selection.version { throw LearnerProgrammeError.conflict }
        var result = snapshot
        switch request.command {
        case .select(let id):
            guard request.expectedSelection != nil else { throw LearnerProgrammeError.conflict }
            guard id == nil || result.plans.contains(where: { $0.id == id }) else { throw LearnerProgrammeError.invalidPosition }
            result.selection = TodayProgrammeSelection(version: request.id, planID: id)
        case .create(let id, let revisionID, let draft, let origin, let timestamp):
            guard !result.plans.contains(where: { $0.id == id }), request.expectedSelection != nil else { throw LearnerProgrammeError.conflict }
            let revision = LearnerPlanRevision(id: revisionID, planID: id, parentID: nil, content: draft.normalised,
                exercises: exercises, origin: origin, createdAt: timestamp)
            try revision.validate()
            guard let firstDay = revision.content.weeks.first?.days.first else { throw LearnerProgrammeError.invalidPosition }
            result.plans.append(LearnerPlan(id: id, ownerID: ownerID, revision: revision, version: request.id, currentDayID: firstDay.id))
            result.selection = TodayProgrammeSelection(version: request.id, planID: id)
        case .edit(let id, let version, let revisionID, let draft, let replacements, let timestamp):
            let index = try index(id, version: version, in: result)
            let old = result.plans[index].revision
            let content = try reconciled(draft.normalised, with: old.content, replacements: replacements)
            guard content.weeks.flatMap(\.days).contains(where: { $0.id == result.plans[index].currentDayID }) else { throw LearnerProgrammeError.currentDayRemoved }
            let currentIDs = Set(old.content.weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).map(\.id))
            let retiredCompletedIDs = Set(result.plans[index].completions.map(\.assignmentID)).subtracting(currentIDs)
            guard retiredCompletedIDs.isDisjoint(with: content.weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).map(\.id)) else { throw LearnerProgrammeError.unsupportedChange }
            let revision = LearnerPlanRevision(id: revisionID, planID: id, parentID: old.id, content: content,
                exercises: exercises, origin: old.origin, createdAt: timestamp)
            try revision.validate()
            result.plans[index].revision = revision
            result.plans[index].version = request.id
            // A changed plan needs a fresh explicit end action; its saved day and completion records remain intact.
            if content != old.content { result.plans[index].reachedEnd = false }
        case .complete(let id, let version, let dayID, let assignmentID, let completed, let timestamp):
            let index = try index(id, version: version, in: result)
            let plan = result.plans[index]
            guard request.expectedSelection != nil, result.selection.planID == id, plan.currentDayID == dayID,
                  let placement = plan.currentDay?.sections.flatMap(\.placements).first(where: { $0.id == assignmentID }),
                  timestamp.instant.timeIntervalSince1970.isFinite else { throw LearnerProgrammeError.invalidPosition }
            result.plans[index].completions.append(LearnerCompletionRecord(id: request.id, revisionID: plan.revision.id,
                dayID: dayID, assignmentID: assignmentID, exercise: placement.exercise, completed: completed, timestamp: timestamp))
            result.plans[index].version = request.id
        case .move(let id, let version, let dayID, let direction, let confirmed):
            let index = try index(id, version: version, in: result)
            let plan = result.plans[index]
            guard request.expectedSelection != nil, result.selection.planID == id, dayID == plan.currentDayID,
                  let current = plan.currentDayIndex, direction == 1 || direction == -1 else { throw LearnerProgrammeError.invalidPosition }
            if direction == 1 && plan.unfinishedCount > 0 && !confirmed { throw LearnerProgrammeError.unfinishedWork }
            let target = current + direction
            if target == plan.days.count && direction == 1 {
                guard !plan.reachedEnd else { throw LearnerProgrammeError.invalidPosition }
                result.plans[index].reachedEnd = true
            } else {
                guard target >= 0 && target < plan.days.count else { throw LearnerProgrammeError.invalidPosition }
                result.plans[index].currentDayID = plan.days[target].id
                result.plans[index].reachedEnd = false
            }
            result.plans[index].version = request.id
        }
        for plan in result.plans {
            let otherIDs = Set(result.plans.filter { $0.id != plan.id }.flatMap { Array($0.revision.content.structuralIDs) + $0.completions.map(\.assignmentID) })
            guard plan.revision.content.structuralIDs.isDisjoint(with: otherIDs) else { throw LearnerProgrammeError.unsupportedChange }
        }
        result.plans.sort { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
        for plan in result.plans { try plan.validate() }
        return result
    }
    private static func index(_ id: LearnerPlanID, version: UUID, in snapshot: LearnerProgrammeSnapshot) throws -> Int {
        guard let index = snapshot.plans.firstIndex(where: { $0.id == id }), snapshot.plans[index].version == version else { throw LearnerProgrammeError.conflict }
        return index
    }
    /// Retain status only for the same work in the same week/day/section. Replacements receive new occurrence IDs.
    static func reconciled(_ draft: LibraryProgrammeDraft, with original: LibraryProgrammeDraft, replacements: [UUID: UUID]) throws -> LibraryProgrammeDraft {
        let issues = draft.validationIssues
        guard issues.isEmpty else { throw LearnerProgrammeError.invalid(issues) }
        var result = draft
        for w in result.weeks.indices {
            for d in result.weeks[w].days.indices {
                for s in result.weeks[w].days[d].sections.indices {
                    for p in result.weeks[w].days[d].sections[s].placements.indices {
                        let placement = result.weeks[w].days[d].sections[s].placements[p]
                        let old = original.weeks.first { $0.id == result.weeks[w].id }?.days.first { $0.id == result.weeks[w].days[d].id }?
                            .sections.first { $0.id == result.weeks[w].days[d].sections[s].id }?.placements.first { $0.id == placement.id }
                        if old == placement { continue }
                        if original.weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).contains(where: { $0.id == placement.id }) {
                            guard let replacement = replacements[placement.id], replacement != placement.id,
                                  !original.weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).contains(where: { $0.id == replacement }) else {
                                throw LearnerProgrammeError.unsupportedChange
                            }
                            result.weeks[w].days[d].sections[s].placements[p] = LibraryProgrammePlacement(id: replacement,
                                exercise: placement.exercise, goal: placement.goal, minutes: placement.minutes)
                        }
                    }
                }
            }
        }
        guard result.validationIssues.isEmpty else { throw LearnerProgrammeError.unsupportedChange }
        return result
    }
}
