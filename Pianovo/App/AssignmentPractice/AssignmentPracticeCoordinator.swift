import Combine
import Foundation

nonisolated enum AssignmentPracticeState: Equatable {
    case preparation, starting, active, interrupted, finishing, finished, discarded
    case failed(AssignmentPracticeFailure)
}

nonisolated enum AssignmentPracticeFailure: Equatable {
    case persistenceUnavailable, invalidTimeRange, saveFailed, conflictingRecord, verificationFailed
}

@MainActor
final class AssignmentPracticeCoordinator: ObservableObject {
    @Published private(set) var state: AssignmentPracticeState = .preparation
    @Published private(set) var isForegroundActive = true
    let context: AssignmentPracticeContext
    let practice: PracticeViewModel
    private(set) var sessionID: PracticeSessionRecordID?
    private(set) var startedAt: PracticeTimestamp?
    private(set) var pendingRecord: PracticeSessionRecord?
    private(set) var summary: PracticeStatistics?
    private let repository: (any PracticeHistoryRepository)?
    private let clock: any PracticeClock
    private let localContext: any PracticeLocalContextProviding
    private let makeID: () -> PracticeSessionRecordID

    init(context: AssignmentPracticeContext, repository: (any PracticeHistoryRepository)?,
         clock: any PracticeClock, localContext: any PracticeLocalContextProviding,
         makeID: @escaping () -> PracticeSessionRecordID, practice: PracticeViewModel) {
        self.context = context
        self.repository = repository
        self.clock = clock
        self.localContext = localContext
        self.makeID = makeID
        self.practice = practice
    }

    var acceptsInput: Bool { state == .active && isForegroundActive }
    var canSave: Bool {
        switch state {
        case .active, .interrupted: true
        case .failed(.saveFailed), .failed(.verificationFailed): true
        default: false
        }
    }

    func start() {
        guard state == .preparation, isForegroundActive else { return }
        state = .starting
        guard repository != nil else {
            state = .failed(.persistenceUnavailable)
            return
        }
        sessionID = makeID()
        startedAt = timestamp()
        practice.resetSession()
        state = .active
    }

    func submit(_ event: MIDIInputEvent) {
        guard acceptsInput else { return }
        practice.submit(event)
    }

    func setForegroundActive(_ active: Bool) { isForegroundActive = active }

    func background() {
        isForegroundActive = false
        guard state == .active else { return }
        freeze()
        if case .failed = state { return }
        state = .interrupted
    }

    func discard() {
        guard state != .finishing && state != .finished else { return }
        state = .discarded
    }

    func finish() async {
        guard canSave else { return }
        if state == .active { freeze() }
        guard let record = pendingRecord, let repository else { return }
        if case .failed(.invalidTimeRange) = state { return }
        // Freeze/gate before suspension. Retries reuse the exact same value.
        state = .finishing
        do {
            try await repository.recordSession(record)
            state = .finished
        } catch PracticeHistoryRepositoryError.duplicateID {
            await reconcile(record, repository: repository)
        } catch {
            state = .failed(.saveFailed)
        }
    }

    private func reconcile(_ record: PracticeSessionRecord, repository: any PracticeHistoryRepository) async {
        do {
            let existing = try await repository.chronologicalHistory().compactMap { event -> PracticeSessionRecord? in
                if case .session(let session) = event, session.id == record.id { return session }
                return nil
            }
            if existing == [record] {
                state = .finished
            } else if existing.isEmpty {
                state = .failed(.verificationFailed)
            } else {
                state = .failed(.conflictingRecord)
            }
        } catch {
            state = .failed(.verificationFailed)
        }
    }

    private func freeze() {
        guard pendingRecord == nil, let sessionID, let startedAt else { return }
        let end = timestamp()
        summary = practice.statistics
        pendingRecord = PracticeSessionRecord(id: sessionID, context: context.recordContext,
                                             startedAt: startedAt, endedAt: end, outcome: .stopped)
        if end.instant < startedAt.instant { state = .failed(.invalidTimeRange) }
    }

    private func timestamp() -> PracticeTimestamp {
        let temporal = PracticeTemporalContext(clock: clock, localContextProvider: localContext)
        return PracticeTimestamp(instant: temporal.now, localDay: temporal.localDay)
    }
}
