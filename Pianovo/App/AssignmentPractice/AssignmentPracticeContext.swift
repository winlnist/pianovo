import Foundation

/// A snapshot of the selected hierarchy, never reconstructed from identifier strings.
nonisolated struct AssignmentPracticeContext: Identifiable, Equatable {
    let recordContext: PracticeRecordContext
    let blockCategory: PracticeCategory
    let title: String
    let goal: String
    let plannedDurationMinutes: Int

    var id: PracticeAssignmentID { recordContext.assignmentID! }

    init?(day: TodayLoadedState, blockID: PracticeBlockID, assignmentID: PracticeAssignmentID) {
        guard day.programme.programmeVersion > 0,
              let block = day.allBlocks.first(where: { $0.id == blockID }),
              block.category == .sightReading,
              block.targetDurationMinutes > 0,
              let assignment = block.assignments.first(where: { $0.id == assignmentID }),
              assignment.sourceID == ExerciseSourceID("generated-sight-reading-current-range") else { return nil }
        recordContext = PracticeRecordContext(
            programme: ProgrammeDefinitionReference(programmeID: day.programme.programmeID,
                                                    programmeVersion: day.programme.programmeVersion),
            weekID: day.weekID, dayID: day.dayID, blockID: block.id,
            assignmentID: assignment.id, sourceID: assignment.sourceID
        )
        blockCategory = block.category
        title = assignment.title
        goal = assignment.goal
        plannedDurationMinutes = block.targetDurationMinutes
    }
}
