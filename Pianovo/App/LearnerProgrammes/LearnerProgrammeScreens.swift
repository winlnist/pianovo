import SwiftUI

struct TodayProgrammeScreen: View {
    let dependencies: AppDependencies
    let onPractise: (AssignmentPracticeContext) -> Void
    @StateObject private var model: LearnerProgrammeViewModel
    @State private var showsProgrammes = false
    @State private var showsEditor = false
    @State private var confirmsNext = false
    @State private var nextRequest: LearnerProgrammeRequest?
    @State private var confirmsCompletion: LibraryProgrammePlacement?
    @State private var viewsOriginalWithoutSelection = false
    @Environment(\.scenePhase) private var scenePhase
    init(dependencies: AppDependencies, onPractise: @escaping (AssignmentPracticeContext) -> Void) {
        self.dependencies = dependencies; self.onPractise = onPractise
        _model = StateObject(wrappedValue: LearnerProgrammeViewModel(repository: dependencies.learnerProgrammeRepository,
            clock: dependencies.clock, localContext: dependencies.localContextProvider))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.selectedPlan?.revision.content.name ?? "Original twelve-week programme").font(.headline).lineLimit(2)
                Spacer()
                Button("Programmes", systemImage: "list.bullet") { showsProgrammes = true }.disabled(!model.allowsActions)
                Button("Refresh", systemImage: "arrow.clockwise") { Task { viewsOriginalWithoutSelection = false; await model.load() } }.disabled(model.actionState == .saving)
            }.padding()
            LearnerProgrammeFeedback(model: model)
            if model.loadState == .ready {
                if let plan = model.selectedPlan { planDay(plan) }
                else { TodayScreen(dependencies: dependencies, onPractise: onPractise).id(model.snapshot.selection.version) }
            } else if viewsOriginalWithoutSelection {
                Text("Viewing the original programme. The saved selection could not be read and has not been changed.").font(.caption).padding()
                TodayScreen(dependencies: dependencies, onPractise: onPractise)
            } else if model.loadState == .loading || model.loadState == .idle {
                ProgressView("Loading your programme selection…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Programme selection unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Your saved programme has not been reset. Retry loading, or view the original programme while leaving the saved selection untouched.")
                } actions: {
                    Button("Retry loading") { Task { await model.load() } }
                    Button("View original programme") { viewsOriginalWithoutSelection = true }
                }
            }
        }
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active && model.actionState == .ready { Task { await model.load() } } }
        .sheet(isPresented: $showsProgrammes) { programmeChooser }
        .sheet(isPresented: $showsEditor, onDismiss: { Task { await model.load() } }) {
            if let plan = model.selectedPlan, let repository = dependencies.learnerProgrammeRepository {
                LearnerPlanEditorScreen(plan: plan, repository: repository, exercises: dependencies.libraryRepository,
                    clock: dependencies.clock, localContext: dependencies.localContextProvider)
            }
        }
        .confirmationDialog(nextConfirmationTitle, isPresented: $confirmsNext, titleVisibility: .visible) {
            Button(model.selectedPlan?.days.last?.id == model.selectedPlan?.currentDayID ? "Finish programme" : "Continue to next day") {
                if let nextRequest { Task { await model.performNavigation(nextRequest) } }
            }
            Button("Stay on this day", role: .cancel) {}
        } message: { Text("Unfinished work will keep its status. Continuing does not complete assignments or prove mastery.") }
        .sheet(item: $confirmsCompletion) { placement in
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.selectedPlan?.revision.exercise(placement.exercise)?.content.title ?? "Assignment").font(.title2.bold())
                    Text(model.selectedPlan?.isCompleted(placement.id) == true
                         ? "Undo your reported completion. This does not delete any saved records."
                         : "Confirm that you practised this assignment. Work outside Pianovo counts. This is your report, not a mastery assessment.")
                    Text("Your saved day stays the same.").foregroundStyle(.secondary)
                    Button(model.selectedPlan?.isCompleted(placement.id) == true ? "Undo completion" : "Confirm completion") {
                        let completed = model.selectedPlan?.isCompleted(placement.id) != true
                        confirmsCompletion = nil
                        Task { await model.complete(placement.id, completed: completed) }
                    }.buttonStyle(.borderedProminent)
                    Spacer()
                }.padding(24).navigationTitle("Assignment status").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { confirmsCompletion = nil } } }
            }
        }
    }
    private var nextConfirmationTitle: String { "\(model.selectedPlan?.unfinishedCount ?? 0) unfinished assignments" }
    private var programmeChooser: some View {
        NavigationStack {
            List {
                Section {
                    Text("Switching keeps each programme's position and records. Create a new learner programme from Library → Programme templates.").foregroundStyle(.secondary)
                    LearnerProgrammeFeedback(model: model)
                }
                Button {
                    Task { await model.select(nil); if model.actionState == .ready { showsProgrammes = false } }
                } label: { Label("Original twelve-week programme", systemImage: model.snapshot.selection.planID == nil ? "checkmark.circle.fill" : "circle") }
                .disabled(!model.allowsActions)
                ForEach(model.snapshot.plans) { plan in
                    Button {
                        Task { await model.select(plan.id); if model.actionState == .ready { showsProgrammes = false } }
                    } label: {
                        Label(plan.revision.content.name, systemImage: model.snapshot.selection.planID == plan.id ? "checkmark.circle.fill" : "circle")
                    }.disabled(!model.allowsActions)
                }
            }.navigationTitle("Your programmes")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showsProgrammes = false } } }
        }
    }
    private func planDay(_ plan: LearnerPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let week = plan.revision.content.weeks.first(where: { $0.days.contains { $0.id == plan.currentDayID } }),
                   let weekIndex = plan.revision.content.weeks.firstIndex(where: { $0.id == week.id }),
                   let dayIndex = week.days.firstIndex(where: { $0.id == plan.currentDayID }), let day = plan.currentDay {
                    Text("Week \(weekIndex + 1) · Day \(dayIndex + 1)").font(.title.bold())
                    if day.isRecovery { Label("Recovery / reflection", systemImage: "leaf") }
                    if plan.reachedEnd {
                        Label("End of programme reached", systemImage: "flag.checkered").font(.headline)
                        Text("Your records and unfinished work are kept. This is not an assessment of mastery. Review earlier days or switch programmes when ready.")
                    }
                    Button("Edit my programme") { showsEditor = true }.disabled(!model.allowsActions)
                    Text("From template: \(plan.revision.origin.name)").font(.caption).foregroundStyle(.secondary)
                    ForEach(day.sections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(section.name).font(.title2.bold())
                            ForEach(section.placements) { placement in
                                if let exercise = plan.revision.exercise(placement.exercise) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(exercise.content.title).font(.headline)
                                        Text(exercise.content.instructions)
                                        Text("Goal: \(placement.goal)")
                                        Label("\(placement.minutes) planned minutes", systemImage: "clock")
                                        Label(plan.isCompleted(placement.id) ? "Completed · your report" : "Not completed",
                                            systemImage: plan.isCompleted(placement.id) ? "checkmark.circle" : "circle")
                                        if exercise.content.referenceMaterialID != nil {
                                            Text("A reference material is linked. Opening documents is not available here yet.").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Text("Written practice guidance. In-app MIDI practice is not available for this authored exercise.").font(.caption).foregroundStyle(.secondary)
                                        Button(plan.isCompleted(placement.id) ? "Undo completion" : "Mark complete") { confirmsCompletion = placement }
                                            .buttonStyle(.bordered).disabled(!model.allowsActions)
                                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            if section.placements.isEmpty { Text("No work in this section.").foregroundStyle(.secondary) }
                        }
                    }
                    if day.sections.isEmpty { Text("No work scheduled for this day.").foregroundStyle(.secondary) }
                    HStack {
                        Button("Previous day") { Task { await model.move(-1) } }.disabled(!model.allowsActions || plan.currentDayIndex == 0)
                        Spacer()
                        Button(plan.days.last?.id == day.id ? "Finish programme" : "Next day") {
                            if plan.unfinishedCount > 0 { nextRequest = model.navigationRequest(1, confirmedUnfinished: true); confirmsNext = true }
                            else { Task { await model.move(1) } }
                        }.buttonStyle(.borderedProminent).disabled(!model.allowsActions || plan.reachedEnd)
                    }
                }
            }.padding(24).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(.systemGroupedBackground))
    }
}

struct LearnerProgrammeFeedback: View {
    @ObservedObject var model: LearnerProgrammeViewModel
    var body: some View {
        if model.actionState == .saving { ProgressView("Saving programme…").padding() }
        if case .failed(let message) = model.actionState {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                HStack {
                    if model.canRetry { Button("Retry save") { Task { await model.retry() } } }
                    Button("Refresh") { Task { await model.load() } }
                }
            }.padding()
        }
    }
}

struct LearnerPlanCreationScreen: View {
    private let onCreated: (() -> Void)?
    let template: LibraryProgrammeTemplateRevision
    @StateObject private var model: LearnerProgrammeViewModel
    @State private var name: String
    @Environment(\.dismiss) private var dismiss
    init(template: LibraryProgrammeTemplateRevision, repository: (any LearnerProgrammeRepository)?, clock: any PracticeClock,
         localContext: any PracticeLocalContextProviding, onCreated: (() -> Void)? = nil) {
        self.onCreated = onCreated
        self.template = template; _name = State(initialValue: template.content.name)
        _model = StateObject(wrappedValue: LearnerProgrammeViewModel(repository: repository, clock: clock, localContext: localContext))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your programme name", text: $name).disabled(model.canRetry || model.actionState == .saving)
                    Text("\(template.content.weeks.count) weeks from \(template.content.name)")
                    Text("Creates your independent programme at its first saved day and selects it in Today. Your existing programme and history are kept; you can switch back from Today → Programmes.")
                    Text("Exercise versions are kept as they were selected. No practice sessions, completions, or mastery are copied.").foregroundStyle(.secondary)
                }
                LearnerProgrammeFeedback(model: model)
                if model.loadState == .unavailable || model.loadState == .failed { Text("Programme storage is unavailable. Retry loading before creating anything.") }
                Button("Create and use in Today") { Task { _ = await model.create(from: template, name: name) } }
                    .disabled(model.loadState != .ready || model.canRetry || model.actionState == .saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
            }.navigationTitle("Your programme").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(model.actionState == .saving) } }
                .task { await model.load() }
                .onChange(of: model.acknowledgedCreatedPlanID) { _, id in if id != nil { dismiss(); onCreated?() } }
        }.interactiveDismissDisabled(model.actionState == .saving)
    }
}

struct LearnerPlanEditorScreen: View {
    @StateObject private var model: LearnerPlanEditorViewModel
    private let exerciseRepository: (any LibraryExerciseRepository)?
    @State private var exercises: [LibraryExercise] = []
    @State private var revisions: [LibraryExerciseReference: LibraryExerciseRevision]
    @State private var ready = false
    @State private var loadFailed = false
    @State private var confirmsDiscard = false
    @Environment(\.dismiss) private var dismiss
    init(plan: LearnerPlan, repository: any LearnerProgrammeRepository, exercises: (any LibraryExerciseRepository)?,
         clock: any PracticeClock, localContext: any PracticeLocalContextProviding) {
        _model = StateObject(wrappedValue: LearnerPlanEditorViewModel(plan: plan, repository: repository, clock: clock, localContext: localContext))
        exerciseRepository = exercises
        _revisions = State(initialValue: Dictionary(uniqueKeysWithValues: plan.revision.exercises.map { (LibraryExerciseReference(exerciseID: $0.exerciseID, revisionID: $0.id), $0) }))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Programme name", text: $model.draft.name)
                    Text("This edits your plan, not its source template. Changed goals, durations, or exercise placements become new assignments without copied completion. Keep the current saved day. Use Edit to reorder or remove items.").font(.caption)
                }
                ForEach($model.draft.weeks) { $week in
                    Section("Week \((model.draft.weeks.firstIndex(where: { $0.id == week.id }) ?? 0) + 1)") {
                        ProgrammeWeekEditor(week: $week, model: model, exercises: exercises, revisions: revisions)
                    }
                }.onMove { model.draft.weeks.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { model.draft.weeks.remove(atOffsets: $0) }
                Button("Add week") { model.addWeek() }.disabled(model.draft.weeks.count >= 104)
            }.disabled(!model.canEdit || !ready)
                .safeAreaInset(edge: .bottom) {
                    if case .failed(let message) = model.actionState { Text(message).padding().background(.regularMaterial) }
                    if loadFailed { VStack { Text("Exercises could not be loaded; editing is disabled."); Button("Retry loading") { Task { await loadExercises() } } }.padding().background(.regularMaterial) }
                }
                .navigationTitle("Edit my programme").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if model.hasChanges { confirmsDiscard = true } else { dismiss() } }.disabled(model.actionState == .saving) }
                    ToolbarItem(placement: .secondaryAction) { EditButton().disabled(!model.canEdit || !ready) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(model.canEdit ? "Save" : "Retry save") { Task { if await model.save() { dismiss() } } }.disabled(model.actionState == .saving || !ready)
                    }
                }
                .task { await loadExercises() }
                .confirmationDialog("Close without another save attempt?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                    Button("Close editor", role: .destructive) { dismiss() }; Button("Keep editing", role: .cancel) {}
                } message: { Text("Unsaved edits will be lost. A change already saved will not be deleted; refresh Today to check.") }
        }.interactiveDismissDisabled(model.hasChanges || model.actionState == .saving)
    }
    private func loadExercises() async {
        ready = false; loadFailed = false
        guard let exerciseRepository else { loadFailed = true; return }
        do {
            let values = try await exerciseRepository.exercises()
            var resolved = revisions
            for value in values { resolved[LibraryExerciseReference(exerciseID: value.id, revisionID: value.currentRevision.id)] = value.currentRevision }
            exercises = values; revisions = resolved; ready = true
        } catch { loadFailed = true }
    }
}
