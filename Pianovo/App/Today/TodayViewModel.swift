import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayViewState = .idle
    @Published private(set) var startState: TodayStartState = .ready
    @Published private(set) var completionState: TodayCompletionState = .ready
    private var pendingCompletion: TodayCompletionRequest?
    private var pendingCompletionRecord: AssignmentCompletionState?
    private var isPerformingOperation = false

    private let programmeSeed: ProgrammeSeed?
    private let progressRepository: (any ProgrammeProgressRepository)?
    private let practiceHistoryRepository: (any PracticeHistoryRepository)?
    private let referenceMaterialResolver: any ReferenceMaterialResolving
    private let clock: any PracticeClock
    private let localContextProvider: any PracticeLocalContextProviding
    private let componentPolicy: TodayAssignmentComponentPolicy

    init(
        programmeSeed: ProgrammeSeed? = PianovoProgrammeSeedData.twelveWeekProgramme(),
        progressRepository: (any ProgrammeProgressRepository)?,
        practiceHistoryRepository: (any PracticeHistoryRepository)?,
        referenceMaterialResolver: any ReferenceMaterialResolving = PianovoReferenceMaterialCatalogue.resolver(),
        clock: any PracticeClock = SystemPracticeClock(),
        localContextProvider: any PracticeLocalContextProviding = SystemPracticeLocalContextProvider(),
        componentPolicy: TodayAssignmentComponentPolicy = TodayAssignmentComponentPolicy()
    ) {
        self.programmeSeed = programmeSeed
        self.progressRepository = progressRepository
        self.practiceHistoryRepository = practiceHistoryRepository
        self.referenceMaterialResolver = referenceMaterialResolver
        self.clock = clock
        self.localContextProvider = localContextProvider
        self.componentPolicy = componentPolicy
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            progressRepository: dependencies.progressRepository,
            practiceHistoryRepository: dependencies.practiceHistoryRepository,
            referenceMaterialResolver: dependencies.referenceMaterialResolver,
            clock: dependencies.clock,
            localContextProvider: dependencies.localContextProvider
        )
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    /// A fresh read for an explicit retry; lifecycle updates use loadIfNeeded instead.
    func load() async {
        guard !isPerformingOperation else { return }
        isPerformingOperation = true
        defer { isPerformingOperation = false }
        startState = .ready
        completionState = .ready
        pendingCompletion = nil
        pendingCompletionRecord = nil
        await loadState()
    }

    func startProgramme() async {
        // Set the gate before the first suspension, including the read-before-write check.
        guard !isPerformingOperation else { return }
        isPerformingOperation = true
        startState = .starting
        defer { isPerformingOperation = false }

        guard let programmeSeed else {
            startState = .failed(.programmeDefinitionUnavailable)
            state = .noProgrammeAvailable(.programmeDefinitionUnavailable)
            return
        }
        guard let progressRepository, practiceHistoryRepository != nil else {
            startState = .failed(.persistenceUnavailable)
            state = .failure(.persistenceUnavailable)
            return
        }

        let programme = programmeSeed.programme
        let snapshot: ProgrammeProgressSnapshot?
        do {
            snapshot = try await progressRepository.loadProgress(programmeID: programme.id)
        } catch {
            startState = .failed(.progressLoadFailed)
            state = .failure(.progressLoadFailed)
            return
        }

        // Existing positions, even invalid ones, must never be silently overwritten.
        if snapshot?.activeProgress == nil {
            guard let week = programme.weeks.min(by: { $0.number < $1.number }),
                  let day = week.days.min(by: { $0.dayNumber < $1.dayNumber }) else {
                startState = .failed(.programmeDefinitionUnavailable)
                state = .noProgrammeAvailable(.programmeDefinitionUnavailable)
                return
            }
            state = .programmeNotStarted(TodayProgrammeSummary(
                programmeID: programme.id, programmeVersion: programme.version, title: programme.title
            ))
            let temporalContext = PracticeTemporalContext(clock: clock, localContextProvider: localContextProvider)
            let progress = ActiveProgrammeProgress(
                programme: ProgrammeDefinitionReference(programmeID: programme.id, programmeVersion: programme.version),
                currentWeekID: week.id,
                currentDayID: day.id,
                updatedAt: PracticeTimestamp(instant: temporalContext.now, localDay: temporalContext.localDay)
            )
            do {
                try await progressRepository.saveActiveProgress(progress)
            } catch {
                startState = .failed(.progressSaveFailed)
                return
            }
        }

        startState = .ready
        await loadState()
    }

    func setAssignmentCompleted(blockID: PracticeBlockID, assignmentID: PracticeAssignmentID,
                                completed: Bool, confirmedComponents: Set<ReferenceMaterialComponentID> = []) async {
        guard !isPerformingOperation, completionState.allowsNewAction,
              case .loaded(let day) = state else { return }
        guard let block = day.allBlocks.first(where: { $0.id == blockID }),
              let assignment = block.assignments.first(where: { $0.id == assignmentID }) else {
            completionState = .failed(assignmentID, .invalidAssignment)
            return
        }
        if completed && !Set(assignment.requiredCompletionComponents.map(\.id)).isSubset(of: confirmedComponents) {
            completionState = .failed(assignmentID, .requiredComponentsMissing)
            return
        }
        let temporal = PracticeTemporalContext(clock: clock, localContextProvider: localContextProvider)
        pendingCompletion = TodayCompletionRequest(
            programme: ProgrammeDefinitionReference(programmeID: day.programme.programmeID,
                                                    programmeVersion: day.programme.programmeVersion),
            weekID: day.weekID, dayID: day.dayID, assignmentID: assignment.id, sourceID: assignment.sourceID,
            status: completed ? .completed : .notStarted,
            timestamp: PracticeTimestamp(instant: temporal.now, localDay: temporal.localDay)
        )
        await savePendingCompletion()
    }

    func retryCompletion() async {
        guard case .failed = completionState else { return }
        await savePendingCompletion()
    }

    private func savePendingCompletion() async {
        guard !isPerformingOperation, let request = pendingCompletion,
              case .loaded(let day) = state else { return }
        isPerformingOperation = true
        completionState = .saving(request.assignmentID)
        defer { isPerformingOperation = false }
        do {
            guard let repository = progressRepository else { throw TodayCompletionFailure.persistenceUnavailable }
            let snapshot = try await completionSnapshot(repository, request: request)
            let existing = snapshot.assignmentCompletions.first { $0.assignmentID == request.assignmentID }
            if let existing, existing.programme != request.programme || existing.sourceID != request.sourceID {
                throw TodayCompletionFailure.invalidAssignment
            }
            // A repeated action (including an ambiguously successful save) is a fresh read, not another write.
            if existing?.status != request.status && !(existing == nil && request.status == .notStarted) {
                if pendingCompletionRecord == nil {
                    pendingCompletionRecord = AssignmentCompletionState(
                        programme: request.programme, assignmentID: request.assignmentID, sourceID: request.sourceID,
                        status: request.status, updatedAt: request.timestamp,
                        completedAt: request.status == .completed ? request.timestamp : nil, note: existing?.note
                    )
                }
                do {
                    try await repository.updateAssignmentCompletion(pendingCompletionRecord!)
                } catch { throw TodayCompletionFailure.saveFailed }
                let verified = try await completionSnapshot(repository, request: request)
                guard verified.assignmentCompletions.contains(pendingCompletionRecord!) else {
                    throw TodayCompletionFailure.verificationFailed
                }
            }
            state = .loaded(day.updatingCompletion(assignmentID: request.assignmentID, status: request.status))
            pendingCompletion = nil
            pendingCompletionRecord = nil
            completionState = .ready
        } catch let failure as TodayCompletionFailure {
            completionState = .failed(request.assignmentID, failure)
        } catch {
            completionState = .failed(request.assignmentID, .progressLoadFailed)
        }
    }

    private func completionSnapshot(_ repository: any ProgrammeProgressRepository,
                                    request: TodayCompletionRequest) async throws -> ProgrammeProgressSnapshot {
        let snapshot: ProgrammeProgressSnapshot?
        do { snapshot = try await repository.loadProgress(programmeID: request.programme.programmeID) }
        catch { throw TodayCompletionFailure.progressLoadFailed }
        guard let snapshot, let active = snapshot.activeProgress,
              active.programme == request.programme,
              active.currentWeekID == request.weekID, active.currentDayID == request.dayID,
              let programme = programmeSeed?.programme, programme.id == request.programme.programmeID,
              programme.version == request.programme.programmeVersion,
              let week = programme.weeks.first(where: { $0.id == request.weekID }),
              let day = week.days.first(where: { $0.id == request.dayID }),
              day.blocks.flatMap(\.assignments).contains(where: {
                  $0.id == request.assignmentID && $0.sourceID == request.sourceID
              }) else { throw TodayCompletionFailure.positionChanged }
        return snapshot
    }

    private func loadState() async {
        state = .loading

        guard let programmeSeed else {
            state = .noProgrammeAvailable(.programmeDefinitionUnavailable)
            return
        }

        guard let progressRepository, let practiceHistoryRepository else {
            state = .failure(.persistenceUnavailable)
            return
        }

        let programme = programmeSeed.programme
        let programmeSummary = TodayProgrammeSummary(
            programmeID: programme.id,
            programmeVersion: programme.version,
            title: programme.title
        )

        let snapshot: ProgrammeProgressSnapshot?
        do {
            snapshot = try await progressRepository.loadProgress(programmeID: programme.id)
        } catch {
            state = .failure(.progressLoadFailed)
            return
        }

        guard let activeProgress = snapshot?.activeProgress else {
            state = .programmeNotStarted(programmeSummary)
            return
        }

        guard
            let weekID = activeProgress.currentWeekID,
            let dayID = activeProgress.currentDayID,
            let week = programme.weeks.first(where: { $0.id == weekID }),
            let day = week.days.first(where: { $0.id == dayID })
        else {
            state = .failure(
                .invalidPersistedPosition(
                    TodayInvalidPosition(
                        weekID: activeProgress.currentWeekID,
                        dayID: activeProgress.currentDayID
                    )
                )
            )
            return
        }

        let masteryDecisions: [MasteryDecisionRecord]
        do {
            masteryDecisions = try await practiceHistoryRepository.latestMasteryDecisions(programmeID: programme.id)
        } catch {
            state = .failure(.masteryLoadFailed)
            return
        }

        let temporalContext = PracticeTemporalContext(clock: clock, localContextProvider: localContextProvider)
        let completions = Dictionary(
            uniqueKeysWithValues: (snapshot?.assignmentCompletions ?? []).map { ($0.assignmentID, $0) }
        )
        let masteryByAssignmentSource = Dictionary(
            uniqueKeysWithValues: masteryDecisions.map {
                (assignmentSourceKey(assignmentID: $0.assignmentID, sourceID: $0.sourceID), $0.resultingState)
            }
        )

        state = .loaded(
            TodayLoadedState(
                programme: programmeSummary,
                weekID: week.id,
                weekTitle: week.title,
                dayID: day.id,
                dayTitle: "Day \(day.dayNumber)",
                dayKind: day.kind,
                suggestedSessionSlot: temporalContext.suggestedSessionSlot,
                localDayKey: temporalContext.localDay.dayKey,
                morningBlocks: blockStates(
                    day.blocks.filter { $0.sessionSlot == .morning },
                    sourceCatalogue: programmeSeed.sourceCatalogue,
                    completions: completions,
                    masteryByAssignmentSource: masteryByAssignmentSource,
                    suggestedSessionSlot: temporalContext.suggestedSessionSlot
                ),
                eveningBlocks: blockStates(
                    day.blocks.filter { $0.sessionSlot == .evening },
                    sourceCatalogue: programmeSeed.sourceCatalogue,
                    completions: completions,
                    masteryByAssignmentSource: masteryByAssignmentSource,
                    suggestedSessionSlot: temporalContext.suggestedSessionSlot
                ),
                recoveryBlocks: blockStates(
                    day.blocks.filter { $0.sessionSlot == .recovery },
                    sourceCatalogue: programmeSeed.sourceCatalogue,
                    completions: completions,
                    masteryByAssignmentSource: masteryByAssignmentSource,
                    suggestedSessionSlot: temporalContext.suggestedSessionSlot
                )
            )
        )
    }

    private func blockStates(
        _ blocks: [PracticeBlock],
        sourceCatalogue: ExerciseSourceCatalogue,
        completions: [PracticeAssignmentID: AssignmentCompletionState],
        masteryByAssignmentSource: [String: MasteryState],
        suggestedSessionSlot: PracticeSessionSlot?
    ) -> [TodayPracticeBlockState] {
        blocks.map { block in
            TodayPracticeBlockState(
                id: block.id,
                title: block.title,
                category: block.category,
                sessionSlot: block.sessionSlot,
                targetDurationMinutes: block.targetDurationMinutes,
                isSuggested: block.sessionSlot == suggestedSessionSlot,
                assignments: block.assignments.map { assignment in
                    assignmentState(
                        assignment,
                        sourceCatalogue: sourceCatalogue,
                        completion: completions[assignment.id],
                        masteryState: masteryByAssignmentSource[
                            assignmentSourceKey(assignmentID: assignment.id, sourceID: assignment.sourceID)
                        ]
                    )
                }
            )
        }
    }

    private func assignmentState(
        _ assignment: PracticeAssignment,
        sourceCatalogue: ExerciseSourceCatalogue,
        completion: AssignmentCompletionState?,
        masteryState: MasteryState?
    ) -> TodayAssignmentState {
        let source = sourceCatalogue.source(withID: assignment.sourceID)
        return TodayAssignmentState(
            id: assignment.id,
            title: assignment.title,
            goal: assignment.goal,
            sourceID: assignment.sourceID,
            sourceTitle: source?.displayTitle ?? "Unknown source",
            completionStatus: completion?.status ?? .notStarted,
            masteryState: masteryState,
            referenceMaterial: referenceMaterialState(for: assignment.sourceID)
        )
    }

    private func assignmentSourceKey(
        assignmentID: PracticeAssignmentID,
        sourceID: ExerciseSourceID
    ) -> String {
        "\(assignmentID.rawValue)|\(sourceID.rawValue)"
    }

    private func referenceMaterialState(for sourceID: ExerciseSourceID) -> TodayReferenceMaterialState {
        let resolution = referenceMaterialResolver.resolve(sourceID: sourceID)
        guard let material = resolution.material else {
            return .unknownSource
        }

        let summary = TodayReferenceMaterialSummary(
            id: material.id,
            title: material.title,
            components: material.components.map(componentPolicy.componentState)
        )

        switch resolution.availability {
        case .available:
            return .available(summary)
        case .unavailable(let reason):
            return .knownUnavailable(summary, reason)
        case nil:
            return .unknownSource
        }
    }
}

private extension PracticeProgramme {
    var version: Int {
        1
    }
}
