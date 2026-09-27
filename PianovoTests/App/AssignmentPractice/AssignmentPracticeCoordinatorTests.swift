import Foundation
import Synchronization
import Testing
@testable import Pianovo

@MainActor
struct AssignmentPracticeCoordinatorTests {
    @Test func preparationAndRepeatedConcurrentStartsWriteNothingAndKeepOneIdentity() async {
        let repository = AssignmentRepositoryDouble()
        let time = AssignmentTestTime()
        var identities = 0
        let model = makeModel(repository, time: time, makeID: {
            identities += 1
            return PracticeSessionRecordID("session-\(identities)")!
        })
        #expect(model.state == .preparation)
        #expect(model.pendingRecord == nil)
        #expect(repository.sessions.isEmpty)
        let first = Task { model.start() }
        let second = Task { model.start() }
        await first.value
        await second.value
        #expect(identities == 1)
        #expect(model.sessionID == PracticeSessionRecordID("session-1"))
        #expect(model.startedAt?.instant == time.now)
        #expect(model.state == .active)
        #expect(repository.writeCount == 0)
    }

    @Test func finishFreezesActualStatisticsAndSavesOnlyStoppedSession() async throws {
        let repository = AssignmentRepositoryDouble()
        let time = AssignmentTestTime()
        let model = makeModel(repository, time: time)
        model.start()
        let expected = model.practice.currentPrompt.expectedPitch
        model.submit(event(expected))
        let next = model.practice.currentPrompt.expectedPitch
        model.submit(event(next == Pitch(.c, octave: 4) ? Pitch(.d, octave: 4) : Pitch(.c, octave: 4)))
        let snapshot = model.practice.statistics
        time.advance(120)
        await model.finish()
        let record = try #require(repository.sessions.first)
        #expect(repository.sessions.count == 1)
        #expect(record.context == AssignmentFixtures.context.recordContext)
        #expect(record.outcome == .stopped)
        #expect(record.duration == 120)
        #expect(model.summary == snapshot)
        #expect(snapshot.correctAnswers == 1 && snapshot.incorrectAttempts == 1)
        #expect(snapshot.totalAttempts == 2 && snapshot.promptsCompleted == 1)
        #expect(snapshot.currentStreak == 0 && snapshot.accuracyPercentage == 50)
        model.submit(event(model.practice.currentPrompt.expectedPitch))
        #expect(model.practice.statistics == snapshot)
        await model.finish()
        #expect(repository.writeCount == 1)
        #expect(model.state == .finished)
    }

    @Test func inactiveSuspendsInputWithoutEndingAndBackgroundFreezesAtObservedTime() async throws {
        let repository = AssignmentRepositoryDouble()
        let time = AssignmentTestTime()
        let model = makeModel(repository, time: time)
        model.start()
        model.setForegroundActive(false)
        model.submit(event(model.practice.currentPrompt.expectedPitch))
        #expect(model.practice.statistics.totalAttempts == 0)
        #expect(model.state == .active)
        #expect(model.pendingRecord == nil)
        model.setForegroundActive(true)
        model.submit(event(model.practice.currentPrompt.expectedPitch))
        #expect(model.practice.statistics.totalAttempts == 1)
        time.advance(45)
        model.background()
        let frozen = try #require(model.pendingRecord)
        #expect(model.state == .interrupted)
        time.advance(600)
        model.background()
        model.setForegroundActive(true)
        model.submit(event(model.practice.currentPrompt.expectedPitch))
        model.start()
        #expect(model.practice.statistics.totalAttempts == 1)
        #expect(repository.writeCount == 0)
        await model.finish()
        #expect(repository.sessions == [frozen])
        #expect(frozen.duration == 45)
    }

    @Test func discardNeverWritesAndCannotRestart() async {
        for started in [false, true] {
            let repository = AssignmentRepositoryDouble()
            let model = makeModel(repository)
            if started { model.start(); model.background() }
            model.discard()
            model.start()
            model.submit(event(model.practice.currentPrompt.expectedPitch))
            await model.finish()
            #expect(repository.writeCount == 0)
            #expect(model.state == .discarded)
            #expect(model.practice.statistics.totalAttempts == 0)
        }
    }

    @Test func zeroInputSessionHasEmptyFrozenStatistics() async {
        let model = makeModel(AssignmentRepositoryDouble())
        model.start()
        await model.finish()
        #expect(model.summary == PracticeStatistics())
        #expect(model.summary?.totalAttempts == 0)
        #expect(model.state == .finished)
    }

    @Test func failedSaveRetainsExactRecordAcrossRetryAndConcurrentFinish() async throws {
        let repository = AssignmentRepositoryDouble()
        repository.failBeforeSave = true
        let time = AssignmentTestTime()
        let model = makeModel(repository, time: time)
        model.start()
        time.advance(10)
        await model.finish()
        #expect(model.state == .failed(.saveFailed))
        let pending = try #require(model.pendingRecord)
        time.advance(90)
        repository.failBeforeSave = false
        repository.pauseNextWrite = true
        let retry = Task { await model.finish() }
        await repository.waitUntilPaused()
        #expect(model.state == .finishing)
        model.discard()
        model.start()
        await model.finish()
        model.submit(event(model.practice.currentPrompt.expectedPitch))
        #expect(model.practice.statistics.totalAttempts == 0)
        repository.release()
        await retry.value
        #expect(repository.sessions == [pending])
        #expect(repository.writeCount == 2)
        #expect(model.pendingRecord == pending)
        #expect(pending.duration == 10)
    }

    @Test func ambiguousSuccessfulWriteReconcilesExactRecordOnly() async {
        let repository = AssignmentRepositoryDouble()
        repository.failAfterSave = true
        let model = makeModel(repository)
        model.start()
        await model.finish()
        #expect(model.state == .failed(.saveFailed))
        #expect(repository.sessions.count == 1)
        repository.failAfterSave = false
        await model.finish()
        #expect(model.state == .finished)
        #expect(repository.sessions.count == 1)
        #expect(repository.readCount == 1)
    }

    @Test func conflictingDuplicateIsStructuredAndNeverOverwritten() async throws {
        let repository = AssignmentRepositoryDouble()
        let model = makeModel(repository)
        model.start()
        let other = PracticeSessionRecord(id: PracticeSessionRecordID("fixed-session")!,
            context: AssignmentFixtures.context.recordContext, startedAt: try #require(model.startedAt),
            endedAt: nil, outcome: .abandoned)
        repository.sessions = [other]
        await model.finish()
        #expect(model.state == .failed(.conflictingRecord))
        #expect(repository.sessions == [other])
        #expect(!model.canSave)
    }

    @Test func duplicateWithoutDurableRecordOrFailedReadDoesNotClaimSuccess() async {
        let repository = AssignmentRepositoryDouble()
        repository.duplicateWithoutRecord = true
        let model = makeModel(repository)
        model.start()
        await model.finish()
        #expect(model.state == .failed(.verificationFailed))
        repository.failRead = true
        await model.finish()
        #expect(model.state == .failed(.verificationFailed))
        repository.failRead = false
        repository.duplicateWithoutRecord = false
        await model.finish()
        #expect(model.state == .finished)
        #expect(repository.sessions.count == 1)
    }

    @Test func negativeClockMovementFailsWithoutWritingOrInventingEnd() async throws {
        let repository = AssignmentRepositoryDouble()
        let time = AssignmentTestTime()
        let model = makeModel(repository, time: time)
        model.start()
        time.advance(-1)
        await model.finish()
        #expect(model.state == .failed(.invalidTimeRange))
        #expect(model.pendingRecord?.endedAt?.instant == time.now)
        #expect(repository.writeCount == 0)
        time.advance(100)
        await model.finish()
        #expect(repository.writeCount == 0)
        #expect(!model.acceptsInput)
    }

    @Test func unavailablePersistenceCannotStart() {
        let model = makeModel(nil)
        model.start()
        #expect(model.state == .failed(.persistenceUnavailable))
        #expect(model.sessionID == nil)
        #expect(model.startedAt == nil)
    }

    @Test(arguments: ["2026-03-29T00:59:30Z", "2026-10-25T00:59:30Z", "2026-09-27T22:59:30Z"])
    func timestampsRetainLocalContextsAcrossDSTAndMidnight(iso: String) async throws {
        let time = AssignmentTestTime(instant: try #require(ISO8601DateFormatter().date(from: iso)))
        let model = makeModel(AssignmentRepositoryDouble(), time: time)
        let start = PracticeTimestamp(instant: time.now, timeZone: time.timeZone)
        model.start()
        time.advance(60)
        let end = PracticeTimestamp(instant: time.now, timeZone: time.timeZone)
        await model.finish()
        #expect(model.pendingRecord?.startedAt == start)
        #expect(model.pendingRecord?.endedAt == end)
        #expect(model.pendingRecord?.duration == 60)
    }

    @Test func timezoneChangeDoesNotRecalculateStartContext() async {
        let time = AssignmentTestTime()
        let model = makeModel(AssignmentRepositoryDouble(), time: time)
        model.start()
        let start = model.startedAt
        time.setZone("America/New_York")
        time.advance(60)
        await model.finish()
        #expect(model.pendingRecord?.startedAt == start)
        #expect(model.pendingRecord?.startedAt.localDay.timeZoneIdentifier == "Europe/London")
        #expect(model.pendingRecord?.endedAt?.localDay.timeZoneIdentifier == "America/New_York")
    }

    @Test func injectedBassConfigurationIsPreservedAndNoteReleasesAreIgnored() {
        let practice = PracticeViewModel(initialMode: .bassReading)
        let time = AssignmentTestTime()
        let model = AssignmentPracticeCoordinator(context: AssignmentFixtures.context,
            repository: AssignmentRepositoryDouble(), clock: time, localContext: time,
            makeID: { PracticeSessionRecordID("bass")! }, practice: practice)
        model.start()
        #expect(practice.mode == .bassReading)
        let pitch = practice.currentPrompt.expectedPitch
        model.submit(MIDIInputEvent(kind: .noteReleased, pitch: pitch, midiNoteNumber: pitch.midiNoteNumber, velocity: 0, channel: 1))
        #expect(practice.statistics.totalAttempts == 0)
        model.submit(event(pitch))
        #expect(practice.statistics.correctAnswers == 1)
    }

    @Test func realRepositoryReceivesOnlySessionAndPreservesProgrammeSnapshot() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        let progress = try Fixtures.activeProgress()
        try await repository.saveActiveProgress(progress)
        let before = try await repository.loadProgress(programmeID: progress.programme.programmeID)
        let time = AssignmentTestTime()
        let model = AssignmentPracticeCoordinator(context: AssignmentFixtures.context, repository: repository,
            clock: time, localContext: time, makeID: { PracticeSessionRecordID("real-session")! }, practice: PracticeViewModel())
        model.start()
        #expect(try await repository.chronologicalHistory().isEmpty)
        time.advance(60)
        await model.finish()
        #expect(try await repository.chronologicalHistory() == [.session(try #require(model.pendingRecord))])
        #expect(try await repository.loadProgress(programmeID: progress.programme.programmeID) == before)
        #expect(try await repository.latestMasteryDecisions(programmeID: progress.programme.programmeID).isEmpty)
    }

    private func makeModel(_ repository: AssignmentRepositoryDouble?, time: AssignmentTestTime = AssignmentTestTime(),
                           makeID: @escaping () -> PracticeSessionRecordID = { PracticeSessionRecordID("fixed-session")! }) -> AssignmentPracticeCoordinator {
        AssignmentPracticeCoordinator(context: AssignmentFixtures.context, repository: repository,
            clock: time, localContext: time, makeID: makeID, practice: PracticeViewModel())
    }

    private func event(_ pitch: Pitch) -> MIDIInputEvent {
        MIDIInputEvent(kind: .notePressed, pitch: pitch, midiNoteNumber: pitch.midiNoteNumber, velocity: 80, channel: 1)
    }
}

nonisolated final class AssignmentTestTime: PracticeClock, PracticeLocalContextProviding {
    private let storage: Mutex<(Date, TimeZone)>
    init(instant: Date = Date(timeIntervalSince1970: 1_790_496_000)) {
        storage = Mutex((instant, TimeZone(identifier: "Europe/London")!))
    }
    var now: Date { storage.withLock { $0.0 } }
    var timeZone: TimeZone { storage.withLock { $0.1 } }
    var calendarIdentifier: PracticeCalendarIdentifier { .gregorian }
    func advance(_ seconds: TimeInterval) { storage.withLock { $0.0.addTimeInterval(seconds) } }
    func setZone(_ zone: String) { storage.withLock { $0.1 = TimeZone(identifier: zone)! } }
}

@MainActor
private final class AssignmentRepositoryDouble: PracticeHistoryRepository {
    var sessions: [PracticeSessionRecord] = []
    var writeCount = 0
    var readCount = 0
    var failBeforeSave = false
    var failAfterSave = false
    var failRead = false
    var duplicateWithoutRecord = false
    var pauseNextWrite = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?

    func recordSession(_ session: PracticeSessionRecord) async throws {
        writeCount += 1
        if pauseNextWrite {
            pauseNextWrite = false
            await withCheckedContinuation { continuation in
                suspended = continuation
                observer?.resume()
                observer = nil
            }
        }
        if failBeforeSave { throw AssignmentSaveError() }
        if duplicateWithoutRecord || sessions.contains(where: { $0.id == session.id }) {
            throw PracticeHistoryRepositoryError.duplicateID(session.id.rawValue)
        }
        sessions.append(session)
        if failAfterSave { throw AssignmentSaveError() }
    }
    func chronologicalHistory() async throws -> [PracticeHistoryEvent] {
        readCount += 1
        if failRead { throw AssignmentSaveError() }
        return sessions.map(PracticeHistoryEvent.session)
    }
    func waitUntilPaused() async {
        if suspended != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { suspended?.resume(); suspended = nil }
    func recordAttempt(_ attempt: PerformanceAttemptRecord) async throws { Issue.record("Forbidden attempt write") }
    func recordReflection(_ reflection: StudentReflectionRecord) async throws { Issue.record("Forbidden reflection write") }
    func recordMasteryDecision(_ decision: MasteryDecisionRecord) async throws { Issue.record("Forbidden mastery write") }
    func latestMasteryDecisions(programmeID: PracticeProgrammeID) async throws -> [MasteryDecisionRecord] { [] }
    func deleteSession(id: PracticeSessionRecordID) async throws { Issue.record("Unexpected deletion") }
    func deleteAllPersonalPracticeData() async throws { Issue.record("Unexpected deletion") }
}

private struct AssignmentSaveError: Error {}
