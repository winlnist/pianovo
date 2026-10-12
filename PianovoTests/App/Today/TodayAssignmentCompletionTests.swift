import Foundation
import Testing
@testable import Pianovo

@MainActor
struct TodayAssignmentCompletionTests {
    @Test(arguments: ["week-01-day-01", "week-01-day-07"])
    func allCurrentDayAssignmentsCanBeSelfReportedIncludingUnavailableAndRecoveryWork(dayID: String) async throws {
        let repository = CompletionRepositoryDouble()
        let progress = try Fixtures.activeProgress(currentDayID: dayID)
        try await repository.backing.saveActiveProgress(progress)
        let model = makeModel(repository)
        await model.load()
        let day = try loaded(model)
        for block in day.allBlocks {
            for assignment in block.assignments {
                await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true,
                    confirmedComponents: Set(assignment.requiredCompletionComponents.map(\.id)))
                #expect(model.completionState == .ready)
                #expect(try status(model, assignment.id) == .completed)
            }
        }
        let snapshot = try #require(try await repository.backing.loadProgress(programmeID: progress.programme.programmeID))
        #expect(snapshot.activeProgress == progress)
        #expect(snapshot.assignmentCompletions.count == day.allBlocks.flatMap(\.assignments).count)
        #expect(snapshot.assignmentCompletions.allSatisfy { $0.status == .completed && $0.completedAt == $0.updatedAt })
        #expect(try await repository.backing.chronologicalHistory().isEmpty)
    }

    @Test func completionAndUndoRestoreAcrossNewViewModelsWithoutAdvancingPosition() async throws {
        let repository = try await preparedRepository()
        let time = AssignmentTestTime()
        let model = makeModel(repository, time: time)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        let restored = makeModel(repository, time: time)
        await restored.load()
        #expect(try status(restored, assignment.id) == .completed)
        time.advance(60)
        await restored.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: false)
        let reopened = makeModel(repository, time: time)
        await reopened.load()
        #expect(try status(reopened, assignment.id) == .notStarted)
        let record = try #require(repository.requests.last)
        #expect(record.completedAt == nil)
        #expect(record.updatedAt.instant == time.now)
        #expect(try loaded(reopened).dayTitle == "Day 1")
        #expect(try await repository.backing.chronologicalHistory().isEmpty)
    }

    @Test func beyerRequiresBothComponentsForCompleteButNotUndo() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let block = try #require(try loaded(model).morningBlocks.first { $0.category == .beyer })
        let assignment = try #require(block.assignments.first)
        let required = assignment.requiredCompletionComponents
        #expect(required.map(\.role) == [.seconda, .prima])
        for confirmed in [Set<ReferenceMaterialComponentID>(), Set([required[0].id])] {
            await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true,
                                              confirmedComponents: confirmed)
            #expect(model.completionState == .failed(assignment.id, .requiredComponentsMissing))
            #expect(repository.requests.isEmpty)
            await model.load()
        }
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true,
                                          confirmedComponents: Set(required.map(\.id)))
        #expect(try status(model, assignment.id) == .completed)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: false)
        #expect(try status(model, assignment.id) == .notStarted)
        #expect(repository.requests.count == 2)
    }

    @Test func beyerRequirementsSurviveUnknownMaterialResolution() {
        let assignment = TodayAssignmentState(id: PracticeAssignmentID("beyer")!, title: "Beyer", goal: "Practise",
            sourceID: ExerciseSourceID("beyer-op101-no-63")!, sourceTitle: "Beyer No. 63", completionStatus: .notStarted,
            masteryState: nil, referenceMaterial: .unknownSource)
        #expect(assignment.requiredCompletionComponents.map(\.role) == [.seconda, .prima])
    }

    @Test func invalidBlockOrAssignmentNeverWrites() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        await model.setAssignmentCompleted(blockID: PracticeBlockID("foreign")!, assignmentID: assignment.id, completed: true)
        #expect(model.completionState == .failed(assignment.id, .invalidAssignment))
        await model.load()
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: PracticeAssignmentID("foreign")!, completed: true)
        #expect(repository.requests.isEmpty)
    }

    @Test(arguments: [false, true])
    func changedPositionOrVersionRejectsStaleAction(versionChanged: Bool) async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        let original = try Fixtures.activeProgress()
        let changed = ActiveProgrammeProgress(
            programme: ProgrammeDefinitionReference(programmeID: original.programme.programmeID,
                programmeVersion: versionChanged ? original.programme.programmeVersion + 1 : original.programme.programmeVersion),
            currentWeekID: original.currentWeekID,
            currentDayID: versionChanged ? original.currentDayID : PracticeDayID("week-01-day-02"), updatedAt: original.updatedAt)
        try await repository.backing.saveActiveProgress(changed)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        #expect(model.completionState == .failed(assignment.id, .positionChanged))
        #expect(repository.requests.isEmpty)
        #expect(try await repository.backing.loadProgress(programmeID: original.programme.programmeID)?.activeProgress == changed)
    }

    @Test func repeatedTapsLoadsAndStartsAreGatedAcrossSuspension() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        repository.pauseNextWrite = true
        let first = Task { await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true) }
        await repository.waitUntilPaused()
        #expect(model.completionState == .saving(assignment.id))
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: false)
        await model.retryCompletion()
        await model.load()
        await model.startProgramme()
        #expect(repository.requests.count == 1)
        repository.release()
        await first.value
        #expect(try status(model, assignment.id) == .completed)
    }

    @Test func failedSaveKeepsVisibleStatusAndExactTimestampUntilRetry() async throws {
        let repository = try await preparedRepository()
        let time = AssignmentTestTime()
        let model = makeModel(repository, time: time)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        repository.failBeforeWrite = true
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        #expect(model.completionState == .failed(assignment.id, .saveFailed))
        #expect(try status(model, assignment.id) == .notStarted)
        let pending = try #require(repository.requests.first)
        time.advance(86400)
        time.setZone("America/New_York")
        repository.failBeforeWrite = false
        await model.retryCompletion()
        #expect(repository.requests == [pending, pending])
        #expect(try status(model, assignment.id) == .completed)
        #expect(pending.updatedAt.localDay.timeZoneIdentifier == "Europe/London")
    }

    @Test func ambiguousSaveIsConfirmedOnRetryWithoutAnotherWrite() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        repository.failAfterWrite = true
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        #expect(model.completionState == .failed(assignment.id, .saveFailed))
        #expect(try status(model, assignment.id) == .notStarted)
        repository.failAfterWrite = false
        await model.retryCompletion()
        #expect(repository.requests.count == 1)
        #expect(try status(model, assignment.id) == .completed)
    }

    @Test func noOpSaveCannotClaimSuccessAndRetryIsSafe() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        repository.ignoreWrite = true
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        #expect(model.completionState == .failed(assignment.id, .verificationFailed))
        #expect(try status(model, assignment.id) == .notStarted)
        repository.ignoreWrite = false
        await model.retryCompletion()
        #expect(repository.requests.first == repository.requests.last)
        #expect(try status(model, assignment.id) == .completed)
    }

    @Test func readFailuresBeforeAndAfterSaveAreRetryable() async throws {
        for failAfter in [false, true] {
            let repository = try await preparedRepository()
            let model = makeModel(repository)
            await model.load()
            let (block, assignment) = try firstAssignment(model)
            repository.failRead = !failAfter
            repository.failReadAfterWrite = failAfter
            await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
            #expect(model.completionState == .failed(assignment.id, .progressLoadFailed))
            #expect(try status(model, assignment.id) == .notStarted)
            repository.failRead = false
            repository.failReadAfterWrite = false
            await model.retryCompletion()
            #expect(repository.requests.count == 1)
            #expect(try status(model, assignment.id) == .completed)
        }
    }

    @Test func refreshClearsFailedIntentAndReadsDurableState() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        repository.failAfterWrite = true
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        await model.load()
        #expect(model.completionState == .ready)
        #expect(try status(model, assignment.id) == .completed)
        await model.retryCompletion()
        #expect(repository.requests.count == 1)
    }

    @Test func repeatedCompleteAndUndoDoNotRewriteTimestamps() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        for completed in [true, true, false, false] {
            await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: completed)
        }
        #expect(repository.requests.count == 2)
    }

    @Test func existingNotesArePreservedAndForeignSourceIsRejected() async throws {
        let repository = try await preparedRepository()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        let day = try loaded(model)
        let timestamp = try Fixtures.timestamp("2026-09-01T10:00:00Z", timeZoneID: "Europe/London")
        let existing = AssignmentCompletionState(programme: ProgrammeDefinitionReference(
            programmeID: day.programme.programmeID, programmeVersion: day.programme.programmeVersion),
            assignmentID: assignment.id, sourceID: assignment.sourceID, status: .inProgress,
            updatedAt: timestamp, completedAt: nil, note: "Existing reflection.")
        try await repository.backing.updateAssignmentCompletion(existing)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        #expect(repository.requests.last?.note == existing.note)
        let foreign = AssignmentCompletionState(programme: existing.programme, assignmentID: assignment.id,
            sourceID: ExerciseSourceID("foreign")!, status: .notStarted, updatedAt: timestamp, completedAt: nil, note: nil)
        try await repository.backing.updateAssignmentCompletion(foreign)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        #expect(model.completionState == .failed(assignment.id, .invalidAssignment))
        #expect(repository.requests.count == 1)
    }

    @Test func completionAndUndoKeepExistingHistoryAndMastery() async throws {
        let repository = try await preparedRepository()
        try await repository.backing.recordSession(try Fixtures.session())
        try await repository.backing.recordMasteryDecision(try Fixtures.masteryDecision())
        let history = try await repository.backing.chronologicalHistory()
        let model = makeModel(repository)
        await model.load()
        let (block, assignment) = try firstAssignment(model)
        let before = try loaded(model)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: true)
        await model.setAssignmentCompleted(blockID: block.id, assignmentID: assignment.id, completed: false)
        #expect(try await repository.backing.chronologicalHistory() == history)
        #expect(try loaded(model) == before)
    }

    private func preparedRepository() async throws -> CompletionRepositoryDouble {
        let repository = CompletionRepositoryDouble()
        try await repository.backing.saveActiveProgress(try Fixtures.activeProgress())
        return repository
    }
    private func makeModel(_ repository: CompletionRepositoryDouble, time: AssignmentTestTime = AssignmentTestTime()) -> TodayViewModel {
        TodayViewModel(progressRepository: repository, practiceHistoryRepository: repository.backing,
                       clock: time, localContextProvider: time)
    }
    private func loaded(_ model: TodayViewModel) throws -> TodayLoadedState {
        guard case .loaded(let day) = model.state else { throw CompletionTestFailure() }
        return day
    }
    private func firstAssignment(_ model: TodayViewModel) throws -> (TodayPracticeBlockState, TodayAssignmentState) {
        let block = try #require(try loaded(model).morningBlocks.first { $0.category != .beyer })
        return (block, try #require(block.assignments.first))
    }
    private func status(_ model: TodayViewModel, _ id: PracticeAssignmentID) throws -> AssignmentCompletionStatus {
        try #require(try loaded(model).allBlocks.flatMap(\.assignments).first { $0.id == id }).completionStatus
    }
}

private struct CompletionTestFailure: Error {}

@MainActor
private final class CompletionRepositoryDouble: ProgrammeProgressRepository {
    let backing = InMemoryPracticeHistoryRepository()
    var requests: [AssignmentCompletionState] = []
    var failBeforeWrite = false
    var failAfterWrite = false
    var failRead = false
    var failReadAfterWrite = false
    var ignoreWrite = false
    var pauseNextWrite = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?

    func loadProgress(programmeID: PracticeProgrammeID) async throws -> ProgrammeProgressSnapshot? {
        if failRead || (failReadAfterWrite && !requests.isEmpty) { throw CompletionTestFailure() }
        return try await backing.loadProgress(programmeID: programmeID)
    }
    func updateAssignmentCompletion(_ completion: AssignmentCompletionState) async throws {
        requests.append(completion)
        if pauseNextWrite {
            pauseNextWrite = false
            await withCheckedContinuation { continuation in
                suspended = continuation
                observer?.resume()
                observer = nil
            }
        }
        if failBeforeWrite { throw CompletionTestFailure() }
        if !ignoreWrite { try await backing.updateAssignmentCompletion(completion) }
        if failAfterWrite { throw CompletionTestFailure() }
    }
    func waitUntilPaused() async {
        if suspended != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { suspended?.resume(); suspended = nil }
    func saveActiveProgress(_ progress: ActiveProgrammeProgress) async throws { Issue.record("Completion must not advance progress") }
    func resetProgrammeProgress(programmeID: PracticeProgrammeID) async throws { Issue.record("Completion must not reset progress") }
}
