import Foundation
import Testing
@testable import Pianovo

@MainActor
struct TodayProgrammeStartTests {
    @Test func firstLaunchLoadsOnceWithoutStarting() async throws {
        let repository = StartProgressRepository()
        let model = makeModel(repository)
        #expect(model.state == .idle)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        guard case .programmeNotStarted = model.state else {
            Issue.record("First launch must wait for explicit start")
            return
        }
        #expect(repository.loadCount == 1)
        #expect(repository.saveCount == 0)
        #expect(try await repository.backing.loadProgress(programmeID: seed.programme.id) == nil)
    }

    @Test func explicitStartSavesFirstDayReloadsAndCreatesNoPracticeRecords() async throws {
        let repository = StartProgressRepository()
        let model = makeModel(repository)
        await model.loadIfNeeded()
        await model.startProgramme()

        let loaded = try loadedState(model)
        let firstWeek = try #require(seed.programme.weeks.min { $0.number < $1.number })
        let firstDay = try #require(firstWeek.days.min { $0.dayNumber < $1.dayNumber })
        #expect(loaded.weekID == firstWeek.id)
        #expect(loaded.dayID == firstDay.id)
        #expect(loaded.weekTitle == "Week 1")
        #expect(loaded.dayTitle == "Day 1")
        #expect(model.startState == .ready)
        #expect(repository.saveCount == 1)
        let snapshot = try #require(try await repository.backing.loadProgress(programmeID: seed.programme.id))
        let active = try #require(snapshot.activeProgress)
        #expect(active.programme.programmeID == seed.programme.id)
        #expect(active.programme.programmeVersion == 1)
        #expect(active.updatedAt.instant == clock.now)
        #expect(active.updatedAt.localDay.timeZoneIdentifier == "Europe/London")
        #expect(active.updatedAt.localDay.calendarIdentifier == .gregorian)
        #expect(active.updatedAt.localDay.dayKey == "2026-03-30")
        #expect(snapshot.assignmentCompletions.isEmpty)
        #expect(try await repository.backing.chronologicalHistory().isEmpty)
        #expect(try await repository.backing.latestMasteryDecisions(programmeID: seed.programme.id).isEmpty)
    }

    @Test func startedDayKeepsBeyer63AndItsTwoRequiredPartsTogether() async throws {
        let repository = StartProgressRepository()
        let model = makeModel(repository)
        await model.startProgramme()
        let loaded = try loadedState(model)
        #expect(!loaded.morningBlocks.isEmpty)
        #expect(!loaded.eveningBlocks.isEmpty)
        #expect(loaded.hasPartialReferenceMaterialAvailability)
        let assignments = loaded.allBlocks.flatMap(\.assignments)
        let beyer = assignments.filter { $0.sourceID == ExerciseSourceID("beyer-op101-no-63") }
        #expect(!beyer.isEmpty)
        for assignment in beyer {
            #expect(assignment.sourceTitle == "Beyer Op. 101 No. 63")
            guard case .knownUnavailable(let material, .notImported) = assignment.referenceMaterial else {
                Issue.record("Unavailable Beyer material must retain its assignment and components")
                continue
            }
            let required = material.components.filter(\.isRequiredForCompleteExercise)
            #expect(Set(required.map(\.role)) == [.seconda, .prima])
            #expect(assignment.completionStatus == .notStarted)
            #expect(assignment.masteryState == nil)
        }
        #expect(assignments.allSatisfy { !$0.sourceTitle.contains("No. 64") && !$0.sourceTitle.contains("No. 65") })
        #expect(seed.sourceCatalogue.sources.compactMap(\.beyerExerciseNumber) == [63])
    }

    @Test func repeatedStartsDoNotWriteAgainOrChangeTimestamp() async throws {
        let repository = StartProgressRepository()
        let model = makeModel(repository)
        await model.startProgramme()
        let before = try await repository.backing.loadProgress(programmeID: seed.programme.id)
        await model.startProgramme()
        #expect(repository.saveCount == 1)
        #expect(try await repository.backing.loadProgress(programmeID: seed.programme.id) == before)
        #expect(try loadedState(model).dayTitle == "Day 1")
    }

    @Test func staleNotStartedScreenPreservesWeekFiveDayThree() async throws {
        let repository = StartProgressRepository()
        let model = makeModel(repository)
        await model.loadIfNeeded()
        let progress = try Fixtures.activeProgress(currentWeekID: "week-05", currentDayID: "week-05-day-03")
        try await repository.backing.saveActiveProgress(progress)
        await model.startProgramme()
        #expect(try loadedState(model).weekTitle == "Week 5")
        #expect(try loadedState(model).dayTitle == "Day 3")
        #expect(repository.saveCount == 0)
        #expect(try await repository.backing.loadProgress(programmeID: seed.programme.id)?.activeProgress == progress)
    }

    @Test func concurrentStartsAndLoadsShareOneInFlightOperation() async throws {
        let repository = StartProgressRepository()
        repository.pauseNextLoad = true
        let model = makeModel(repository)
        let first = Task { await model.startProgramme() }
        await repository.waitUntilLoadPaused()
        #expect(model.startState == .starting)
        await model.startProgramme()
        await model.loadIfNeeded()
        await model.load()
        #expect(repository.loadCount == 1)
        #expect(repository.saveCount == 0)
        repository.releaseLoad()
        await first.value
        #expect(repository.saveCount == 1)
        #expect(try loadedState(model).dayTitle == "Day 1")
        await model.startProgramme()
        #expect(repository.saveCount == 1)
    }

    @Test func concurrentStartsPreserveAnExistingLaterPosition() async throws {
        let repository = StartProgressRepository()
        repository.pauseNextLoad = true
        let progress = try Fixtures.activeProgress(currentWeekID: "week-05", currentDayID: "week-05-day-03")
        try await repository.backing.saveActiveProgress(progress)
        let model = makeModel(repository)
        let first = Task { await model.startProgramme() }
        await repository.waitUntilLoadPaused()
        await model.startProgramme()
        repository.releaseLoad()
        await first.value
        #expect(repository.saveCount == 0)
        #expect(try loadedState(model).weekTitle == "Week 5")
        #expect(try loadedState(model).dayTitle == "Day 3")
        #expect(try await repository.backing.loadProgress(programmeID: seed.programme.id)?.activeProgress == progress)
    }

    @Test func saveFailureIsStructuredAndStartIsRetryable() async throws {
        let repository = StartProgressRepository()
        repository.failSave = true
        let model = makeModel(repository)
        await model.startProgramme()
        #expect(model.startState == .failed(.progressSaveFailed))
        guard case .programmeNotStarted = model.state else {
            Issue.record("Save failure must retain the Start Programme action")
            return
        }
        #expect(try await repository.backing.loadProgress(programmeID: seed.programme.id) == nil)
        repository.failSave = false
        await model.startProgramme()
        #expect(model.startState == .ready)
        #expect(try loadedState(model).dayTitle == "Day 1")
    }

    @Test func retryAfterAmbiguousSaveDoesNotOverwriteSavedProgress() async throws {
        let repository = StartProgressRepository()
        repository.failAfterSave = true
        let model = makeModel(repository)
        await model.startProgramme()
        #expect(model.startState == .failed(.progressSaveFailed))
        let progress = try Fixtures.activeProgress(currentWeekID: "week-05", currentDayID: "week-05-day-03")
        try await repository.backing.saveActiveProgress(progress)
        repository.failAfterSave = false
        await model.startProgramme()
        #expect(repository.saveCount == 1)
        #expect(try loadedState(model).dayID == progress.currentDayID)
    }

    @Test func startReadFailureNeverWritesAndCanBeRetried() async throws {
        let repository = StartProgressRepository()
        repository.failLoad = true
        let model = makeModel(repository)
        await model.startProgramme()
        #expect(model.startState == .failed(.progressLoadFailed))
        #expect(model.state == .failure(.progressLoadFailed))
        #expect(repository.saveCount == 0)
        repository.failLoad = false
        await model.load()
        #expect(model.startState == .ready)
        await model.startProgramme()
        #expect(try loadedState(model).dayTitle == "Day 1")
    }

    @Test func explicitRetryPerformsFreshLoadButLifecycleDoesNotRetryFailure() async throws {
        let repository = StartProgressRepository()
        repository.failLoad = true
        let model = makeModel(repository)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(repository.loadCount == 1)
        repository.failLoad = false
        let progress = try Fixtures.activeProgress(currentWeekID: "week-05", currentDayID: "week-05-day-03")
        try await repository.backing.saveActiveProgress(progress)
        await model.load()
        #expect(repository.loadCount == 2)
        #expect(try loadedState(model).dayID == progress.currentDayID)
        await model.loadIfNeeded()
        #expect(repository.loadCount == 2)
    }

    @Test func lifecycleLoadsAreCoalescedWhileSuspended() async {
        let repository = StartProgressRepository()
        repository.pauseNextLoad = true
        let model = makeModel(repository)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilLoadPaused()
        #expect(model.state == .loading)
        await model.loadIfNeeded()
        await model.startProgramme()
        #expect(repository.loadCount == 1)
        repository.releaseLoad()
        await first.value
        #expect(repository.saveCount == 0)
    }

    @Test func invalidExistingProgressIsNotReset() async throws {
        let repository = StartProgressRepository()
        let progress = try Fixtures.activeProgress(currentWeekID: "week-99", currentDayID: "week-99-day-01")
        try await repository.backing.saveActiveProgress(progress)
        let model = makeModel(repository)
        await model.startProgramme()
        #expect(model.state == .failure(.invalidPersistedPosition(TodayInvalidPosition(
            weekID: progress.currentWeekID, dayID: progress.currentDayID
        ))))
        #expect(repository.saveCount == 0)
        #expect(try await repository.backing.loadProgress(programmeID: seed.programme.id)?.activeProgress == progress)
    }

    @Test func missingProgrammeAndUnavailablePersistenceNeverStart() async {
        let repository = StartProgressRepository()
        let missing = TodayViewModel(programmeSeed: nil, progressRepository: repository,
                                     practiceHistoryRepository: repository.backing)
        await missing.startProgramme()
        #expect(missing.state == .noProgrammeAvailable(.programmeDefinitionUnavailable))
        #expect(missing.startState == .failed(.programmeDefinitionUnavailable))
        #expect(repository.saveCount == 0)
        let unavailable = TodayViewModel(progressRepository: nil, practiceHistoryRepository: nil)
        await unavailable.startProgramme()
        #expect(unavailable.state == .failure(.persistenceUnavailable))
        #expect(unavailable.startState == .failed(.persistenceUnavailable))
    }

    @Test func seedOrderingDeterminesStartRatherThanArrayOrder() async throws {
        let original = seed.programme
        let reordered = PracticeProgramme(
            id: original.id, title: original.title, progressionPrinciple: original.progressionPrinciple,
            weeks: original.weeks.reversed().map {
                ProgrammeWeek(id: $0.id, number: $0.number, title: $0.title, days: $0.days.reversed())
            }, masteryRules: original.masteryRules
        )
        let repository = StartProgressRepository()
        let model = TodayViewModel(
            programmeSeed: ProgrammeSeed(programme: reordered, sourceCatalogue: seed.sourceCatalogue),
            progressRepository: repository, practiceHistoryRepository: repository.backing,
            clock: clock, localContextProvider: context
        )
        await model.startProgramme()
        #expect(try loadedState(model).weekTitle == "Week 1")
        #expect(try loadedState(model).dayTitle == "Day 1")
    }

    @Test(arguments: ["2026-03-29T00:30:00Z", "2026-03-29T01:30:00Z", "2026-03-29T23:30:00Z", "2026-12-31T23:59:59Z", "2027-01-01T00:00:00Z"])
    func dateAndDaylightSavingNeverAdvanceRecoveryDay(instant: String) async throws {
        let repository = StartProgressRepository()
        let progress = try Fixtures.activeProgress(currentWeekID: "week-01", currentDayID: "week-01-day-07")
        try await repository.backing.saveActiveProgress(progress)
        let model = makeModel(repository, clock: FixedPracticeClock(now: try #require(ISO8601DateFormatter().date(from: instant))))
        await model.startProgramme()
        let loaded = try loadedState(model)
        #expect(loaded.dayKind == .recoveryReflection)
        #expect(loaded.dayID == progress.currentDayID)
        #expect(!loaded.recoveryBlocks.isEmpty)
        #expect(loaded.morningBlocks.isEmpty && loaded.eveningBlocks.isEmpty)
        #expect(repository.saveCount == 0)
    }

    private var seed: ProgrammeSeed { PianovoProgrammeSeedData.twelveWeekProgramme() }
    private var clock: FixedPracticeClock {
        FixedPracticeClock(now: ISO8601DateFormatter().date(from: "2026-03-29T23:30:00Z")!)
    }
    private var context: FixedPracticeLocalContextProvider {
        FixedPracticeLocalContextProvider(timeZone: TimeZone(identifier: "Europe/London")!, calendarIdentifier: .gregorian)
    }
    private func makeModel(_ repository: StartProgressRepository, clock: FixedPracticeClock? = nil) -> TodayViewModel {
        TodayViewModel(progressRepository: repository, practiceHistoryRepository: repository.backing,
                       clock: clock ?? self.clock, localContextProvider: context)
    }
    private func loadedState(_ model: TodayViewModel) throws -> TodayLoadedState {
        guard case .loaded(let value) = model.state else {
            Issue.record("Expected loaded Today, got \(model.state)")
            throw StartTestFailure()
        }
        return value
    }
}

private struct StartTestFailure: Error {}

@MainActor
private final class StartProgressRepository: ProgrammeProgressRepository {
    let backing = InMemoryPracticeHistoryRepository()
    var loadCount = 0
    var saveCount = 0
    var failLoad = false
    var failSave = false
    var failAfterSave = false
    var pauseNextLoad = false
    private var suspendedLoad: CheckedContinuation<Void, Never>?
    private var pauseObserver: CheckedContinuation<Void, Never>?

    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot? {
        loadCount += 1
        if failLoad { throw StartTestFailure() }
        if pauseNextLoad {
            pauseNextLoad = false
            await withCheckedContinuation { continuation in
                suspendedLoad = continuation
                pauseObserver?.resume()
                pauseObserver = nil
            }
        }
        return try await backing.loadProgress(programmeID: programmeID)
    }
    func saveActiveProgress(_ progress: ActiveProgrammeProgress) async throws {
        saveCount += 1
        if failSave { throw StartTestFailure() }
        try await backing.saveActiveProgress(progress)
        if failAfterSave { throw StartTestFailure() }
    }
    func waitUntilLoadPaused() async {
        if suspendedLoad != nil { return }
        await withCheckedContinuation { pauseObserver = $0 }
    }
    func releaseLoad() {
        suspendedLoad?.resume()
        suspendedLoad = nil
    }
    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws {
        Issue.record("Starting must not write completions")
    }
    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws {
        Issue.record("Starting must not reset progress")
    }
}
