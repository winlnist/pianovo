import Combine
import Foundation

nonisolated enum LearnerProgrammeActionState: Equatable { case ready, saving, failed(String) }
@MainActor
final class LearnerProgrammeViewModel: ObservableObject {
    @Published private(set) var acknowledgedCreatedPlanID: LearnerPlanID?
    @Published private(set) var snapshot = LearnerProgrammeSnapshot()
    @Published private(set) var loadState: LibraryLoadState = .idle
    @Published private(set) var actionState: LearnerProgrammeActionState = .ready
    let repository: (any LearnerProgrammeRepository)?
    let clock: any PracticeClock
    let localContext: any PracticeLocalContextProviding
    private var busy = false
    private var pending: LearnerProgrammeRequest?
    private var creatingID: LearnerPlanID?
    init(repository: (any LearnerProgrammeRepository)?, clock: any PracticeClock, localContext: any PracticeLocalContextProviding) {
        self.repository = repository; self.clock = clock; self.localContext = localContext
    }
    var allowsActions: Bool { loadState == .ready && actionState == .ready && !busy }
    var canRetry: Bool { pending != nil && !busy }
    var selectedPlan: LearnerPlan? { snapshot.selectedPlan }
    func load() async {
        guard !busy else { return }
        guard let repository else { loadState = .unavailable; return }
        busy = true; loadState = .loading; pending = nil; creatingID = nil; actionState = .ready; defer { busy = false }
        do { snapshot = try await repository.snapshot(); loadState = .ready }
        catch { loadState = .failed }
    }
    func select(_ id: LearnerPlanID?) async {
        guard allowsActions else { return }
        pending = LearnerProgrammeRequest(id: UUID(), expectedSelection: snapshot.selection.version, command: .select(id))
        await save()
    }
    func create(from template: LibraryProgrammeTemplateRevision, name: String) async -> Bool {
        guard loadState == .ready, !busy, pending == nil else { return false }
        var draft = template.content.independentCopy()
        draft.name = name
        guard draft.validationIssues.isEmpty else { actionState = .failed(LearnerProgrammeError.invalid(draft.validationIssues).message); return false }
        let temporal = PracticeTemporalContext(clock: clock, localContextProvider: localContext)
        let origin = LibraryProgrammeOrigin(templateID: template.templateID, revisionID: template.id, name: template.content.name,
            creatorAttribution: template.origin?.creatorAttribution)
        let planID = LearnerPlanID(rawValue: UUID())
        creatingID = planID
        pending = LearnerProgrammeRequest(id: UUID(), expectedSelection: snapshot.selection.version,
            command: .create(planID, LearnerPlanRevisionID(rawValue: UUID()), draft, origin,
                PracticeTimestamp(instant: temporal.now, localDay: temporal.localDay)))
        await save()
        return acknowledgedCreatedPlanID == planID
    }
    func complete(_ assignment: UUID, completed: Bool) async {
        guard allowsActions, let plan = selectedPlan else { return }
        let temporal = PracticeTemporalContext(clock: clock, localContextProvider: localContext)
        pending = LearnerProgrammeRequest(id: UUID(), expectedSelection: snapshot.selection.version,
            command: .complete(plan.id, plan.version, plan.currentDayID, assignment, completed, PracticeTimestamp(instant: temporal.now, localDay: temporal.localDay)))
        await save()
    }
    func navigationRequest(_ direction: Int, confirmedUnfinished: Bool = false) -> LearnerProgrammeRequest? {
        guard allowsActions, let plan = selectedPlan else { return nil }
        return LearnerProgrammeRequest(id: UUID(), expectedSelection: snapshot.selection.version,
            command: .move(plan.id, plan.version, plan.currentDayID, direction, confirmedUnfinished))
    }
    func move(_ direction: Int, confirmedUnfinished: Bool = false) async {
        guard let request = navigationRequest(direction, confirmedUnfinished: confirmedUnfinished) else { return }
        await performNavigation(request)
    }
    func performNavigation(_ request: LearnerProgrammeRequest) async {
        guard allowsActions, case .move = request.command else { return }
        pending = request
        await save()
    }
    func retry() async { guard canRetry else { return }; await save() }
    private func save() async {
        guard !busy, let pending, let repository else { return }
        busy = true; actionState = .saving; defer { busy = false }
        do {
            snapshot = try await repository.apply(pending)
            if let creatingID, snapshot.plans.contains(where: { $0.id == creatingID }) { acknowledgedCreatedPlanID = creatingID }
            self.creatingID = nil; self.pending = nil; actionState = .ready
        }
        catch let error as LearnerProgrammeError { actionState = .failed(error.message) }
        catch { actionState = .failed("The change could not be confirmed. Retry keeps the same request; refresh to check durable storage.") }
    }
}

@MainActor
protocol ProgrammeDraftEditing: ObservableObject {
    var draft: LibraryProgrammeDraft { get set }
    var canEdit: Bool { get }
    func addWeek()
    func addDay(weekID: UUID)
    func addSection(weekID: UUID, dayID: UUID)
    func addExercise(_ exercise: LibraryExercise, weekID: UUID, dayID: UUID, sectionID: UUID)
}
extension ProgrammeTemplateEditorViewModel: ProgrammeDraftEditing {}

@MainActor
final class LearnerPlanEditorViewModel: ProgrammeDraftEditing {
    @Published var draft: LibraryProgrammeDraft
    @Published private(set) var actionState: LearnerProgrammeActionState = .ready
    private let original: LearnerPlan
    private let repository: any LearnerProgrammeRepository
    private let clock: any PracticeClock
    private let localContext: any PracticeLocalContextProviding
    private var pending: LearnerProgrammeRequest?
    init(plan: LearnerPlan, repository: any LearnerProgrammeRepository, clock: any PracticeClock, localContext: any PracticeLocalContextProviding) {
        original = plan; draft = plan.revision.content; self.repository = repository; self.clock = clock; self.localContext = localContext
    }
    var canEdit: Bool { pending == nil && actionState != .saving }
    var hasChanges: Bool { pending != nil || draft != original.revision.content }
    func addWeek() {
        guard canEdit, draft.weeks.count < 104 else { return }
        draft.weeks.append(LibraryProgrammeWeek(id: UUID(), days: [LibraryProgrammeDay(id: UUID())]))
    }
    func addDay(weekID: UUID) {
        guard canEdit, let w = draft.weeks.firstIndex(where: { $0.id == weekID }), draft.weeks[w].days.count < 7 else { return }
        draft.weeks[w].days.append(LibraryProgrammeDay(id: UUID()))
    }
    func addSection(weekID: UUID, dayID: UUID) {
        guard canEdit, let w = draft.weeks.firstIndex(where: { $0.id == weekID }),
              let d = draft.weeks[w].days.firstIndex(where: { $0.id == dayID }), draft.weeks[w].days[d].sections.count < 8 else { return }
        draft.weeks[w].days[d].sections.append(LibraryProgrammeSection(id: UUID(), name: "Practice"))
    }
    func addExercise(_ exercise: LibraryExercise, weekID: UUID, dayID: UUID, sectionID: UUID) {
        guard canEdit, !exercise.isArchived, let w = draft.weeks.firstIndex(where: { $0.id == weekID }),
              let d = draft.weeks[w].days.firstIndex(where: { $0.id == dayID }),
              let s = draft.weeks[w].days[d].sections.firstIndex(where: { $0.id == sectionID }), draft.weeks[w].days[d].sections[s].placements.count < 100 else { return }
        draft.weeks[w].days[d].sections[s].placements.append(LibraryProgrammePlacement(id: UUID(), exercise:
            LibraryExerciseReference(exerciseID: exercise.id, revisionID: exercise.currentRevision.id), goal: exercise.currentRevision.content.learningPurpose, minutes: 10))
    }
    func save() async -> Bool {
        guard actionState != .saving else { return false }
        if pending == nil {
            let content = draft.normalised
            guard content.validationIssues.isEmpty else { actionState = .failed(LearnerProgrammeError.invalid(content.validationIssues).message); return false }
            guard content.weeks.flatMap(\.days).contains(where: { $0.id == original.currentDayID }) else {
                actionState = .failed(LearnerProgrammeError.currentDayRemoved.message); return false
            }
            let replacements = Dictionary(uniqueKeysWithValues: original.revision.content.weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).map { ($0.id, UUID()) })
            let temporal = PracticeTemporalContext(clock: clock, localContextProvider: localContext)
            pending = LearnerProgrammeRequest(id: UUID(), expectedSelection: nil, command: .edit(original.id, original.version,
                LearnerPlanRevisionID(rawValue: UUID()), content, replacements, PracticeTimestamp(instant: temporal.now, localDay: temporal.localDay)))
        }
        guard let pending else { return false }
        actionState = .saving
        do { _ = try await repository.apply(pending); actionState = .ready; return true }
        catch let error as LearnerProgrammeError { actionState = .failed(error.message); return false }
        catch { actionState = .failed("The edit could not be confirmed. Retry or close and refresh to check."); return false }
    }
}
