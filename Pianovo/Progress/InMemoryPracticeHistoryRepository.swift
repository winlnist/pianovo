import Foundation

actor InMemoryPracticeHistoryRepository: ProgrammeProgressRepository, PracticeHistoryRepository {
    private var activeProgressByProgrammeID: [PracticeProgrammeID: ActiveProgrammeProgress] = [:]
    private var completionsByAssignmentID: [PracticeAssignmentID: AssignmentCompletionState] = [:]
    private var sessionsByID: [PracticeSessionRecordID: PracticeSessionRecord] = [:]
    private var attemptsByID: [PerformanceAttemptRecordID: PerformanceAttemptRecord] = [:]
    private var reflectionsByID: [StudentReflectionRecordID: StudentReflectionRecord] = [:]
    private var masteryDecisionsByID: [MasteryDecisionRecordID: MasteryDecisionRecord] = [:]
    private let validator = ProgressRecordValidator()

    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot? {
        let activeProgress = activeProgressByProgrammeID[programmeID]
        let completions = completionsByAssignmentID.values
            .filter { $0.programme.programmeID == programmeID }
            .sorted { $0.updatedAt.instant < $1.updatedAt.instant }

        guard activeProgress != nil || !completions.isEmpty else {
            return nil
        }

        return ProgrammeProgressSnapshot(
            activeProgress: activeProgress,
            assignmentCompletions: completions
        )
    }

    func saveActiveProgress(_ progress: ActiveProgrammeProgress) async throws {
        try validate(validator.validateActiveProgress(progress))
        activeProgressByProgrammeID[progress.programme.programmeID] = progress
    }

    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws {
        try validate(validator.validateCompletion(completion))
        completionsByAssignmentID[completion.assignmentID] = completion
    }

    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws {
        activeProgressByProgrammeID[programmeID] = nil
        completionsByAssignmentID = completionsByAssignmentID.filter {
            $0.value.programme.programmeID != programmeID
        }
        masteryDecisionsByID = masteryDecisionsByID.filter {
            $0.value.programme.programmeID != programmeID
        }
    }

    func recordSession(_ session: PracticeSessionRecord) async throws {
        try validate(validator.validateSession(session))
        guard sessionsByID[session.id] == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(session.id.rawValue)
        }

        sessionsByID[session.id] = session
    }

    func recordAttempt(_ attempt: PerformanceAttemptRecord) async throws {
        guard attemptsByID[attempt.id] == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(attempt.id.rawValue)
        }

        try validate(validator.validateAttempt(attempt, knownSessionIDs: Set(sessionsByID.keys)))
        attemptsByID[attempt.id] = attempt
    }

    func recordReflection(_ reflection: StudentReflectionRecord) async throws {
        guard reflectionsByID[reflection.id] == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(reflection.id.rawValue)
        }

        try validate(validator.validateReflection(reflection, knownSessionIDs: Set(sessionsByID.keys)))
        reflectionsByID[reflection.id] = reflection
    }

    func recordMasteryDecision(_ decision: MasteryDecisionRecord) async throws {
        guard masteryDecisionsByID[decision.id] == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(decision.id.rawValue)
        }

        try validate(validator.validateMasteryDecision(decision))
        masteryDecisionsByID[decision.id] = decision
    }

    func latestMasteryDecisions(programmeID: PracticeProgrammeID) async throws -> [MasteryDecisionRecord] {
        latestMasteryDecisions(from: masteryDecisionsByID.values.filter { $0.programme.programmeID == programmeID })
    }

    func chronologicalHistory() async throws -> [PracticeHistoryEvent] {
        let events: [PracticeHistoryEvent] =
            sessionsByID.values.map(PracticeHistoryEvent.session)
            + attemptsByID.values.map(PracticeHistoryEvent.attempt)
            + reflectionsByID.values.map(PracticeHistoryEvent.reflection)
            + masteryDecisionsByID.values.map(PracticeHistoryEvent.masteryDecision)

        return events.sorted { first, second in
            if first.timestamp.instant == second.timestamp.instant {
                return sortKey(first) < sortKey(second)
            }

            return first.timestamp.instant < second.timestamp.instant
        }
    }

    func deleteSession(id: PracticeSessionRecordID) async throws {
        guard sessionsByID[id] != nil else {
            throw PracticeHistoryRepositoryError.notFound(id.rawValue)
        }

        sessionsByID[id] = nil
        attemptsByID = attemptsByID.filter { $0.value.sessionID != id }
        reflectionsByID = reflectionsByID.filter { $0.value.sessionID != id }
    }

    func deleteAllPersonalPracticeData() async throws {
        activeProgressByProgrammeID.removeAll()
        completionsByAssignmentID.removeAll()
        sessionsByID.removeAll()
        attemptsByID.removeAll()
        reflectionsByID.removeAll()
        masteryDecisionsByID.removeAll()
    }

    private func validate(_ issues: [ProgressValidationIssue]) throws {
        guard issues.isEmpty else {
            throw PracticeHistoryRepositoryError.validationFailed(issues)
        }
    }

    private func sortKey(_ event: PracticeHistoryEvent) -> String {
        switch event {
        case .session(let record):
            "0-\(record.id.rawValue)"
        case .attempt(let record):
            "1-\(record.id.rawValue)"
        case .reflection(let record):
            "2-\(record.id.rawValue)"
        case .masteryDecision(let record):
            "3-\(record.id.rawValue)"
        }
    }

    private func latestMasteryDecisions(from decisions: [MasteryDecisionRecord]) -> [MasteryDecisionRecord] {
        var latestByTarget: [String: MasteryDecisionRecord] = [:]

        for decision in decisions {
            let key = masteryTargetKey(decision)
            guard let current = latestByTarget[key] else {
                latestByTarget[key] = decision
                continue
            }

            if isLaterMasteryDecision(decision, than: current) {
                latestByTarget[key] = decision
            }
        }

        return latestByTarget.values.sorted {
            masteryTargetKey($0) < masteryTargetKey($1)
        }
    }

    private func isLaterMasteryDecision(
        _ candidate: MasteryDecisionRecord,
        than current: MasteryDecisionRecord
    ) -> Bool {
        if candidate.decidedAt.instant != current.decidedAt.instant {
            return candidate.decidedAt.instant > current.decidedAt.instant
        }

        return candidate.id.rawValue > current.id.rawValue
    }

    private func masteryTargetKey(_ decision: MasteryDecisionRecord) -> String {
        "\(decision.assignmentID.rawValue)|\(decision.sourceID.rawValue)"
    }
}
