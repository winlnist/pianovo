import Foundation

nonisolated enum TodayViewState: Equatable {
    case idle
    case loading
    case loaded(TodayLoadedState)
    case programmeNotStarted(TodayProgrammeSummary)
    case noProgrammeAvailable(TodayLoadingFailure)
    case failure(TodayLoadingFailure)
}

nonisolated enum TodayLoadingFailure: Equatable {
    case persistenceUnavailable
    case progressLoadFailed
    case masteryLoadFailed
    case invalidPersistedPosition(TodayInvalidPosition)
    case programmeDefinitionUnavailable
    case unknown
}

nonisolated struct TodayInvalidPosition: Equatable {
    let weekID: ProgrammeWeekID?
    let dayID: PracticeDayID?
}

nonisolated struct TodayProgrammeSummary: Equatable {
    let programmeID: PracticeProgrammeID
    let programmeVersion: Int
    let title: String
}

nonisolated struct TodayLoadedState: Equatable {
    let programme: TodayProgrammeSummary
    let weekID: ProgrammeWeekID
    let weekTitle: String
    let dayID: PracticeDayID
    let dayTitle: String
    let dayKind: PracticeDayKind
    let suggestedSessionSlot: PracticeSessionSlot?
    let localDayKey: String
    let morningBlocks: [TodayPracticeBlockState]
    let eveningBlocks: [TodayPracticeBlockState]
    let recoveryBlocks: [TodayPracticeBlockState]

    var hasPartialReferenceMaterialAvailability: Bool {
        allBlocks
            .flatMap(\.assignments)
            .contains(where: { assignment in
                if case .knownUnavailable = assignment.referenceMaterial {
                    return true
                }

                return false
            })
    }

    var allBlocks: [TodayPracticeBlockState] {
        morningBlocks + eveningBlocks + recoveryBlocks
    }
}

nonisolated struct TodayPracticeBlockState: Equatable, Identifiable {
    let id: PracticeBlockID
    let title: String
    let category: PracticeCategory
    let sessionSlot: PracticeSessionSlot
    let targetDurationMinutes: Int
    let isSuggested: Bool
    let assignments: [TodayAssignmentState]
}

nonisolated struct TodayAssignmentState: Equatable, Identifiable {
    let id: PracticeAssignmentID
    let title: String
    let goal: String
    let sourceID: ExerciseSourceID
    let sourceTitle: String
    let completionStatus: AssignmentCompletionStatus
    let masteryState: MasteryState?
    let referenceMaterial: TodayReferenceMaterialState
}

nonisolated enum TodayReferenceMaterialState: Equatable {
    case unknownSource
    case knownUnavailable(TodayReferenceMaterialSummary, DocumentUnavailableReason)
    case available(TodayReferenceMaterialSummary)
}

nonisolated struct TodayReferenceMaterialSummary: Equatable {
    let id: ReferenceMaterialID
    let title: String
    let components: [TodayReferenceMaterialComponentState]
}

nonisolated struct TodayReferenceMaterialComponentState: Equatable, Identifiable {
    let id: ReferenceMaterialComponentID
    let role: ReferenceMaterialComponentRole
    let isRequiredForCompleteExercise: Bool
    let pdfKitPageIndex: Int?
    let printedPageLabel: String?
}

nonisolated enum TodayStartState: Equatable {
    case ready
    case starting
    case failed(TodayStartFailure)
}

nonisolated enum TodayStartFailure: Equatable {
    case persistenceUnavailable
    case programmeDefinitionUnavailable
    case progressLoadFailed
    case progressSaveFailed
}
