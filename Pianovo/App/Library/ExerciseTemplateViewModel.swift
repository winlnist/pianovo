import Combine
import Foundation

@MainActor
final class ExerciseTemplateViewModel: ObservableObject {
    @Published private(set) var templates: [LibraryExerciseTemplate] = []
    @Published private(set) var loadState: LibraryLoadState = .idle
    @Published private(set) var actionState: LibraryActionState = .ready
    let repository: (any LibraryExerciseTemplateRepository)?
    let clock: any PracticeClock
    private var isPerformingOperation = false
    private var pendingArchive: LibraryTemplateMutation?

    init(repository: (any LibraryExerciseTemplateRepository)?, clock: any PracticeClock = SystemPracticeClock()) {
        self.repository = repository
        self.clock = clock
    }
    var allowsActions: Bool { loadState == .ready && actionState == .ready && !isPerformingOperation }
    func loadIfNeeded() async { if loadState == .idle { await load() } }
    func load() async {
        guard !isPerformingOperation else { return }
        guard let repository else { loadState = .unavailable; return }
        isPerformingOperation = true
        loadState = .loading
        actionState = .ready
        pendingArchive = nil
        defer { isPerformingOperation = false }
        do { templates = try await repository.templates(); loadState = .ready }
        catch { loadState = .failed }
    }
    func acceptSaved(_ template: LibraryExerciseTemplate) {
        templates.removeAll { $0.id == template.id }
        templates.append(template)
    }
    func visibleTemplates(archived: Bool, search: String) -> [LibraryExerciseTemplate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return templates.filter {
            $0.isArchived == archived && (query.isEmpty || $0.currentRevision.content.name.localizedCaseInsensitiveContains(query))
        }.sorted {
            let order = $0.currentRevision.content.name.localizedStandardCompare($1.currentRevision.content.name)
            return order == .orderedSame ? $0.id.rawValue.uuidString < $1.id.rawValue.uuidString : order == .orderedAscending
        }
    }
    func setArchived(_ template: LibraryExerciseTemplate, archived: Bool) async {
        guard allowsActions else { return }
        pendingArchive = .setArchived(template.id, expectedRevision: template.currentRevision.id, archived: archived)
        await saveArchive()
    }
    func retryArchive() async { if case .failed = actionState { await saveArchive() } }
    private func saveArchive() async {
        guard !isPerformingOperation, let pendingArchive, let repository else { return }
        isPerformingOperation = true
        actionState = .saving
        defer { isPerformingOperation = false }
        do {
            acceptSaved(try await repository.apply(pendingArchive))
            self.pendingArchive = nil
            actionState = .ready
        } catch { actionState = .failed(LibraryViewModel.failure(error)) }
    }
}

@MainActor
final class ExerciseTemplateEditorViewModel: ObservableObject {
    @Published var draft: LibraryTemplateDraft
    @Published private(set) var saveState: LibraryActionState = .ready
    private let original: LibraryExerciseTemplate?
    private let starter: LibraryStarterPattern?
    private let initialDraft: LibraryTemplateDraft
    private let repository: (any LibraryExerciseTemplateRepository)?
    private let clock: any PracticeClock
    private let makeUUID: () -> UUID
    private var pending: LibraryTemplateMutation?

    init(template: LibraryExerciseTemplate? = nil, starter: LibraryStarterPattern? = nil,
         repository: (any LibraryExerciseTemplateRepository)?, clock: any PracticeClock = SystemPracticeClock(),
         makeUUID: @escaping () -> UUID = UUID.init) {
        original = template
        self.starter = template?.currentRevision.starterPattern ?? starter
        initialDraft = template?.currentRevision.content ?? starter?.draft ?? LibraryTemplateDraft()
        draft = initialDraft
        self.repository = repository
        self.clock = clock
        self.makeUUID = makeUUID
    }
    var isEditing: Bool { original != nil }
    var canEdit: Bool { pending == nil && saveState != .saving && saveState != .saved }
    var hasChanges: Bool { pending != nil || draft != initialDraft }
    var usesStarter: Bool { starter != nil }
    func save() async -> LibraryExerciseTemplate? {
        guard saveState != .saving && saveState != .saved else { return nil }
        guard let repository else { saveState = .failed(.unavailable); return nil }
        if pending == nil {
            let content = draft.normalised
            guard content.validationIssues.isEmpty else { saveState = .failed(.invalid(content.validationIssues)); return nil }
            let revision = LibraryExerciseTemplateRevision(id: LibraryTemplateRevisionID(rawValue: makeUUID()),
                templateID: original?.id ?? LibraryTemplateID(rawValue: makeUUID()), parentRevisionID: original?.currentRevision.id,
                content: content, createdAt: clock.now, starterPattern: starter)
            if let original { pending = .revise(revision, replacing: original.currentRevision.id) }
            else { pending = .create(revision) }
        }
        guard let pending else { return nil }
        saveState = .saving
        do {
            let result = try await repository.apply(pending)
            saveState = .saved
            return result
        } catch { saveState = .failed(LibraryViewModel.failure(error)); return nil }
    }
}
