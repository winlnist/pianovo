import Testing
@testable import Sightlink_Piano

struct InMemoryPracticeHistoryRepositoryTests {
    @Test func savingSameActiveProgrammeProgressIdentityUpsertsLatestValues() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let programmeID = try #require(PracticeProgrammeID("programme-pianovo-twelve-week-v1"))
        let updatedAt = try Fixtures.timestamp("2026-09-02T09:00:00Z", timeZoneID: "Europe/London")

        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        try await repository.saveActiveProgress(try Fixtures.activeProgress(
            currentWeekID: "week-02",
            currentDayID: "week-02-day-03",
            updatedAt: updatedAt
        ))

        let snapshot = try #require(try await repository.loadProgress(programmeID: programmeID))

        #expect(snapshot.activeProgress?.currentWeekID == ProgrammeWeekID("week-02"))
        #expect(snapshot.activeProgress?.currentDayID == PracticeDayID("week-02-day-03"))
        #expect(snapshot.activeProgress?.updatedAt.instant == updatedAt.instant)
        #expect(snapshot.assignmentCompletions.isEmpty)
    }

    @Test func updatingSameAssignmentCompletionIdentityUpsertsLatestValues() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let programmeID = try #require(PracticeProgrammeID("programme-pianovo-twelve-week-v1"))
        let updatedAt = try Fixtures.timestamp("2026-09-02T10:45:00Z", timeZoneID: "Europe/London")

        try await repository.updateAssignmentCompletion(try Fixtures.completion(status: .inProgress, note: "First state."))
        try await repository.updateAssignmentCompletion(try Fixtures.completion(
            status: .completed,
            updatedAt: updatedAt,
            completedAt: updatedAt,
            note: "Latest state."
        ))

        let snapshot = try #require(try await repository.loadProgress(programmeID: programmeID))
        let completion = try #require(snapshot.assignmentCompletions.first)

        #expect(snapshot.assignmentCompletions.count == 1)
        #expect(completion.status == .completed)
        #expect(completion.note == "Latest state.")
        #expect(completion.updatedAt.instant == updatedAt.instant)
    }

    @Test func recordingSameSessionIDReturnsDuplicateError() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let session = try Fixtures.session()

        try await repository.recordSession(session)

        await #expect(throws: PracticeHistoryRepositoryError.duplicateID(session.id.rawValue)) {
            try await repository.recordSession(session)
        }
    }

    @Test func recordingDuplicateAttemptIDFailsAndKeepsOriginalAttempt() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let original = try Fixtures.attempt()
        let duplicate = try PerformanceAttemptRecord(
            id: original.id,
            sessionID: original.sessionID,
            context: original.context,
            occurredAt: Fixtures.timestamp("2026-09-01T10:10:00Z", timeZoneID: "Europe/London"),
            outcome: .abandoned
        )

        try await repository.recordSession(try Fixtures.session())
        try await repository.recordAttempt(original)

        await #expect(throws: PracticeHistoryRepositoryError.duplicateID(original.id.rawValue)) {
            try await repository.recordAttempt(duplicate)
        }

        let attempts = try await repository.chronologicalHistory().compactMap { event -> PerformanceAttemptRecord? in
            if case .attempt(let attempt) = event { attempt } else { nil }
        }
        #expect(attempts == [original])
    }

    @Test func recordingDuplicateReflectionIDFailsAndKeepsOriginalReflection() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let original = try Fixtures.reflection(note: "Original note.")
        let duplicate = try Fixtures.reflection(note: "Changed note.")

        try await repository.recordSession(try Fixtures.session())
        try await repository.recordReflection(original)

        await #expect(throws: PracticeHistoryRepositoryError.duplicateID(original.id.rawValue)) {
            try await repository.recordReflection(duplicate)
        }

        let reflections = try await repository.chronologicalHistory().compactMap { event -> StudentReflectionRecord? in
            if case .reflection(let reflection) = event { reflection } else { nil }
        }
        #expect(reflections == [original])
    }

    @Test func recordingDuplicateMasteryDecisionIDFailsAndKeepsOriginalDecision() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let original = try Fixtures.masteryDecision(resultingState: .stabilizing, reason: "Original decision.")
        let duplicate = try Fixtures.masteryDecision(resultingState: .mastered, reason: "Changed decision.")

        try await repository.recordMasteryDecision(original)

        await #expect(throws: PracticeHistoryRepositoryError.duplicateID(original.id.rawValue)) {
            try await repository.recordMasteryDecision(duplicate)
        }

        let decisions = try await repository.chronologicalHistory().compactMap { event -> MasteryDecisionRecord? in
            if case .masteryDecision(let decision) = event { decision } else { nil }
        }
        #expect(decisions == [original])
    }

    @Test func chronologicalHistoryIsStable() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.recordSession(try Fixtures.session())
        try await repository.recordAttempt(try Fixtures.attempt())
        try await repository.recordReflection(try Fixtures.reflection())
        try await repository.recordMasteryDecision(try Fixtures.masteryDecision())

        let history = try await repository.chronologicalHistory()

        #expect(history.count == 4)
        #expect(history.map(\.timestamp.instant) == history.map(\.timestamp.instant).sorted())
    }

    @Test func deletingSessionCascadesToSessionAttemptsAndSessionReflectionsOnly() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let session = try Fixtures.session()
        try await repository.recordSession(session)
        try await repository.recordAttempt(try Fixtures.attempt())
        try await repository.recordReflection(try Fixtures.reflection(id: "session-reflection", sessionID: session.id.rawValue))
        try await repository.recordReflection(try Fixtures.reflection(id: "day-reflection", sessionID: nil))

        try await repository.deleteSession(id: session.id)

        let history = try await repository.chronologicalHistory()
        #expect(history == [
            .reflection(try Fixtures.reflection(id: "day-reflection", sessionID: nil))
        ])
    }

    @Test func resetProgrammeProgressKeepsHistoryButClearsCompletionsAndMasteryState() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let programmeID = try #require(PracticeProgrammeID("programme-pianovo-twelve-week-v1"))

        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        try await repository.updateAssignmentCompletion(try Fixtures.completion())
        try await repository.recordSession(try Fixtures.session())
        try await repository.recordAttempt(try Fixtures.attempt())
        try await repository.recordReflection(try Fixtures.reflection())
        try await repository.recordMasteryDecision(try Fixtures.masteryDecision())

        try await repository.resetProgrammeProgress(programmeID: programmeID)

        let snapshot = try await repository.loadProgress(programmeID: programmeID)
        let history = try await repository.chronologicalHistory()

        #expect(snapshot == nil)
        #expect(history.contains { if case .session = $0 { true } else { false } })
        #expect(history.contains { if case .attempt = $0 { true } else { false } })
        #expect(history.contains { if case .reflection = $0 { true } else { false } })
        #expect(!history.contains { if case .masteryDecision = $0 { true } else { false } })
    }

    @Test func deleteAllPersonalPracticeDataClearsEverything() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let programmeID = try #require(PracticeProgrammeID("programme-pianovo-twelve-week-v1"))

        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        try await repository.updateAssignmentCompletion(try Fixtures.completion())
        try await repository.recordSession(try Fixtures.session())
        try await repository.recordAttempt(try Fixtures.attempt())
        try await repository.recordReflection(try Fixtures.reflection())
        try await repository.recordMasteryDecision(try Fixtures.masteryDecision())

        try await repository.deleteAllPersonalPracticeData()

        #expect(try await repository.loadProgress(programmeID: programmeID) == nil)
        #expect(try await repository.chronologicalHistory().isEmpty)
    }
}
