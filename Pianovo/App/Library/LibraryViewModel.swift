import Combine
import Foundation

nonisolated enum LibraryLoadState: Equatable { case idle, loading, ready, unavailable, failed }
nonisolated enum LibraryActionState: Equatable { case ready, saving, saved, failed(LibraryActionFailure) }
nonisolated enum LibraryActionFailure: Equatable {
    case unavailable, storage, conflict, invalid([LibraryValidationIssue])
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var exercises: [LibraryExercise] = []
    @Published private(set) var loadState: LibraryLoadState = .idle
    @Published private(set) var archiveState: LibraryActionState = .ready
    private var pendingArchive: LibraryMutation?
    private var isPerformingOperation = false
    let repository: (any LibraryExerciseRepository)?
    let clock: any PracticeClock

    init(repository: (any LibraryExerciseRepository)?, clock: any PracticeClock = SystemPracticeClock()) {
        self.repository = repository
        self.clock = clock
    }

    var allowsActions: Bool { loadState == .ready && archiveState == .ready && !isPerformingOperation }

    func loadIfNeeded() async { if loadState == .idle { await load() } }

    func load() async {
        guard !isPerformingOperation else { return }
        guard let repository else { loadState = .unavailable; return }
        isPerformingOperation = true
        loadState = .loading
        archiveState = .ready
        pendingArchive = nil
        defer { isPerformingOperation = false }
        do {
            exercises = try await repository.exercises()
            loadState = .ready
        } catch { loadState = .failed }
    }

    func setArchived(_ exercise: LibraryExercise, archived: Bool) async {
        guard allowsActions else { return }
        pendingArchive = .setArchived(exercise.id, expectedRevision: exercise.currentRevision.id, archived: archived)
        await saveArchive()
    }

    func retryArchive() async { if case .failed = archiveState { await saveArchive() } }

    private func saveArchive() async {
        guard !isPerformingOperation, let pendingArchive, let repository else { return }
        isPerformingOperation = true
        archiveState = .saving
        defer { isPerformingOperation = false }
        do {
            let result = try await repository.apply(pendingArchive)
            acceptSaved(result)
            self.pendingArchive = nil
            archiveState = .ready
        } catch { archiveState = .failed(Self.failure(error)) }
    }

    func acceptSaved(_ result: LibraryExercise) {
        exercises.removeAll { $0.id == result.id }
        exercises.append(result)
    }

    func visibleExercises(archived: Bool, search: String) -> [LibraryExercise] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter {
            $0.isArchived == archived && (query.isEmpty || $0.currentRevision.content.title.localizedCaseInsensitiveContains(query))
        }.sorted {
            let comparison = $0.currentRevision.content.title.localizedStandardCompare($1.currentRevision.content.title)
            return comparison == .orderedSame ? $0.id.rawValue.uuidString < $1.id.rawValue.uuidString : comparison == .orderedAscending
        }
    }

    static func failure(_ error: Error) -> LibraryActionFailure {
        switch error {
        case LibraryRepositoryError.invalid(let issues): .invalid(issues)
        case LibraryRepositoryError.conflict, LibraryRepositoryError.duplicateID,
             LibraryRepositoryError.archived, LibraryRepositoryError.notFound: .conflict
        default: .storage
        }
    }
}

@MainActor
final class LibraryEditorViewModel: ObservableObject {
    @Published var draft: LibraryExerciseDraft
    @Published private(set) var saveState: LibraryActionState = .ready
    private let original: LibraryExercise?
    private let repository: (any LibraryExerciseRepository)?
    private let clock: any PracticeClock
    private let makeUUID: () -> UUID
    private var pending: LibraryMutation?

    init(exercise: LibraryExercise? = nil, repository: (any LibraryExerciseRepository)?,
         clock: any PracticeClock = SystemPracticeClock(), makeUUID: @escaping () -> UUID = UUID.init) {
        original = exercise
        draft = exercise?.currentRevision.content ?? LibraryExerciseDraft()
        self.repository = repository
        self.clock = clock
        self.makeUUID = makeUUID
    }

    var isEditing: Bool { original != nil }
    var canEdit: Bool { pending == nil && saveState != .saving && saveState != .saved }
    var hasChanges: Bool { draft != (original?.currentRevision.content ?? LibraryExerciseDraft()) }

    func save() async -> LibraryExercise? {
        guard saveState != .saving && saveState != .saved else { return nil }
        guard let repository else { saveState = .failed(.unavailable); return nil }
        if pending == nil {
            let content = draft.normalised
            guard content.validationIssues.isEmpty else {
                saveState = .failed(.invalid(content.validationIssues))
                return nil
            }
            let revision = LibraryExerciseRevision(
                id: LibraryRevisionID(rawValue: makeUUID()),
                exerciseID: original?.id ?? LibraryExerciseID(rawValue: makeUUID()),
                parentRevisionID: original?.currentRevision.id,
                content: content, createdAt: clock.now, origin: original?.currentRevision.origin
            )
            if let original { pending = .revise(revision, replacing: original.currentRevision.id) }
            else { pending = .create(revision) }
        }
        guard let pending else { return nil }
        saveState = .saving // Gate before the repository suspension; retries reuse the frozen request.
        do {
            let result = try await repository.apply(pending)
            saveState = .saved
            return result
        } catch {
            saveState = .failed(LibraryViewModel.failure(error))
            return nil
        }
    }
}
