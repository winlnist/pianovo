import Combine
import Foundation

nonisolated enum ProgrammeTemplateFailure: Equatable {
    case invalid([LibraryProgrammeIssue]), missingReference, unavailable, conflict, storage
    var message: String {
        switch self {
        case .invalid(let issues): issues.map(\.message).joined(separator: " ")
        case .missingReference: "An exercise version could not be found. Refresh the Library before editing again."
        case .unavailable: "Saved programme templates are unavailable. Reopen Pianovo to try again."
        case .conflict: "This template changed or was archived. Close and refresh before editing again."
        case .storage: "The change could not be confirmed. Retry keeps the same request; close and refresh to check durable storage."
        }
    }
    static func from(_ error: Error) -> Self {
        if let error = error as? LibraryProgrammeError {
            switch error { case .invalid(let issues): return .invalid(issues); case .missingExerciseRevision: return .missingReference }
        }
        if let error = error as? LibraryRepositoryError, [.conflict, .archived, .notFound, .duplicateID].contains(error) { return .conflict }
        return .storage
    }
}
nonisolated enum ProgrammeTemplateActionState: Equatable { case ready, saving, saved, failed(ProgrammeTemplateFailure) }

@MainActor
final class ProgrammeTemplateViewModel: ObservableObject {
    @Published private(set) var templates: [LibraryProgrammeTemplate] = []
    @Published private(set) var exercises: [LibraryExercise] = []
    @Published private(set) var revisions: [LibraryExerciseReference: LibraryExerciseRevision] = [:]
    @Published private(set) var loadState: LibraryLoadState = .idle
    @Published private(set) var actionState: ProgrammeTemplateActionState = .ready
    let repository: (any LibraryProgrammeTemplateRepository)?
    let exerciseRepository: (any LibraryExerciseRepository)?
    let clock: any PracticeClock
    private var busy = false
    private var pendingArchive: LibraryProgrammeMutation?
    init(repository: (any LibraryProgrammeTemplateRepository)?, exerciseRepository: (any LibraryExerciseRepository)?, clock: any PracticeClock) {
        self.repository = repository; self.exerciseRepository = exerciseRepository; self.clock = clock
    }
    var allowsActions: Bool { loadState == .ready && actionState == .ready && !busy }
    func loadIfNeeded() async { if loadState == .idle { await load() } }
    func load() async {
        guard !busy else { return }
        guard let repository, let exerciseRepository else { loadState = .unavailable; return }
        busy = true; loadState = .loading; actionState = .ready; pendingArchive = nil
        defer { busy = false }
        do {
            let saved = try await repository.templates()
            let available = try await exerciseRepository.exercises()
            var resolved: [LibraryExerciseReference: LibraryExerciseRevision] = [:]
            for exercise in available {
                for revision in try await exerciseRepository.revisionHistory(for: exercise.id) {
                    resolved[LibraryExerciseReference(exerciseID: exercise.id, revisionID: revision.id)] = revision
                }
            }
            guard saved.allSatisfy({ $0.currentRevision.content.references.allSatisfy { resolved[$0] != nil } }) else {
                throw LibraryProgrammeError.missingExerciseRevision
            }
            templates = saved; exercises = available; revisions = resolved; loadState = .ready
        } catch { loadState = .failed }
    }
    func visibleTemplates(archived: Bool, search: String) -> [LibraryProgrammeTemplate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return templates.filter { $0.isArchived == archived && (query.isEmpty || $0.currentRevision.content.name.localizedCaseInsensitiveContains(query)) }
            .sorted { $0.currentRevision.content.name.localizedStandardCompare($1.currentRevision.content.name) == .orderedAscending }
    }
    func acceptSaved(_ value: LibraryProgrammeTemplate) { templates.removeAll { $0.id == value.id }; templates.append(value) }
    func setArchived(_ value: LibraryProgrammeTemplate, archived: Bool) async {
        guard allowsActions else { return }
        pendingArchive = .setArchived(value.id, expectedRevision: value.currentRevision.id, archived: archived)
        await saveArchive()
    }
    func retryArchive() async { if case .failed = actionState { await saveArchive() } }
    private func saveArchive() async {
        guard !busy, let pendingArchive, let repository else { return }
        busy = true; actionState = .saving; defer { busy = false }
        do { acceptSaved(try await repository.apply(pendingArchive)); self.pendingArchive = nil; actionState = .ready }
        catch { actionState = .failed(.from(error)) }
    }
}

@MainActor
final class ProgrammeTemplateEditorViewModel: ObservableObject {
    @Published var draft: LibraryProgrammeDraft
    @Published private(set) var saveState: ProgrammeTemplateActionState = .ready
    private let original: LibraryProgrammeTemplate?
    private let origin: LibraryProgrammeOrigin?
    private let initial: LibraryProgrammeDraft
    private let repository: (any LibraryProgrammeTemplateRepository)?
    private let clock: any PracticeClock
    private let makeUUID: () -> UUID
    private var pending: LibraryProgrammeMutation?
    init(template: LibraryProgrammeTemplate? = nil, copying: LibraryProgrammeTemplateRevision? = nil,
         starterWeeks: Int? = nil, repository: (any LibraryProgrammeTemplateRepository)?, clock: any PracticeClock,
         makeUUID: @escaping () -> UUID = UUID.init) {
        original = template; self.repository = repository; self.clock = clock; self.makeUUID = makeUUID
        if let template { initial = template.currentRevision.content; origin = template.currentRevision.origin }
        else if let copying {
            initial = copying.content.independentCopy(makeUUID: makeUUID)
            origin = LibraryProgrammeOrigin(templateID: copying.templateID, revisionID: copying.id, name: copying.content.name, creatorAttribution: copying.origin?.creatorAttribution)
        } else {
            initial = starterWeeks.map { LibraryProgrammeDraft.starter(weekCount: $0, makeUUID: makeUUID) } ??
                LibraryProgrammeDraft(weeks: [LibraryProgrammeWeek(id: makeUUID(), days: [LibraryProgrammeDay(id: makeUUID())])])
            origin = nil
        }
        draft = initial
    }
    var isEditing: Bool { original != nil }
    var canEdit: Bool { pending == nil && saveState != .saving && saveState != .saved }
    var hasChanges: Bool { pending != nil || draft != initial }
    func addWeek() {
        guard canEdit, draft.weeks.count < 104 else { return }
        draft.weeks.append(LibraryProgrammeWeek(id: makeUUID(), days: [LibraryProgrammeDay(id: makeUUID())]))
    }
    func addDay(weekID: UUID) {
        guard canEdit, let w = draft.weeks.firstIndex(where: { $0.id == weekID }), draft.weeks[w].days.count < 7 else { return }
        draft.weeks[w].days.append(LibraryProgrammeDay(id: makeUUID()))
    }
    func addSection(weekID: UUID, dayID: UUID) {
        guard canEdit, let w = draft.weeks.firstIndex(where: { $0.id == weekID }),
              let d = draft.weeks[w].days.firstIndex(where: { $0.id == dayID }), draft.weeks[w].days[d].sections.count < 8 else { return }
        draft.weeks[w].days[d].sections.append(LibraryProgrammeSection(id: makeUUID(), name: "Practice"))
    }
    func addExercise(_ exercise: LibraryExercise, weekID: UUID, dayID: UUID, sectionID: UUID) {
        guard canEdit, !exercise.isArchived, let w = draft.weeks.firstIndex(where: { $0.id == weekID }),
              let d = draft.weeks[w].days.firstIndex(where: { $0.id == dayID }),
              let s = draft.weeks[w].days[d].sections.firstIndex(where: { $0.id == sectionID }),
              draft.weeks[w].days[d].sections[s].placements.count < 100 else { return }
        draft.weeks[w].days[d].sections[s].placements.append(LibraryProgrammePlacement(id: makeUUID(),
            exercise: LibraryExerciseReference(exerciseID: exercise.id, revisionID: exercise.currentRevision.id),
            goal: exercise.currentRevision.content.learningPurpose, minutes: 10))
    }
    func save() async -> LibraryProgrammeTemplate? {
        guard saveState != .saving && saveState != .saved else { return nil }
        guard let repository else { saveState = .failed(.unavailable); return nil }
        if pending == nil {
            let content = draft.normalised
            guard content.validationIssues.isEmpty else { saveState = .failed(.invalid(content.validationIssues)); return nil }
            let revision = LibraryProgrammeTemplateRevision(id: LibraryProgrammeRevisionID(rawValue: makeUUID()),
                templateID: original?.id ?? LibraryProgrammeTemplateID(rawValue: makeUUID()), parentRevisionID: original?.currentRevision.id,
                content: content, createdAt: clock.now, origin: origin)
            pending = original.map { .revise(revision, replacing: $0.currentRevision.id) } ?? .create(revision)
        }
        guard let pending else { return nil }
        saveState = .saving
        do { let result = try await repository.apply(pending); saveState = .saved; return result }
        catch { saveState = .failed(.from(error)); return nil }
    }
}
