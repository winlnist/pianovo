import Foundation
import Testing
@testable import Sightlink_Piano

struct ProgressDomainTests {
    @Test func sessionEndCannotPrecedeStart() throws {
        let session = try Fixtures.session(
            startedAt: Fixtures.timestamp("2026-09-01T10:00:00Z", timeZoneID: "Europe/London"),
            endedAt: Fixtures.timestamp("2026-09-01T09:59:59Z", timeZoneID: "Europe/London")
        )

        let issues = ProgressRecordValidator().validateSession(session)

        #expect(issues.contains { $0.code == .negativeDuration })
        #expect(issues.contains { $0.code == .invalidTemporalRange })
    }

    @Test func attemptRequiresExistingSession() throws {
        let attempt = try Fixtures.attempt()

        let issues = ProgressRecordValidator().validateAttempt(attempt, knownSessionIDs: [])

        #expect(issues.contains { $0.code == .unresolvedSessionReference })
    }

    @Test func unreferencedReflectionFailsValidation() throws {
        let reflection = try StudentReflectionRecord(
            id: #require(StudentReflectionRecordID("reflection-1")),
            programme: nil,
            weekID: nil,
            dayID: nil,
            sessionID: nil,
            note: "Loose thought.",
            createdAt: Fixtures.timestamp("2026-09-01T10:00:00Z", timeZoneID: "Europe/London")
        )

        let issues = ProgressRecordValidator().validateReflection(reflection, knownSessionIDs: [])

        #expect(issues.contains { $0.code == .missingRequiredReference })
    }

    @Test func masteryDecisionRetainsRuleVersionWhenProducedByRule() throws {
        let decision = try Fixtures.masteryDecision(masteryRuleVersion: nil)

        let issues = ProgressRecordValidator().validateMasteryDecision(decision)

        #expect(issues.contains { $0.code == .invalidMasteryRuleVersion })
    }

    @Test func localDayUsesPersistedTimeZoneInsteadOfCurrentDefault() throws {
        let londonTimestamp = try Fixtures.timestamp("2026-07-01T23:30:00Z", timeZoneID: "Europe/London")
        NSTimeZone.default = TimeZone(identifier: "UTC")!

        #expect(londonTimestamp.localDay.timeZoneIdentifier == "Europe/London")
        #expect(londonTimestamp.localDay.dayKey == "2026-07-02")
    }

    @Test func utcAndLondonCanPlaceSameInstantOnDifferentLocalDays() throws {
        let instant = "2026-07-01T23:30:00Z"
        let utcTimestamp = try Fixtures.timestamp(instant, timeZoneID: "UTC")
        let londonTimestamp = try Fixtures.timestamp(instant, timeZoneID: "Europe/London")

        #expect(utcTimestamp.localDay.dayKey == "2026-07-01")
        #expect(londonTimestamp.localDay.dayKey == "2026-07-02")
    }

    @Test func localMidnightBoundaryIsDerivedWhenRecordIsCreated() throws {
        let beforeMidnight = try Fixtures.timestamp("2026-09-01T22:30:00Z", timeZoneID: "Europe/London")
        let afterMidnight = try Fixtures.timestamp("2026-09-01T23:30:00Z", timeZoneID: "Europe/London")

        #expect(beforeMidnight.localDay.dayKey == "2026-09-01")
        #expect(afterMidnight.localDay.dayKey == "2026-09-02")
    }

    @Test func daylightSavingTransitionKeepsStableLocalDayKey() throws {
        let beforeClockChange = try Fixtures.timestamp("2026-03-29T00:30:00Z", timeZoneID: "Europe/London")
        let afterClockChange = try Fixtures.timestamp("2026-03-29T01:30:00Z", timeZoneID: "Europe/London")

        #expect(beforeClockChange.localDay.dayKey == "2026-03-29")
        #expect(afterClockChange.localDay.dayKey == "2026-03-29")
    }
}

enum Fixtures {
    static func timestamp(_ iso8601: String, timeZoneID: String) throws -> PracticeTimestamp {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return PracticeTimestamp(
            instant: try #require(formatter.date(from: iso8601)),
            timeZone: try #require(TimeZone(identifier: timeZoneID))
        )
    }

    static func programme() throws -> ProgrammeDefinitionReference {
        ProgrammeDefinitionReference(
            programmeID: PracticeProgrammeID("programme-pianovo-twelve-week-v1")!,
            programmeVersion: 1
        )
    }

    static func context() throws -> PracticeRecordContext {
        PracticeRecordContext(
            programme: try programme(),
            weekID: ProgrammeWeekID("week-01")!,
            dayID: PracticeDayID("week-01-day-01")!,
            blockID: PracticeBlockID("week-01-day-01-morning-beyer")!,
            assignmentID: PracticeAssignmentID("week-01-day-01-morning-beyer-assignment")!,
            sourceID: ExerciseSourceID("beyer-op101-no-63")!
        )
    }

    static func session(
        id: String = "session-1",
        startedAt: PracticeTimestamp? = nil,
        endedAt: PracticeTimestamp? = nil
    ) throws -> PracticeSessionRecord {
        PracticeSessionRecord(
            id: try #require(PracticeSessionRecordID(id)),
            context: try context(),
            startedAt: try startedAt ?? timestamp("2026-09-01T10:00:00Z", timeZoneID: "Europe/London"),
            endedAt: try endedAt ?? timestamp("2026-09-01T10:45:00Z", timeZoneID: "Europe/London"),
            outcome: .completed
        )
    }

    static func attempt(id: String = "attempt-1", sessionID: String = "session-1") throws -> PerformanceAttemptRecord {
        PerformanceAttemptRecord(
            id: try #require(PerformanceAttemptRecordID(id)),
            sessionID: try #require(PracticeSessionRecordID(sessionID)),
            context: try context(),
            occurredAt: try timestamp("2026-09-01T10:05:00Z", timeZoneID: "Europe/London"),
            outcome: .completed
        )
    }

    static func completion(
        status: AssignmentCompletionStatus = .completed,
        updatedAt: PracticeTimestamp? = nil,
        completedAt: PracticeTimestamp? = nil,
        note: String? = nil
    ) throws -> AssignmentCompletionState {
        AssignmentCompletionState(
            programme: try programme(),
            assignmentID: PracticeAssignmentID("week-01-day-01-morning-beyer-assignment")!,
            sourceID: ExerciseSourceID("beyer-op101-no-63")!,
            status: status,
            updatedAt: try updatedAt ?? timestamp("2026-09-01T10:45:00Z", timeZoneID: "Europe/London"),
            completedAt: try completedAt ?? timestamp("2026-09-01T10:45:00Z", timeZoneID: "Europe/London"),
            note: note
        )
    }

    static func reflection(
        id: String = "reflection-1",
        sessionID: String? = "session-1",
        note: String = "Good focus."
    ) throws -> StudentReflectionRecord {
        StudentReflectionRecord(
            id: try #require(StudentReflectionRecordID(id)),
            programme: try programme(),
            weekID: ProgrammeWeekID("week-01")!,
            dayID: PracticeDayID("week-01-day-01")!,
            sessionID: try sessionID.map { try #require(PracticeSessionRecordID($0)) },
            note: note,
            createdAt: try timestamp("2026-09-01T11:00:00Z", timeZoneID: "Europe/London")
        )
    }

    static func masteryDecision(
        id: String = "mastery-decision-1",
        masteryRuleVersion: Int? = 1,
        resultingState: MasteryState = .stabilizing,
        reason: String? = "Teacher approved controlled repeat."
    ) throws -> MasteryDecisionRecord {
        MasteryDecisionRecord(
            id: try #require(MasteryDecisionRecordID(id)),
            programme: try programme(),
            assignmentID: PracticeAssignmentID("week-01-day-01-morning-beyer-assignment")!,
            sourceID: ExerciseSourceID("beyer-op101-no-63")!,
            decisionSource: .manual,
            resultingState: resultingState,
            masteryRuleID: MasteryRuleID("mastery-rule-beyer-control-v1")!,
            masteryRuleVersion: masteryRuleVersion,
            reason: reason,
            decidedAt: try timestamp("2026-09-01T11:05:00Z", timeZoneID: "Europe/London")
        )
    }

    static func activeProgress(
        currentWeekID: String? = "week-01",
        currentDayID: String? = "week-01-day-01",
        updatedAt: PracticeTimestamp? = nil
    ) throws -> ActiveProgrammeProgress {
        ActiveProgrammeProgress(
            programme: try programme(),
            currentWeekID: currentWeekID.flatMap(ProgrammeWeekID.init),
            currentDayID: currentDayID.flatMap(PracticeDayID.init),
            updatedAt: try updatedAt ?? timestamp("2026-09-01T09:00:00Z", timeZoneID: "Europe/London")
        )
    }
}
