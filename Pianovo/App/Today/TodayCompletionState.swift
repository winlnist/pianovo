import Foundation

nonisolated enum TodayCompletionState: Equatable {
    case ready
    case saving(PracticeAssignmentID)
    case failed(PracticeAssignmentID, TodayCompletionFailure)

    var allowsNewAction: Bool { self == .ready }
    var assignmentID: PracticeAssignmentID? {
        switch self {
        case .ready: nil
        case .saving(let id), .failed(let id, _): id
        }
    }
}

nonisolated enum TodayCompletionFailure: Error, Equatable {
    case invalidAssignment, requiredComponentsMissing, positionChanged
    case persistenceUnavailable, progressLoadFailed, saveFailed, verificationFailed
}

/// A learner's explicit intent, retained unchanged for a retry.
nonisolated struct TodayCompletionRequest {
    let programme: ProgrammeDefinitionReference
    let weekID: ProgrammeWeekID
    let dayID: PracticeDayID
    let assignmentID: PracticeAssignmentID
    let sourceID: ExerciseSourceID
    let status: AssignmentCompletionStatus
    let timestamp: PracticeTimestamp
}

nonisolated extension TodayAssignmentState {
    var requiredCompletionComponents: [TodayReferenceMaterialComponentState] {
        // The two required parts stay explicit even if material resolution fails.
        if sourceID == ExerciseSourceID("beyer-op101-no-63") {
            return [
                TodayReferenceMaterialComponentState(id: ReferenceMaterialComponentID("beyer-op101-no-63-seconda")!,
                    role: .seconda, isRequiredForCompleteExercise: true, pdfKitPageIndex: nil, printedPageLabel: nil),
                TodayReferenceMaterialComponentState(id: ReferenceMaterialComponentID("beyer-op101-no-63-prima")!,
                    role: .prima, isRequiredForCompleteExercise: true, pdfKitPageIndex: nil, printedPageLabel: nil)
            ]
        }
        switch referenceMaterial {
        case .available(let summary), .knownUnavailable(let summary, _):
            return summary.components.filter(\.isRequiredForCompleteExercise)
        case .unknownSource: return []
        }
    }
}

nonisolated extension TodayLoadedState {
    func updatingCompletion(assignmentID: PracticeAssignmentID, status: AssignmentCompletionStatus) -> TodayLoadedState {
        func updated(_ blocks: [TodayPracticeBlockState]) -> [TodayPracticeBlockState] {
            blocks.map { block in
                TodayPracticeBlockState(id: block.id, title: block.title, category: block.category,
                    sessionSlot: block.sessionSlot, targetDurationMinutes: block.targetDurationMinutes,
                    isSuggested: block.isSuggested, assignments: block.assignments.map { assignment in
                        TodayAssignmentState(id: assignment.id, title: assignment.title, goal: assignment.goal,
                            sourceID: assignment.sourceID, sourceTitle: assignment.sourceTitle,
                            completionStatus: assignment.id == assignmentID ? status : assignment.completionStatus,
                            masteryState: assignment.masteryState, referenceMaterial: assignment.referenceMaterial)
                    })
            }
        }
        return TodayLoadedState(programme: programme, weekID: weekID, weekTitle: weekTitle,
            dayID: dayID, dayTitle: dayTitle, dayKind: dayKind, suggestedSessionSlot: suggestedSessionSlot,
            localDayKey: localDayKey, morningBlocks: updated(morningBlocks), eveningBlocks: updated(eveningBlocks),
            recoveryBlocks: updated(recoveryBlocks))
    }
}
