import Foundation
import SwiftData

@MainActor
final class SwiftDataPracticeHistoryRepository: ProgrammeProgressRepository, PracticeHistoryRepository {
    private let context: ModelContext
    private let validator = ProgressRecordValidator()

    private let saveSessionContext: (ModelContext) throws -> Void

    init(context: ModelContext, saveSessionContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.saveSessionContext = saveSessionContext
    }

    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot? {
        let activeProgress = try fetchActiveProgressModels()
            .first { $0.programmeID == programmeID.rawValue }
            .flatMap(Self.activeProgress)
        let completions = try fetchCompletionModels()
            .filter { $0.programmeID == programmeID.rawValue }
            .compactMap(Self.completion)
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

        if let existing = try fetchActiveProgressModels().first(where: { $0.programmeID == progress.programme.programmeID.rawValue }) {
            existing.update(from: progress)
        } else {
            context.insert(ActiveProgrammeProgressModel(progress: progress))
        }

        try context.save()
    }

    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws {
        try validate(validator.validateCompletion(completion))
        let stableID = AssignmentCompletionModel.id(
            programmeID: completion.programme.programmeID.rawValue,
            assignmentID: completion.assignmentID.rawValue
        )

        if let existing = try fetchCompletionModels().first(where: { $0.id == stableID }) {
            existing.update(from: completion)
        } else {
            context.insert(AssignmentCompletionModel(completion: completion))
        }

        try context.save()
    }

    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws {
        for model in try fetchActiveProgressModels() where model.programmeID == programmeID.rawValue {
            context.delete(model)
        }
        for model in try fetchCompletionModels() where model.programmeID == programmeID.rawValue {
            context.delete(model)
        }
        for model in try fetchMasteryDecisionModels() where model.programmeID == programmeID.rawValue {
            context.delete(model)
        }

        try context.save()
    }

    func recordSession(_ session: PracticeSessionRecord) async throws {
        try validate(validator.validateSession(session))
        // Session insertion is an isolated transaction: rollback must never touch
        // pending progress or other records in the repository's original context.
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        guard try writer.fetch(FetchDescriptor<PracticeSessionModel>()).first(where: { $0.id == session.id.rawValue }) == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(session.id.rawValue)
        }
        writer.insert(PracticeSessionModel(session: session))
        do {
            try saveSessionContext(writer)
            let reader = ModelContext(context.container)
            guard try reader.fetch(FetchDescriptor<PracticeSessionModel>())
                .compactMap(Self.session).contains(session) else {
                throw PracticeHistoryRepositoryError.notFound(session.id.rawValue)
            }
        } catch {
            writer.rollback()
            throw error
        }
    }

    func recordAttempt(_ attempt: PerformanceAttemptRecord) async throws {
        guard try fetchAttemptModels().first(where: { $0.id == attempt.id.rawValue }) == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(attempt.id.rawValue)
        }

        try validate(
            validator.validateAttempt(
                attempt,
                knownSessionIDs: Set(try fetchSessionModels().compactMap { PracticeSessionRecordID($0.id) })
            )
        )
        context.insert(PerformanceAttemptModel(attempt: attempt))
        try context.save()
    }

    func recordReflection(_ reflection: StudentReflectionRecord) async throws {
        guard try fetchReflectionModels().first(where: { $0.id == reflection.id.rawValue }) == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(reflection.id.rawValue)
        }

        try validate(
            validator.validateReflection(
                reflection,
                knownSessionIDs: Set(try fetchSessionModels().compactMap { PracticeSessionRecordID($0.id) })
            )
        )
        context.insert(StudentReflectionModel(reflection: reflection))
        try context.save()
    }

    func recordMasteryDecision(_ decision: MasteryDecisionRecord) async throws {
        guard try fetchMasteryDecisionModels().first(where: { $0.id == decision.id.rawValue }) == nil else {
            throw PracticeHistoryRepositoryError.duplicateID(decision.id.rawValue)
        }

        try validate(validator.validateMasteryDecision(decision))
        context.insert(MasteryDecisionModel(decision: decision))
        try context.save()
    }

    func latestMasteryDecisions(programmeID: PracticeProgrammeID) async throws -> [MasteryDecisionRecord] {
        let decisions = try fetchMasteryDecisionModels()
            .filter { $0.programmeID == programmeID.rawValue }
            .compactMap(Self.masteryDecision)

        return latestMasteryDecisions(from: decisions)
    }

    func chronologicalHistory() async throws -> [PracticeHistoryEvent] {
        let events: [PracticeHistoryEvent] =
            try ModelContext(context.container).fetch(FetchDescriptor<PracticeSessionModel>())
                .compactMap(Self.session).map(PracticeHistoryEvent.session)
            + fetchAttemptModels().compactMap(Self.attempt).map(PracticeHistoryEvent.attempt)
            + fetchReflectionModels().compactMap(Self.reflection).map(PracticeHistoryEvent.reflection)
            + fetchMasteryDecisionModels().compactMap(Self.masteryDecision).map(PracticeHistoryEvent.masteryDecision)

        return events.sorted { first, second in
            if first.timestamp.instant == second.timestamp.instant {
                return sortKey(first) < sortKey(second)
            }

            return first.timestamp.instant < second.timestamp.instant
        }
    }

    func deleteSession(id: PracticeSessionRecordID) async throws {
        guard let session = try fetchSessionModels().first(where: { $0.id == id.rawValue }) else {
            throw PracticeHistoryRepositoryError.notFound(id.rawValue)
        }

        for attempt in try fetchAttemptModels() where attempt.sessionID == id.rawValue {
            context.delete(attempt)
        }
        for reflection in try fetchReflectionModels() where reflection.sessionID == id.rawValue {
            context.delete(reflection)
        }
        context.delete(session)

        try context.save()
    }

    func deleteAllPersonalPracticeData() async throws {
        for model in try fetchActiveProgressModels() {
            context.delete(model)
        }
        for model in try fetchCompletionModels() {
            context.delete(model)
        }
        for model in try fetchSessionModels() {
            context.delete(model)
        }
        for model in try fetchAttemptModels() {
            context.delete(model)
        }
        for model in try fetchReflectionModels() {
            context.delete(model)
        }
        for model in try fetchMasteryDecisionModels() {
            context.delete(model)
        }

        try context.save()
    }

    private func fetchActiveProgressModels() throws -> [ActiveProgrammeProgressModel] {
        try context.fetch(FetchDescriptor<ActiveProgrammeProgressModel>())
    }

    private func fetchCompletionModels() throws -> [AssignmentCompletionModel] {
        try context.fetch(FetchDescriptor<AssignmentCompletionModel>())
    }

    private func fetchSessionModels() throws -> [PracticeSessionModel] {
        try context.fetch(FetchDescriptor<PracticeSessionModel>())
    }

    private func fetchAttemptModels() throws -> [PerformanceAttemptModel] {
        try context.fetch(FetchDescriptor<PerformanceAttemptModel>())
    }

    private func fetchReflectionModels() throws -> [StudentReflectionModel] {
        try context.fetch(FetchDescriptor<StudentReflectionModel>())
    }

    private func fetchMasteryDecisionModels() throws -> [MasteryDecisionModel] {
        try context.fetch(FetchDescriptor<MasteryDecisionModel>())
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

private extension SwiftDataPracticeHistoryRepository {
    nonisolated static func activeProgress(_ model: ActiveProgrammeProgressModel) -> ActiveProgrammeProgress? {
        guard
            let programmeID = PracticeProgrammeID(model.programmeID),
            let updatedAt = timestamp(
                instant: model.updatedAt,
                timeZoneIdentifier: model.updatedTimeZoneIdentifier,
                calendarIdentifier: model.updatedCalendarIdentifier,
                localDayKey: model.updatedLocalDayKey
            )
        else {
            return nil
        }

        return ActiveProgrammeProgress(
            programme: ProgrammeDefinitionReference(programmeID: programmeID, programmeVersion: model.programmeVersion),
            currentWeekID: model.currentWeekID.flatMap(ProgrammeWeekID.init),
            currentDayID: model.currentDayID.flatMap(PracticeDayID.init),
            updatedAt: updatedAt
        )
    }

    nonisolated static func completion(_ model: AssignmentCompletionModel) -> AssignmentCompletionState? {
        guard
            let programmeID = PracticeProgrammeID(model.programmeID),
            let assignmentID = PracticeAssignmentID(model.assignmentID),
            let sourceID = ExerciseSourceID(model.sourceID),
            let status = AssignmentCompletionStatus(rawValue: model.status),
            let updatedAt = timestamp(
                instant: model.updatedAt,
                timeZoneIdentifier: model.updatedTimeZoneIdentifier,
                calendarIdentifier: model.updatedCalendarIdentifier,
                localDayKey: model.updatedLocalDayKey
            )
        else {
            return nil
        }

        let completedAt = optionalTimestamp(
            instant: model.completedAt,
            timeZoneIdentifier: model.completedTimeZoneIdentifier,
            calendarIdentifier: model.completedCalendarIdentifier,
            localDayKey: model.completedLocalDayKey
        )

        return AssignmentCompletionState(
            programme: ProgrammeDefinitionReference(programmeID: programmeID, programmeVersion: model.programmeVersion),
            assignmentID: assignmentID,
            sourceID: sourceID,
            status: status,
            updatedAt: updatedAt,
            completedAt: completedAt,
            note: model.note
        )
    }

    nonisolated static func session(_ model: PracticeSessionModel) -> PracticeSessionRecord? {
        guard
            let id = PracticeSessionRecordID(model.id),
            let context = context(
                programmeID: model.programmeID,
                programmeVersion: model.programmeVersion,
                weekID: model.weekID,
                dayID: model.dayID,
                blockID: model.blockID,
                assignmentID: model.assignmentID,
                sourceID: model.sourceID
            ),
            let startedAt = timestamp(
                instant: model.startedAt,
                timeZoneIdentifier: model.startedTimeZoneIdentifier,
                calendarIdentifier: model.startedCalendarIdentifier,
                localDayKey: model.startedLocalDayKey
            ),
            let outcome = PracticeSessionOutcome(rawValue: model.outcome)
        else {
            return nil
        }

        let endedAt = optionalTimestamp(
            instant: model.endedAt,
            timeZoneIdentifier: model.endedTimeZoneIdentifier,
            calendarIdentifier: model.endedCalendarIdentifier,
            localDayKey: model.endedLocalDayKey
        )

        return PracticeSessionRecord(
            id: id,
            context: context,
            startedAt: startedAt,
            endedAt: endedAt,
            outcome: outcome
        )
    }

    nonisolated static func attempt(_ model: PerformanceAttemptModel) -> PerformanceAttemptRecord? {
        guard
            let id = PerformanceAttemptRecordID(model.id),
            let sessionID = PracticeSessionRecordID(model.sessionID),
            let context = context(
                programmeID: model.programmeID,
                programmeVersion: model.programmeVersion,
                weekID: model.weekID,
                dayID: model.dayID,
                blockID: model.blockID,
                assignmentID: model.assignmentID,
                sourceID: model.sourceID
            ),
            let occurredAt = timestamp(
                instant: model.occurredAt,
                timeZoneIdentifier: model.occurredTimeZoneIdentifier,
                calendarIdentifier: model.occurredCalendarIdentifier,
                localDayKey: model.occurredLocalDayKey
            ),
            let outcome = PerformanceAttemptOutcome(rawValue: model.outcome)
        else {
            return nil
        }

        return PerformanceAttemptRecord(
            id: id,
            sessionID: sessionID,
            context: context,
            occurredAt: occurredAt,
            outcome: outcome
        )
    }

    nonisolated static func reflection(_ model: StudentReflectionModel) -> StudentReflectionRecord? {
        guard
            let id = StudentReflectionRecordID(model.id),
            let createdAt = timestamp(
                instant: model.createdAt,
                timeZoneIdentifier: model.createdTimeZoneIdentifier,
                calendarIdentifier: model.createdCalendarIdentifier,
                localDayKey: model.createdLocalDayKey
            )
        else {
            return nil
        }

        let programme: ProgrammeDefinitionReference?
        if let rawProgrammeID = model.programmeID, let programmeID = PracticeProgrammeID(rawProgrammeID), let version = model.programmeVersion {
            programme = ProgrammeDefinitionReference(programmeID: programmeID, programmeVersion: version)
        } else {
            programme = nil
        }

        return StudentReflectionRecord(
            id: id,
            programme: programme,
            weekID: model.weekID.flatMap(ProgrammeWeekID.init),
            dayID: model.dayID.flatMap(PracticeDayID.init),
            sessionID: model.sessionID.flatMap(PracticeSessionRecordID.init),
            note: model.note,
            createdAt: createdAt
        )
    }

    nonisolated static func masteryDecision(_ model: MasteryDecisionModel) -> MasteryDecisionRecord? {
        guard
            let id = MasteryDecisionRecordID(model.id),
            let programmeID = PracticeProgrammeID(model.programmeID),
            let assignmentID = PracticeAssignmentID(model.assignmentID),
            let sourceID = ExerciseSourceID(model.sourceID),
            let decisionSource = MasteryDecisionSource(rawValue: model.decisionSource),
            let resultingState = MasteryState(rawValue: model.resultingState),
            let decidedAt = timestamp(
                instant: model.decidedAt,
                timeZoneIdentifier: model.decidedTimeZoneIdentifier,
                calendarIdentifier: model.decidedCalendarIdentifier,
                localDayKey: model.decidedLocalDayKey
            )
        else {
            return nil
        }

        return MasteryDecisionRecord(
            id: id,
            programme: ProgrammeDefinitionReference(programmeID: programmeID, programmeVersion: model.programmeVersion),
            assignmentID: assignmentID,
            sourceID: sourceID,
            decisionSource: decisionSource,
            resultingState: resultingState,
            masteryRuleID: model.masteryRuleID.flatMap(MasteryRuleID.init),
            masteryRuleVersion: model.masteryRuleVersion,
            reason: model.reason,
            decidedAt: decidedAt
        )
    }

    nonisolated static func context(
        programmeID: String,
        programmeVersion: Int,
        weekID: String?,
        dayID: String?,
        blockID: String?,
        assignmentID: String?,
        sourceID: String?
    ) -> PracticeRecordContext? {
        guard let programmeID = PracticeProgrammeID(programmeID) else {
            return nil
        }

        return PracticeRecordContext(
            programme: ProgrammeDefinitionReference(programmeID: programmeID, programmeVersion: programmeVersion),
            weekID: weekID.flatMap(ProgrammeWeekID.init),
            dayID: dayID.flatMap(PracticeDayID.init),
            blockID: blockID.flatMap(PracticeBlockID.init),
            assignmentID: assignmentID.flatMap(PracticeAssignmentID.init),
            sourceID: sourceID.flatMap(ExerciseSourceID.init)
        )
    }

    nonisolated static func timestamp(
        instant: Date,
        timeZoneIdentifier: String,
        calendarIdentifier: String,
        localDayKey: String
    ) -> PracticeTimestamp? {
        guard
            let calendar = PracticeCalendarIdentifier(rawValue: calendarIdentifier),
            let localDay = localDay(
                key: localDayKey,
                calendarIdentifier: calendar,
                timeZoneIdentifier: timeZoneIdentifier
            )
        else {
            return nil
        }

        return PracticeTimestamp(instant: instant, localDay: localDay)
    }

    nonisolated static func optionalTimestamp(
        instant: Date?,
        timeZoneIdentifier: String?,
        calendarIdentifier: String?,
        localDayKey: String?
    ) -> PracticeTimestamp? {
        guard let instant, let timeZoneIdentifier, let calendarIdentifier, let localDayKey else {
            return nil
        }

        return timestamp(
            instant: instant,
            timeZoneIdentifier: timeZoneIdentifier,
            calendarIdentifier: calendarIdentifier,
            localDayKey: localDayKey
        )
    }

    nonisolated static func localDay(
        key: String,
        calendarIdentifier: PracticeCalendarIdentifier,
        timeZoneIdentifier: String
    ) -> LocalDayContext? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }

        return LocalDayContext(
            calendarIdentifier: calendarIdentifier,
            timeZoneIdentifier: timeZoneIdentifier,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        )
    }
}
