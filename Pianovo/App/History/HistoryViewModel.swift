import Combine
import Foundation

nonisolated struct HistoryEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let timestamp: PracticeTimestamp
    let noteContext: LearnerNoteContext?
    var recordedTime: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timestamp.localDay.timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        return formatter.string(from: timestamp.instant)
    }
}
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var issues: [String] = []
    @Published private(set) var loading = false
    @Published private(set) var currentDayContext: LearnerNoteContext?
    private var legacyEntries: [HistoryEntry] = []
    private var learnerEntries: [HistoryEntry] = []
    private var noteEntries: [HistoryEntry] = []
    let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }
    func load() async {
        guard !loading else { return }
        loading = true; issues = []; currentDayContext = nil; defer { loading = false }
        let seed = PianovoProgrammeSeedData.twelveWeekProgramme()
        if let repository = dependencies.practiceHistoryRepository {
            do { legacyEntries = try await repository.chronologicalHistory().map { Self.entry($0, seed: seed) } }
            catch { issues.append("Saved sessions and original reflections could not be loaded. Previously read records are kept.") }
        } else { issues.append("Original practice history is unavailable.") }
        if let repository = dependencies.learnerProgrammeRepository {
            do {
                let snapshot = try await repository.snapshot()
                var values: [HistoryEntry] = []
                for plan in snapshot.plans {
                    let revisions = try await repository.revisions(for: plan.id)
                    for record in plan.completions {
                        guard let revision = revisions.first(where: { $0.id == record.revisionID }),
                              let context = LearnerNoteContext.day(plan: plan, revision: revision, dayID: record.dayID, assignmentID: record.assignmentID),
                              let exercise = revision.exercise(record.exercise) else { throw LearnerProgrammeError.corruptStore }
                        values.append(HistoryEntry(id: "learner-completion-\(record.id)", title: record.completed ? "Reported complete" : "Completion undone",
                            detail: "\(exercise.content.title)\n\(context.title)\nLearner report, not a mastery assessment.", timestamp: record.timestamp, noteContext: context))
                    }
                }
                learnerEntries = values
                if let plan = snapshot.selectedPlan {
                    currentDayContext = LearnerNoteContext.day(plan: plan, revision: plan.revision, dayID: plan.currentDayID)
                } else if let progress = dependencies.progressRepository {
                    let saved = try await progress.loadProgress(programmeID: seed.programme.id)
                    if let active = saved?.activeProgress, active.programme.programmeVersion == 1,
                       let week = seed.programme.weeks.first(where: { $0.id == active.currentWeekID }),
                       let day = week.days.first(where: { $0.id == active.currentDayID }) {
                        currentDayContext = .originalDay(active.programme, week.id, day.id, "\(seed.programme.title) · Week \(week.number), Day \(day.dayNumber)")
                    }
                }
            } catch { issues.append("Learner programme history or the current day could not be loaded. Previously read records are kept.") }
        } else { issues.append("Learner programme history is unavailable.") }
        if let repository = dependencies.privateNoteRepository {
            do {
                noteEntries = try await repository.notes().map { note in
                    HistoryEntry(id: "private-note-\(note.id)", title: "Private learner note", detail: "\(note.context.title)\n\(note.text)", timestamp: note.createdAt, noteContext: note.context)
                }
            } catch { issues.append("Private notes could not be loaded. Previously read notes are kept.") }
        } else { issues.append("Private notes are unavailable.") }
        entries = (legacyEntries + learnerEntries + noteEntries).sorted {
            $0.timestamp.instant == $1.timestamp.instant ? $0.id < $1.id : $0.timestamp.instant > $1.timestamp.instant
        }
    }
    private static func entry(_ event: PracticeHistoryEvent, seed: ProgrammeSeed) -> HistoryEntry {
        switch event {
        case .session(let session):
            let title = session.context.sourceID.flatMap { seed.sourceCatalogue.source(withID: $0)?.displayTitle } ?? "Saved practice session"
            let duration = session.duration.map { $0 >= 0 ? String(format: "Recorded duration: %.1f minutes", $0 / 60) : "Duration unavailable" } ?? "No end time recorded"
            return HistoryEntry(id: "session-\(session.id.rawValue)", title: title,
                detail: "Outcome: \(session.outcome.rawValue)\n\(duration)\nAccuracy, tempo and numeric session statistics were not saved.", timestamp: session.startedAt, noteContext: .session(session, title))
        case .reflection(let reflection):
            return HistoryEntry(id: "reflection-\(reflection.id.rawValue)", title: "Saved learner reflection", detail: reflection.note,
                timestamp: reflection.createdAt, noteContext: nil)
        case .attempt(let attempt):
            return HistoryEntry(id: "attempt-\(attempt.id.rawValue)", title: "Recorded attempt", detail: "Outcome: \(attempt.outcome.rawValue). No numeric assessment is stored in this record.", timestamp: attempt.occurredAt, noteContext: nil)
        case .masteryDecision(let decision):
            return HistoryEntry(id: "mastery-\(decision.id.rawValue)", title: "Stored mastery decision",
                detail: "\(String(describing: decision.resultingState)) · \(decision.decisionSource.rawValue)\n\(decision.reason ?? "No reason recorded")\nA saved decision, not a new evaluation by History.", timestamp: decision.decidedAt, noteContext: nil)
        }
    }
}
@MainActor
final class PrivateNoteEditorViewModel: ObservableObject {
    @Published var text = ""
    @Published private(set) var saving = false
    @Published private(set) var error: String?
    private let context: LearnerNoteContext
    private let repository: (any PrivateLearnerNoteRepository)?
    private let clock: any PracticeClock
    private let localContext: any PracticeLocalContextProviding
    private var pending: PrivateLearnerNote?
    private var saved = false
    init(context: LearnerNoteContext, repository: (any PrivateLearnerNoteRepository)?, clock: any PracticeClock, localContext: any PracticeLocalContextProviding) {
        self.context = context; self.repository = repository; self.clock = clock; self.localContext = localContext
    }
    var canEdit: Bool { pending == nil && !saving && !saved }
    var hasChanges: Bool { pending != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func save() async -> Bool {
        guard !saving && !saved else { return false }
        guard let repository else { error = "Private notes are unavailable. Reopen Pianovo to try again."; return false }
        if pending == nil {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { error = "Write a note before saving."; return false }
            let temporal = PracticeTemporalContext(clock: clock, localContextProvider: localContext)
            pending = PrivateLearnerNote(id: UUID(), context: context, text: trimmed,
                createdAt: PracticeTimestamp(instant: temporal.now, localDay: temporal.localDay), audience: .privateLearner)
        }
        guard let pending else { return false }
        saving = true; error = nil; defer { saving = false }
        do { _ = try await repository.save(pending); saved = true; return true }
        catch { self.error = "The note could not be confirmed. Retry keeps the same text, context and time. Close and refresh History to check whether it was saved."; return false }
    }
}
