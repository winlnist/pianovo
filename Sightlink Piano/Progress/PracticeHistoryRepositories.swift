import Foundation

nonisolated enum PracticeHistoryRepositoryError: Error, Equatable {
    case duplicateID(String)
    case validationFailed([ProgressValidationIssue])
    case notFound(String)
}

nonisolated enum PracticeHistoryEvent: Hashable {
    case session(PracticeSessionRecord)
    case attempt(PerformanceAttemptRecord)
    case reflection(StudentReflectionRecord)
    case masteryDecision(MasteryDecisionRecord)

    var timestamp: PracticeTimestamp {
        switch self {
        case .session(let record):
            record.startedAt
        case .attempt(let record):
            record.occurredAt
        case .reflection(let record):
            record.createdAt
        case .masteryDecision(let record):
            record.decidedAt
        }
    }
}

protocol ProgrammeProgressRepository {
    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot?
    func saveActiveProgress(_ progress: ActiveProgrammeProgress) async throws
    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws
    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws
}

protocol PracticeHistoryRepository {
    func recordSession(_ session: PracticeSessionRecord) async throws
    func recordAttempt(_ attempt: PerformanceAttemptRecord) async throws
    func recordReflection(_ reflection: StudentReflectionRecord) async throws
    func recordMasteryDecision(_ decision: MasteryDecisionRecord) async throws
    func chronologicalHistory() async throws -> [PracticeHistoryEvent]
    func deleteSession(id: PracticeSessionRecordID) async throws
    func deleteAllPersonalPracticeData() async throws
}
