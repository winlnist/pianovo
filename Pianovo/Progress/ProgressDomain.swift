import Foundation

nonisolated struct PracticeSessionRecordID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct PerformanceAttemptRecordID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct StudentReflectionRecordID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct MasteryDecisionRecordID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated enum PracticeCalendarIdentifier: String, Codable, Hashable {
    case gregorian

    var foundationIdentifier: Calendar.Identifier {
        switch self {
        case .gregorian:
            .gregorian
        }
    }
}

nonisolated struct LocalDayContext: Codable, Hashable {
    let calendarIdentifier: PracticeCalendarIdentifier
    let timeZoneIdentifier: String
    let year: Int
    let month: Int
    let day: Int

    var dayKey: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init(
        calendarIdentifier: PracticeCalendarIdentifier,
        timeZoneIdentifier: String,
        year: Int,
        month: Int,
        day: Int
    ) {
        self.calendarIdentifier = calendarIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.year = year
        self.month = month
        self.day = day
    }

    init(
        timestamp: Date,
        timeZone: TimeZone,
        calendarIdentifier: PracticeCalendarIdentifier = .gregorian
    ) {
        var calendar = Calendar(identifier: calendarIdentifier.foundationIdentifier)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: timestamp)

        self.init(
            calendarIdentifier: calendarIdentifier,
            timeZoneIdentifier: timeZone.identifier,
            year: components.year ?? 1,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }
}

nonisolated struct PracticeTimestamp: Codable, Hashable, Comparable {
    let instant: Date
    let localDay: LocalDayContext

    init(
        instant: Date,
        timeZone: TimeZone,
        calendarIdentifier: PracticeCalendarIdentifier = .gregorian
    ) {
        self.instant = instant
        self.localDay = LocalDayContext(
            timestamp: instant,
            timeZone: timeZone,
            calendarIdentifier: calendarIdentifier
        )
    }

    init(instant: Date, localDay: LocalDayContext) {
        self.instant = instant
        self.localDay = localDay
    }

    static func < (lhs: PracticeTimestamp, rhs: PracticeTimestamp) -> Bool {
        lhs.instant < rhs.instant
    }
}

nonisolated struct ProgrammeDefinitionReference: Codable, Hashable {
    let programmeID: PracticeProgrammeID
    let programmeVersion: Int
}

nonisolated struct PracticeRecordContext: Codable, Hashable {
    let programme: ProgrammeDefinitionReference
    let weekID: ProgrammeWeekID?
    let dayID: PracticeDayID?
    let blockID: PracticeBlockID?
    let assignmentID: PracticeAssignmentID?
    let sourceID: ExerciseSourceID?
}

nonisolated enum PracticeSessionOutcome: String, Codable, Hashable {
    case completed
    case stopped
    case abandoned
}

nonisolated struct PracticeSessionRecord: Identifiable, Codable, Hashable {
    let id: PracticeSessionRecordID
    let context: PracticeRecordContext
    let startedAt: PracticeTimestamp
    let endedAt: PracticeTimestamp?
    let outcome: PracticeSessionOutcome

    var duration: TimeInterval? {
        endedAt.map { $0.instant.timeIntervalSince(startedAt.instant) }
    }
}

nonisolated enum PerformanceAttemptOutcome: String, Codable, Hashable {
    case completed
    case stopped
    case abandoned
}

nonisolated struct PerformanceAttemptRecord: Identifiable, Codable, Hashable {
    let id: PerformanceAttemptRecordID
    let sessionID: PracticeSessionRecordID
    let context: PracticeRecordContext
    let occurredAt: PracticeTimestamp
    let outcome: PerformanceAttemptOutcome
}

nonisolated enum AssignmentCompletionStatus: String, Codable, Hashable {
    case notStarted
    case inProgress
    case completed
}

nonisolated struct AssignmentCompletionState: Codable, Hashable {
    let programme: ProgrammeDefinitionReference
    let assignmentID: PracticeAssignmentID
    let sourceID: ExerciseSourceID
    let status: AssignmentCompletionStatus
    let updatedAt: PracticeTimestamp
    let completedAt: PracticeTimestamp?
    let note: String?
}

nonisolated struct ActiveProgrammeProgress: Codable, Hashable {
    let programme: ProgrammeDefinitionReference
    let currentWeekID: ProgrammeWeekID?
    let currentDayID: PracticeDayID?
    let updatedAt: PracticeTimestamp
}

nonisolated struct ProgrammeProgressSnapshot: Codable, Hashable {
    let activeProgress: ActiveProgrammeProgress?
    let assignmentCompletions: [AssignmentCompletionState]
}

nonisolated struct StudentReflectionRecord: Identifiable, Codable, Hashable {
    let id: StudentReflectionRecordID
    let programme: ProgrammeDefinitionReference?
    let weekID: ProgrammeWeekID?
    let dayID: PracticeDayID?
    let sessionID: PracticeSessionRecordID?
    let note: String
    let createdAt: PracticeTimestamp
}

nonisolated enum MasteryDecisionSource: String, Codable, Hashable {
    case automatic
    case manual
}

nonisolated struct MasteryDecisionRecord: Identifiable, Codable, Hashable {
    let id: MasteryDecisionRecordID
    let programme: ProgrammeDefinitionReference
    let assignmentID: PracticeAssignmentID
    let sourceID: ExerciseSourceID
    let decisionSource: MasteryDecisionSource
    let resultingState: MasteryState
    let masteryRuleID: MasteryRuleID?
    let masteryRuleVersion: Int?
    let reason: String?
    let decidedAt: PracticeTimestamp
}

nonisolated enum ProgressValidationCode: String, Hashable {
    case duplicateID
    case missingRequiredReference
    case missingRequiredField
    case invalidTemporalRange
    case negativeDuration
    case invalidProgrammeVersion
    case invalidMasteryRuleVersion
    case unresolvedSessionReference
}

nonisolated struct ProgressValidationIssue: Hashable {
    let code: ProgressValidationCode
    let path: String
    let message: String
}

nonisolated struct ProgressRecordValidator {
    func validateActiveProgress(_ progress: ActiveProgrammeProgress) -> [ProgressValidationIssue] {
        validateProgramme(progress.programme, path: "activeProgress.programme")
    }

    func validateCompletion(_ completion: AssignmentCompletionState) -> [ProgressValidationIssue] {
        var issues = validateProgramme(completion.programme, path: "assignmentCompletion.programme")

        if completion.completedAt?.instant.timeIntervalSince(completion.updatedAt.instant) ?? 0 < 0 {
            issues.append(
                ProgressValidationIssue(
                    code: .invalidTemporalRange,
                    path: "assignmentCompletion.completedAt",
                    message: "Completion timestamp cannot precede the update timestamp."
                )
            )
        }

        return issues
    }

    func validateSession(_ session: PracticeSessionRecord) -> [ProgressValidationIssue] {
        var issues = validateContext(session.context, path: "session.context")

        if let duration = session.duration, duration < 0 {
            issues.append(
                ProgressValidationIssue(
                    code: .negativeDuration,
                    path: "session.duration",
                    message: "Session duration cannot be negative."
                )
            )
            issues.append(
                ProgressValidationIssue(
                    code: .invalidTemporalRange,
                    path: "session.endedAt",
                    message: "Session end cannot precede session start."
                )
            )
        }

        return issues
    }

    func validateAttempt(
        _ attempt: PerformanceAttemptRecord,
        knownSessionIDs: Set<PracticeSessionRecordID>
    ) -> [ProgressValidationIssue] {
        var issues = validateContext(attempt.context, path: "attempt.context")

        if !knownSessionIDs.contains(attempt.sessionID) {
            issues.append(
                ProgressValidationIssue(
                    code: .unresolvedSessionReference,
                    path: "attempt.sessionID",
                    message: "Attempt must reference an existing session."
                )
            )
        }

        return issues
    }

    func validateReflection(
        _ reflection: StudentReflectionRecord,
        knownSessionIDs: Set<PracticeSessionRecordID>
    ) -> [ProgressValidationIssue] {
        var issues: [ProgressValidationIssue] = []

        if reflection.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missing(path: "reflection.note"))
        }

        if reflection.programme == nil && reflection.dayID == nil && reflection.sessionID == nil {
            issues.append(
                ProgressValidationIssue(
                    code: .missingRequiredReference,
                    path: "reflection.context",
                    message: "Reflection must reference a programme day, a session, or both."
                )
            )
        }

        if let programme = reflection.programme {
            issues += validateProgramme(programme, path: "reflection.programme")
        }

        if let sessionID = reflection.sessionID, !knownSessionIDs.contains(sessionID) {
            issues.append(
                ProgressValidationIssue(
                    code: .unresolvedSessionReference,
                    path: "reflection.sessionID",
                    message: "Session-owned reflection must reference an existing session."
                )
            )
        }

        return issues
    }

    func validateMasteryDecision(_ decision: MasteryDecisionRecord) -> [ProgressValidationIssue] {
        var issues = validateProgramme(decision.programme, path: "masteryDecision.programme")

        if decision.masteryRuleID != nil && decision.masteryRuleVersion == nil {
            issues.append(
                ProgressValidationIssue(
                    code: .invalidMasteryRuleVersion,
                    path: "masteryDecision.masteryRuleVersion",
                    message: "A mastery decision produced by a rule must retain the rule version."
                )
            )
        }

        if let version = decision.masteryRuleVersion, version <= 0 {
            issues.append(
                ProgressValidationIssue(
                    code: .invalidMasteryRuleVersion,
                    path: "masteryDecision.masteryRuleVersion",
                    message: "Mastery rule version must be positive."
                )
            )
        }

        return issues
    }

    private func validateContext(_ context: PracticeRecordContext, path: String) -> [ProgressValidationIssue] {
        var issues = validateProgramme(context.programme, path: "\(path).programme")

        if context.assignmentID == nil {
            issues.append(.missing(path: "\(path).assignmentID"))
        }

        if context.sourceID == nil {
            issues.append(.missing(path: "\(path).sourceID"))
        }

        return issues
    }

    private func validateProgramme(_ programme: ProgrammeDefinitionReference, path: String) -> [ProgressValidationIssue] {
        guard programme.programmeVersion > 0 else {
            return [
                ProgressValidationIssue(
                    code: .invalidProgrammeVersion,
                    path: "\(path).programmeVersion",
                    message: "Programme version must be positive."
                )
            ]
        }

        return []
    }
}

private extension ProgressValidationIssue {
    nonisolated static func missing(path: String) -> ProgressValidationIssue {
        ProgressValidationIssue(
            code: .missingRequiredField,
            path: path,
            message: "Required field is missing."
        )
    }
}
