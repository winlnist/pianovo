import Foundation
import SwiftData

enum PracticeHistorySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ActiveProgrammeProgressModel.self,
            AssignmentCompletionModel.self,
            PracticeSessionModel.self,
            PerformanceAttemptModel.self,
            StudentReflectionModel.self,
            MasteryDecisionModel.self
        ]
    }
}

extension PracticeHistorySchemaV1 {
    @Model
    final class ActiveProgrammeProgressModel {
        @Attribute(.unique) var programmeID: String
        var programmeVersion: Int
        var currentWeekID: String?
        var currentDayID: String?
        var updatedAt: Date
        var updatedTimeZoneIdentifier: String
        var updatedCalendarIdentifier: String
        var updatedLocalDayKey: String

        init(progress: ActiveProgrammeProgress) {
            self.programmeID = progress.programme.programmeID.rawValue
            self.programmeVersion = progress.programme.programmeVersion
            self.currentWeekID = progress.currentWeekID?.rawValue
            self.currentDayID = progress.currentDayID?.rawValue
            self.updatedAt = progress.updatedAt.instant
            self.updatedTimeZoneIdentifier = progress.updatedAt.localDay.timeZoneIdentifier
            self.updatedCalendarIdentifier = progress.updatedAt.localDay.calendarIdentifier.rawValue
            self.updatedLocalDayKey = progress.updatedAt.localDay.dayKey
        }

        func update(from progress: ActiveProgrammeProgress) {
            self.programmeVersion = progress.programme.programmeVersion
            self.currentWeekID = progress.currentWeekID?.rawValue
            self.currentDayID = progress.currentDayID?.rawValue
            self.updatedAt = progress.updatedAt.instant
            self.updatedTimeZoneIdentifier = progress.updatedAt.localDay.timeZoneIdentifier
            self.updatedCalendarIdentifier = progress.updatedAt.localDay.calendarIdentifier.rawValue
            self.updatedLocalDayKey = progress.updatedAt.localDay.dayKey
        }
    }

    @Model
    final class AssignmentCompletionModel {
        @Attribute(.unique) var id: String
        var programmeID: String
        var programmeVersion: Int
        var assignmentID: String
        var sourceID: String
        var status: String
        var updatedAt: Date
        var updatedTimeZoneIdentifier: String
        var updatedCalendarIdentifier: String
        var updatedLocalDayKey: String
        var completedAt: Date?
        var completedTimeZoneIdentifier: String?
        var completedCalendarIdentifier: String?
        var completedLocalDayKey: String?
        var note: String?

        init(completion: AssignmentCompletionState) {
            self.id = Self.id(programmeID: completion.programme.programmeID.rawValue, assignmentID: completion.assignmentID.rawValue)
            self.programmeID = completion.programme.programmeID.rawValue
            self.programmeVersion = completion.programme.programmeVersion
            self.assignmentID = completion.assignmentID.rawValue
            self.sourceID = completion.sourceID.rawValue
            self.status = completion.status.rawValue
            self.updatedAt = completion.updatedAt.instant
            self.updatedTimeZoneIdentifier = completion.updatedAt.localDay.timeZoneIdentifier
            self.updatedCalendarIdentifier = completion.updatedAt.localDay.calendarIdentifier.rawValue
            self.updatedLocalDayKey = completion.updatedAt.localDay.dayKey
            self.completedAt = completion.completedAt?.instant
            self.completedTimeZoneIdentifier = completion.completedAt?.localDay.timeZoneIdentifier
            self.completedCalendarIdentifier = completion.completedAt?.localDay.calendarIdentifier.rawValue
            self.completedLocalDayKey = completion.completedAt?.localDay.dayKey
            self.note = completion.note
        }

        func update(from completion: AssignmentCompletionState) {
            self.programmeVersion = completion.programme.programmeVersion
            self.sourceID = completion.sourceID.rawValue
            self.status = completion.status.rawValue
            self.updatedAt = completion.updatedAt.instant
            self.updatedTimeZoneIdentifier = completion.updatedAt.localDay.timeZoneIdentifier
            self.updatedCalendarIdentifier = completion.updatedAt.localDay.calendarIdentifier.rawValue
            self.updatedLocalDayKey = completion.updatedAt.localDay.dayKey
            self.completedAt = completion.completedAt?.instant
            self.completedTimeZoneIdentifier = completion.completedAt?.localDay.timeZoneIdentifier
            self.completedCalendarIdentifier = completion.completedAt?.localDay.calendarIdentifier.rawValue
            self.completedLocalDayKey = completion.completedAt?.localDay.dayKey
            self.note = completion.note
        }

        static func id(programmeID: String, assignmentID: String) -> String {
            "\(programmeID)|\(assignmentID)"
        }
    }

    @Model
    final class PracticeSessionModel {
        @Attribute(.unique) var id: String
        var programmeID: String
        var programmeVersion: Int
        var weekID: String?
        var dayID: String?
        var blockID: String?
        var assignmentID: String?
        var sourceID: String?
        var startedAt: Date
        var startedTimeZoneIdentifier: String
        var startedCalendarIdentifier: String
        var startedLocalDayKey: String
        var endedAt: Date?
        var endedTimeZoneIdentifier: String?
        var endedCalendarIdentifier: String?
        var endedLocalDayKey: String?
        var outcome: String

        init(session: PracticeSessionRecord) {
            self.id = session.id.rawValue
            self.programmeID = session.context.programme.programmeID.rawValue
            self.programmeVersion = session.context.programme.programmeVersion
            self.weekID = session.context.weekID?.rawValue
            self.dayID = session.context.dayID?.rawValue
            self.blockID = session.context.blockID?.rawValue
            self.assignmentID = session.context.assignmentID?.rawValue
            self.sourceID = session.context.sourceID?.rawValue
            self.startedAt = session.startedAt.instant
            self.startedTimeZoneIdentifier = session.startedAt.localDay.timeZoneIdentifier
            self.startedCalendarIdentifier = session.startedAt.localDay.calendarIdentifier.rawValue
            self.startedLocalDayKey = session.startedAt.localDay.dayKey
            self.endedAt = session.endedAt?.instant
            self.endedTimeZoneIdentifier = session.endedAt?.localDay.timeZoneIdentifier
            self.endedCalendarIdentifier = session.endedAt?.localDay.calendarIdentifier.rawValue
            self.endedLocalDayKey = session.endedAt?.localDay.dayKey
            self.outcome = session.outcome.rawValue
        }
    }

    @Model
    final class PerformanceAttemptModel {
        @Attribute(.unique) var id: String
        var sessionID: String
        var programmeID: String
        var programmeVersion: Int
        var weekID: String?
        var dayID: String?
        var blockID: String?
        var assignmentID: String?
        var sourceID: String?
        var occurredAt: Date
        var occurredTimeZoneIdentifier: String
        var occurredCalendarIdentifier: String
        var occurredLocalDayKey: String
        var outcome: String

        init(attempt: PerformanceAttemptRecord) {
            self.id = attempt.id.rawValue
            self.sessionID = attempt.sessionID.rawValue
            self.programmeID = attempt.context.programme.programmeID.rawValue
            self.programmeVersion = attempt.context.programme.programmeVersion
            self.weekID = attempt.context.weekID?.rawValue
            self.dayID = attempt.context.dayID?.rawValue
            self.blockID = attempt.context.blockID?.rawValue
            self.assignmentID = attempt.context.assignmentID?.rawValue
            self.sourceID = attempt.context.sourceID?.rawValue
            self.occurredAt = attempt.occurredAt.instant
            self.occurredTimeZoneIdentifier = attempt.occurredAt.localDay.timeZoneIdentifier
            self.occurredCalendarIdentifier = attempt.occurredAt.localDay.calendarIdentifier.rawValue
            self.occurredLocalDayKey = attempt.occurredAt.localDay.dayKey
            self.outcome = attempt.outcome.rawValue
        }
    }

    @Model
    final class StudentReflectionModel {
        @Attribute(.unique) var id: String
        var programmeID: String?
        var programmeVersion: Int?
        var weekID: String?
        var dayID: String?
        var sessionID: String?
        var note: String
        var createdAt: Date
        var createdTimeZoneIdentifier: String
        var createdCalendarIdentifier: String
        var createdLocalDayKey: String

        init(reflection: StudentReflectionRecord) {
            self.id = reflection.id.rawValue
            self.programmeID = reflection.programme?.programmeID.rawValue
            self.programmeVersion = reflection.programme?.programmeVersion
            self.weekID = reflection.weekID?.rawValue
            self.dayID = reflection.dayID?.rawValue
            self.sessionID = reflection.sessionID?.rawValue
            self.note = reflection.note
            self.createdAt = reflection.createdAt.instant
            self.createdTimeZoneIdentifier = reflection.createdAt.localDay.timeZoneIdentifier
            self.createdCalendarIdentifier = reflection.createdAt.localDay.calendarIdentifier.rawValue
            self.createdLocalDayKey = reflection.createdAt.localDay.dayKey
        }
    }

    @Model
    final class MasteryDecisionModel {
        @Attribute(.unique) var id: String
        var programmeID: String
        var programmeVersion: Int
        var assignmentID: String
        var sourceID: String
        var decisionSource: String
        var resultingState: String
        var masteryRuleID: String?
        var masteryRuleVersion: Int?
        var reason: String?
        var decidedAt: Date
        var decidedTimeZoneIdentifier: String
        var decidedCalendarIdentifier: String
        var decidedLocalDayKey: String

        init(decision: MasteryDecisionRecord) {
            self.id = decision.id.rawValue
            self.programmeID = decision.programme.programmeID.rawValue
            self.programmeVersion = decision.programme.programmeVersion
            self.assignmentID = decision.assignmentID.rawValue
            self.sourceID = decision.sourceID.rawValue
            self.decisionSource = decision.decisionSource.rawValue
            self.resultingState = decision.resultingState.rawValue
            self.masteryRuleID = decision.masteryRuleID?.rawValue
            self.masteryRuleVersion = decision.masteryRuleVersion
            self.reason = decision.reason
            self.decidedAt = decision.decidedAt.instant
            self.decidedTimeZoneIdentifier = decision.decidedAt.localDay.timeZoneIdentifier
            self.decidedCalendarIdentifier = decision.decidedAt.localDay.calendarIdentifier.rawValue
            self.decidedLocalDayKey = decision.decidedAt.localDay.dayKey
        }
    }
}

typealias ActiveProgrammeProgressModel = PracticeHistorySchemaV1.ActiveProgrammeProgressModel
typealias AssignmentCompletionModel = PracticeHistorySchemaV1.AssignmentCompletionModel
typealias PracticeSessionModel = PracticeHistorySchemaV1.PracticeSessionModel
typealias PerformanceAttemptModel = PracticeHistorySchemaV1.PerformanceAttemptModel
typealias StudentReflectionModel = PracticeHistorySchemaV1.StudentReflectionModel
typealias MasteryDecisionModel = PracticeHistorySchemaV1.MasteryDecisionModel
