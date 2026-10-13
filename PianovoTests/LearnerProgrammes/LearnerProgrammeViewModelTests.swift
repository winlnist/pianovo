import Foundation
import Testing
@testable import Pianovo

@MainActor
struct LearnerProgrammeViewModelTests {
    @Test func initialLoadDoesNotStartAnythingAndCreationSelectsOnlyAcknowledgedPlan() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let model = makeModel(fixture.plans)
        await model.load()
        #expect(model.snapshot.selection == .initial && model.snapshot.plans.isEmpty)
        #expect(model.acknowledgedCreatedPlanID == nil)
        #expect(await model.create(from: fixture.template, name: "My programme"))
        let plan = try #require(model.selectedPlan)
        #expect(plan.id == model.acknowledgedCreatedPlanID)
        #expect(plan.revision.content.name == "My programme" && plan.completions.isEmpty)
        let restarted = makeModel(fixture.plans)
        await restarted.load()
        #expect(restarted.selectedPlan == plan)
        #expect(restarted.acknowledgedCreatedPlanID == nil)
    }

    @Test func validationCanBeCorrectedWithoutLeavingTheCreationForm() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let model = makeModel(fixture.plans)
        await model.load()
        #expect(await model.create(from: fixture.template, name: " ") == false)
        #expect(!model.canRetry && model.snapshot.plans.isEmpty)
        #expect(await model.create(from: fixture.template, name: "Corrected name"))
        #expect(model.selectedPlan?.revision.content.name == "Corrected name")
    }

    @Test func failedAndAmbiguousCreationKeepsIdentityTimeAndSelectionUntilRetry() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let repository = LearnerRepositoryDouble(fixture.plans)
        let clock = AssignmentTestTime()
        let model = makeModel(repository, clock: clock)
        await model.load()
        repository.failBefore = true
        #expect(await model.create(from: fixture.template, name: "Frozen") == false)
        let request = try #require(repository.requests.first)
        #expect(model.canRetry && model.snapshot.selection == .initial)
        clock.advance(1000)
        #expect(await model.create(from: fixture.template, name: "Different") == false)
        #expect(repository.requests == [request])
        repository.failBefore = false; repository.failAfter = true
        await model.retry()
        #expect(model.snapshot.plans.isEmpty)
        repository.failAfter = false; await model.retry()
        #expect(repository.requests == [request, request, request])
        #expect(model.snapshot.plans.count == 1 && model.selectedPlan?.revision.content.name == "Frozen")
        #expect(model.selectedPlan?.id == model.acknowledgedCreatedPlanID)
    }

    @Test func concurrentCreationAndNavigationAreGated() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let repository = LearnerRepositoryDouble(fixture.plans)
        let model = makeModel(repository)
        await model.load()
        repository.pauseNext = true
        let creation = Task { await model.create(from: fixture.template, name: "Only one") }
        await repository.waitUntilPaused()
        #expect(model.actionState == .saving)
        #expect(await model.create(from: fixture.template, name: "Duplicate") == false)
        await model.select(nil); await model.move(1)
        #expect(repository.requests.count == 1)
        repository.release()
        #expect(await creation.value)
        #expect(model.snapshot.plans.count == 1)
    }

    @Test func confirmedNavigationKeepsOldIntentAfterRefreshAndCannotMoveDifferentPlan() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let model = makeModel(fixture.plans)
        await model.load()
        #expect(await model.create(from: fixture.template, name: "First"))
        let firstPlan = try #require(model.selectedPlan)
        let warningIntent = try #require(model.navigationRequest(1, confirmedUnfinished: true))
        #expect(await model.create(from: fixture.template, name: "Second"))
        let secondPlan = try #require(model.selectedPlan)
        await model.performNavigation(warningIntent)
        #expect(model.selectedPlan == secondPlan)
        guard case .failed = model.actionState else { Issue.record("The stale confirmation must fail"); return }
        await model.load(); await model.select(firstPlan.id)
        #expect(model.selectedPlan?.currentDayID == firstPlan.currentDayID)
    }

    @Test func completionNavigationAndProgrammeSwitchingKeepSeparatePositions() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let model = makeModel(fixture.plans)
        await model.load()
        #expect(await model.create(from: fixture.template, name: "My plan"))
        let first = try #require(model.selectedPlan)
        let assignment = try #require(first.currentDay?.sections.first?.placements.first)
        await model.complete(assignment.id, completed: true)
        #expect(model.selectedPlan?.isCompleted(assignment.id) == true)
        #expect(model.selectedPlan?.currentDayID == first.currentDayID)
        await model.move(1)
        let advanced = try #require(model.selectedPlan)
        #expect(advanced.currentDay?.isRecovery == true)
        await model.select(nil)
        #expect(model.selectedPlan == nil)
        await model.select(first.id)
        #expect(model.selectedPlan == advanced)
        await model.move(-1)
        #expect(model.selectedPlan?.isCompleted(assignment.id) == true)
        await model.complete(assignment.id, completed: false)
        #expect(model.selectedPlan?.isCompleted(assignment.id) == false)
    }

    @Test func failedReadsRetainKnownStateAndDisableActions() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let repository = LearnerRepositoryDouble(fixture.plans)
        let model = makeModel(repository)
        await model.load(); _ = await model.create(from: fixture.template, name: "My plan")
        let previous = model.snapshot
        repository.failRead = true
        await model.load()
        #expect(model.loadState == .failed && model.snapshot == previous && !model.allowsActions)
        await model.select(nil)
        #expect(model.snapshot == previous)
        repository.failRead = false; await model.load()
        #expect(model.loadState == .ready && model.snapshot == previous)
        let unavailable = makeModel(nil)
        await unavailable.load()
        #expect(unavailable.loadState == .unavailable && !unavailable.allowsActions)
    }

    @Test func personalEditorKeepsFrozenRetryAndRejectsRemovingCurrentDayBeforeWriting() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: false)
        let repository = LearnerRepositoryDouble(fixture.plans)
        let saved = try await repository.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
        let plan = try #require(saved.selectedPlan)
        let clock = AssignmentTestTime()
        let editor = LearnerPlanEditorViewModel(plan: plan, repository: repository, clock: clock, localContext: context)
        editor.draft.weeks[0].days.removeFirst()
        #expect(await editor.save() == false && editor.canEdit)
        #expect(repository.requests.count == 1)
        editor.draft = plan.revision.content
        editor.draft.name = "Adapted"
        repository.failBefore = true
        #expect(await editor.save() == false && !editor.canEdit)
        let request = try #require(repository.requests.last)
        clock.advance(500)
        editor.draft.name = "Not in pending request"
        editor.addWeek()
        repository.failBefore = false
        #expect(await editor.save())
        #expect(repository.requests.suffix(2) == [request, request])
        #expect(try await repository.snapshot().selectedPlan?.revision.content.name == "Adapted")
    }
    private var context: FixedPracticeLocalContextProvider { FixedPracticeLocalContextProvider(timeZone: TimeZone(identifier: "Europe/London")!, calendarIdentifier: .gregorian) }
    private func makeModel(_ repository: (any LearnerProgrammeRepository)?, clock: any PracticeClock = AssignmentTestTime()) -> LearnerProgrammeViewModel {
        LearnerProgrammeViewModel(repository: repository, clock: clock, localContext: context)
    }
}
@MainActor
private final class LearnerRepositoryDouble: LearnerProgrammeRepository {
    let backing: any LearnerProgrammeRepository
    var requests: [LearnerProgrammeRequest] = []
    var failBefore = false
    var failAfter = false
    var failRead = false
    var pauseNext = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    init(_ backing: any LearnerProgrammeRepository) { self.backing = backing }
    func snapshot() async throws -> LearnerProgrammeSnapshot {
        if failRead { throw LibraryTestError() }; return try await backing.snapshot()
    }
    func revisions(for id: LearnerPlanID) async throws -> [LearnerPlanRevision] { try await backing.revisions(for: id) }
    func apply(_ request: LearnerProgrammeRequest) async throws -> LearnerProgrammeSnapshot {
        requests.append(request)
        if pauseNext {
            pauseNext = false
            await withCheckedContinuation { continuation in suspended = continuation; observer?.resume(); observer = nil }
        }
        if failBefore { throw LibraryTestError() }
        let result = try await backing.apply(request)
        if failAfter { throw LibraryTestError() }
        return result
    }
    func waitUntilPaused() async { if suspended != nil { return }; await withCheckedContinuation { observer = $0 } }
    func release() { suspended?.resume(); suspended = nil }
}
