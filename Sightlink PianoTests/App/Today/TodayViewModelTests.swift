import Foundation
import Testing
@testable import Sightlink_Piano

@MainActor
struct TodayViewModelTests {
    @Test func firstLaunchRemainsProgrammeNotStarted() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        guard case .programmeNotStarted(let programme) = viewModel.state else {
            Issue.record("Expected programmeNotStarted, got \(viewModel.state).")
            return
        }

        #expect(programme.title == "Pianovo Twelve-Week Programme")
    }

    @Test func persistedPositionLoadsCurrentDayWithoutCalendarAdvancement() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress(
            currentWeekID: "week-01",
            currentDayID: "week-01-day-02"
        ))
        let viewModel = makeViewModel(
            progressRepository: repository,
            practiceHistoryRepository: repository,
            clock: try fixedClock("2026-12-31T23:30:00Z")
        )

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        #expect(loaded.weekID == ProgrammeWeekID("week-01"))
        #expect(loaded.dayID == PracticeDayID("week-01-day-02"))
        #expect(loaded.dayTitle == "Day 2")
    }

    @Test func invalidPersistedPositionProducesStructuredFailure() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress(
            currentWeekID: "week-99",
            currentDayID: "week-99-day-01"
        ))
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        #expect(viewModel.state == .failure(.invalidPersistedPosition(
            TodayInvalidPosition(
                weekID: ProgrammeWeekID("week-99"),
                dayID: PracticeDayID("week-99-day-01")
            )
        )))
    }

    @Test func morningAndEveningBlocksRemainVisibleWhenMorningIsSuggested() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        let viewModel = makeViewModel(
            progressRepository: repository,
            practiceHistoryRepository: repository,
            clock: try fixedClock("2026-09-01T08:00:00Z")
        )

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        #expect(loaded.suggestedSessionSlot == .morning)
        #expect(loaded.morningBlocks.isEmpty == false)
        #expect(loaded.eveningBlocks.isEmpty == false)
        #expect(loaded.morningBlocks.allSatisfy { $0.isSuggested })
        #expect(loaded.eveningBlocks.allSatisfy { !$0.isSuggested })
    }

    @Test func eveningSuggestionDoesNotHideMorningBlocks() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        let viewModel = makeViewModel(
            progressRepository: repository,
            practiceHistoryRepository: repository,
            clock: try fixedClock("2026-09-01T19:00:00Z")
        )

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        #expect(loaded.suggestedSessionSlot == .evening)
        #expect(loaded.morningBlocks.isEmpty == false)
        #expect(loaded.eveningBlocks.isEmpty == false)
        #expect(loaded.eveningBlocks.allSatisfy { $0.isSuggested })
    }

    @Test func recoveryDayLoadsRecoveryBlocks() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress(
            currentWeekID: "week-01",
            currentDayID: "week-01-day-07"
        ))
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        #expect(loaded.dayKind == .recoveryReflection)
        #expect(loaded.morningBlocks.isEmpty)
        #expect(loaded.eveningBlocks.isEmpty)
        #expect(loaded.recoveryBlocks.count == 1)
    }

    @Test func londonDaylightSavingContextIsPresentationalOnly() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress(
            currentWeekID: "week-01",
            currentDayID: "week-01-day-03"
        ))
        let viewModel = makeViewModel(
            progressRepository: repository,
            practiceHistoryRepository: repository,
            clock: try fixedClock("2026-03-29T00:30:00Z")
        )

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        #expect(loaded.dayID == PracticeDayID("week-01-day-03"))
        #expect(loaded.localDayKey == "2026-03-29")
    }

    @Test func beyerNumberSixtyThreeShowsPrimaAndSecondaAsRequired() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        let beyerAssignments = loaded.allBlocks
            .flatMap(\.assignments)
            .filter { $0.sourceID == ExerciseSourceID("beyer-op101-no-63") }
        let components = beyerAssignments
            .flatMap { assignment -> [TodayReferenceMaterialComponentState] in
                if case .knownUnavailable(let summary, _) = assignment.referenceMaterial {
                    return summary.components
                }

                return []
            }

        #expect(components.contains {
            $0.role == .seconda && $0.isRequiredForCompleteExercise && $0.pdfKitPageIndex == 45 && $0.printedPageLabel == "46"
        })
        #expect(components.contains {
            $0.role == .prima && $0.isRequiredForCompleteExercise && $0.pdfKitPageIndex == 46 && $0.printedPageLabel == "47"
        })
    }

    @Test func laterAdaptiveBeyerSourceDoesNotExposeLaterNumberedExercise() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress(
            currentWeekID: "week-02",
            currentDayID: "week-02-day-01"
        ))
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        let adaptiveBeyerAssignments = loaded.allBlocks
            .flatMap(\.assignments)
            .filter { $0.sourceID == ExerciseSourceID("beyer-op101-current-sequence") }

        #expect(adaptiveBeyerAssignments.isEmpty == false)
        #expect(adaptiveBeyerAssignments.allSatisfy { $0.sourceTitle == "Current Beyer sequence exercise" })
        #expect(adaptiveBeyerAssignments.allSatisfy { assignment in
            if case .unknownSource = assignment.referenceMaterial {
                true
            } else {
                false
            }
        })
    }

    @Test func knownUnavailableReferenceMaterialIsPartialAvailabilityNotFailure() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        #expect(loaded.hasPartialReferenceMaterialAvailability)
    }

    @Test func latestMasteryDecisionAppearsInAssignmentState() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        try await repository.saveActiveProgress(try Fixtures.activeProgress())
        try await repository.recordMasteryDecision(try Fixtures.masteryDecision(resultingState: .learning))
        try await repository.recordMasteryDecision(try masteryDecision(
            id: "mastery-decision-2",
            assignmentID: "week-01-day-01-morning-beyer-assignment",
            sourceID: "beyer-op101-no-63",
            decidedAt: "2026-09-02T11:00:00Z",
            resultingState: .nearlyMastered
        ))
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        let loaded = try #require(viewModel.loadedState)
        let beyer = try #require(loaded.allBlocks.flatMap(\.assignments).first {
            $0.id == PracticeAssignmentID("week-01-day-01-morning-beyer-assignment")
        })
        #expect(beyer.masteryState == .nearlyMastered)
    }

    @Test func loadingTodayPerformsNoPersistenceWritesOrHistoryLoad() async throws {
        let repository = TodayReadOnlyRepository(
            snapshot: ProgrammeProgressSnapshot(
                activeProgress: try Fixtures.activeProgress(),
                assignmentCompletions: []
            ),
            masteryDecisions: []
        )
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        #expect(await repository.writeCount == 0)
        #expect(await repository.didLoadChronologicalHistory == false)
        #expect(viewModel.loadedState != nil)
    }

    @Test func persistenceUnavailableIsStructuredAndContainsNoRawErrorString() async {
        let viewModel = makeViewModel(progressRepository: nil, practiceHistoryRepository: nil)

        await viewModel.load()

        #expect(viewModel.state == .failure(.persistenceUnavailable))
    }

    @Test func progressFailureIsStructuredAndContainsNoRawErrorString() async {
        let repository = TodayFailingProgressRepository()
        let viewModel = makeViewModel(progressRepository: repository, practiceHistoryRepository: repository)

        await viewModel.load()

        #expect(viewModel.state == .failure(.progressLoadFailed))
    }

    private func makeViewModel(
        progressRepository: (any ProgrammeProgressRepository)?,
        practiceHistoryRepository: (any PracticeHistoryRepository)?,
        clock: any PracticeClock = FixedPracticeClock(now: Date(timeIntervalSince1970: 0))
    ) -> TodayViewModel {
        TodayViewModel(
            progressRepository: progressRepository,
            practiceHistoryRepository: practiceHistoryRepository,
            clock: clock,
            localContextProvider: FixedPracticeLocalContextProvider(
                timeZone: TimeZone(identifier: "Europe/London")!,
                calendarIdentifier: .gregorian
            )
        )
    }

    private func fixedClock(_ iso8601: String) throws -> FixedPracticeClock {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return FixedPracticeClock(now: try #require(formatter.date(from: iso8601)))
    }

    private func masteryDecision(
        id: String,
        assignmentID: String,
        sourceID: String,
        decidedAt: String,
        resultingState: MasteryState
    ) throws -> MasteryDecisionRecord {
        MasteryDecisionRecord(
            id: try #require(MasteryDecisionRecordID(id)),
            programme: try Fixtures.programme(),
            assignmentID: try #require(PracticeAssignmentID(assignmentID)),
            sourceID: try #require(ExerciseSourceID(sourceID)),
            decisionSource: .manual,
            resultingState: resultingState,
            masteryRuleID: try #require(MasteryRuleID("mastery-rule-beyer-control-v1")),
            masteryRuleVersion: 1,
            reason: nil,
            decidedAt: try Fixtures.timestamp(decidedAt, timeZoneID: "Europe/London")
        )
    }
}

private extension TodayViewModel {
    var loadedState: TodayLoadedState? {
        if case .loaded(let loaded) = state {
            return loaded
        }

        return nil
    }
}

private actor TodayReadOnlyRepository: ProgrammeProgressRepository, PracticeHistoryRepository {
    private let snapshot: ProgrammeProgressSnapshot?
    private let masteryDecisions: [MasteryDecisionRecord]
    private(set) var writeCount = 0
    private(set) var didLoadChronologicalHistory = false

    init(snapshot: ProgrammeProgressSnapshot?, masteryDecisions: [MasteryDecisionRecord]) {
        self.snapshot = snapshot
        self.masteryDecisions = masteryDecisions
    }

    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot? {
        snapshot
    }

    func saveActiveProgress(_ progress: ActiveProgrammeProgress) async throws {
        writeCount += 1
    }

    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws {
        writeCount += 1
    }

    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws {
        writeCount += 1
    }

    func recordSession(_ session: PracticeSessionRecord) async throws {
        writeCount += 1
    }

    func recordAttempt(_ attempt: PerformanceAttemptRecord) async throws {
        writeCount += 1
    }

    func recordReflection(_ reflection: StudentReflectionRecord) async throws {
        writeCount += 1
    }

    func recordMasteryDecision(_ decision: MasteryDecisionRecord) async throws {
        writeCount += 1
    }

    func latestMasteryDecisions(programmeID: PracticeProgrammeID) async throws -> [MasteryDecisionRecord] {
        masteryDecisions
    }

    func chronologicalHistory() async throws -> [PracticeHistoryEvent] {
        didLoadChronologicalHistory = true
        return []
    }

    func deleteSession(id: PracticeSessionRecordID) async throws {
        writeCount += 1
    }

    func deleteAllPersonalPracticeData() async throws {
        writeCount += 1
    }
}

private actor TodayFailingProgressRepository: ProgrammeProgressRepository, PracticeHistoryRepository {
    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot? {
        throw Failure()
    }

    func saveActiveProgress(_ progress: ActiveProgrammeProgress) async throws {}
    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws {}
    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws {}
    func recordSession(_ session: PracticeSessionRecord) async throws {}
    func recordAttempt(_ attempt: PerformanceAttemptRecord) async throws {}
    func recordReflection(_ reflection: StudentReflectionRecord) async throws {}
    func recordMasteryDecision(_ decision: MasteryDecisionRecord) async throws {}
    func latestMasteryDecisions(programmeID: PracticeProgrammeID) async throws -> [MasteryDecisionRecord] { [] }
    func chronologicalHistory() async throws -> [PracticeHistoryEvent] { [] }
    func deleteSession(id: PracticeSessionRecordID) async throws {}
    func deleteAllPersonalPracticeData() async throws {}

    private struct Failure: Error {}
}
