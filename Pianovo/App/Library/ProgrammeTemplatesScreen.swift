import SwiftUI

struct ProgrammeTemplatesScreen: View {
    @StateObject private var model: ProgrammeTemplateViewModel
    private let onProgrammeActivated: (() -> Void)?
    private let learnerRepository: (any LearnerProgrammeRepository)?
    private let localContext: any PracticeLocalContextProviding
    @State private var creating: ProgrammeCreationContext?
    @State private var search = ""
    @State private var archived = false
    @State private var editing: ProgrammeEditingContext?
    init(repository: (any LibraryProgrammeTemplateRepository)?, exerciseRepository: (any LibraryExerciseRepository)?, clock: any PracticeClock,
         learnerRepository: (any LearnerProgrammeRepository)? = nil, localContext: any PracticeLocalContextProviding = SystemPracticeLocalContextProvider(), onProgrammeActivated: (() -> Void)? = nil) {
        self.onProgrammeActivated = onProgrammeActivated
        self.learnerRepository = learnerRepository; self.localContext = localContext
        _model = StateObject(wrappedValue: ProgrammeTemplateViewModel(repository: repository, exerciseRepository: exerciseRepository, clock: clock))
    }
    var body: some View {
        List {
            Section {
                Text("Arrange saved exercises into reusable programmes. Use a template to create your own independent programme for Today.").foregroundStyle(.secondary)
                Picker("Programme list", selection: $archived) { Text("Active").tag(false); Text("Archived").tag(true) }.pickerStyle(.segmented)
            }
            Section { ProgrammeTemplateFeedback(model: model) }
            Section {
                ForEach(model.visibleTemplates(archived: archived, search: search)) { template in
                    NavigationLink {
                        detail(id: template.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(template.currentRevision.content.name).font(.headline)
                            Text("\(template.currentRevision.content.weeks.count) weeks").foregroundStyle(.secondary)
                        }
                    }
                }
                if model.loadState == .ready && model.visibleTemplates(archived: archived, search: search).isEmpty {
                    ContentUnavailableView("No programme templates here", systemImage: "calendar", description: Text("Create a blank template or choose a starter structure."))
                }
            }
        }
        .navigationTitle("Programme templates")
        .searchable(text: $search, prompt: "Find a programme template")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Blank template") { editing = ProgrammeEditingContext() }
                    Section("Starter structures — no exercises added") {
                        Button("One week: Morning / Evening") { editing = ProgrammeEditingContext(starterWeeks: 1) }
                        Button("Twelve weeks: Morning / Evening") { editing = ProgrammeEditingContext(starterWeeks: 12) }
                    }
                } label: { Label("New Programme", systemImage: "plus") }.disabled(!model.allowsActions || editing != nil || creating != nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }.disabled(model.loadState == .loading || model.actionState == .saving)
            }
        }
        .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { context in
            ProgrammeTemplateEditor(model: ProgrammeTemplateEditorViewModel(template: context.template, copying: context.copying,
                starterWeeks: context.starterWeeks, repository: model.repository, clock: model.clock),
                exercises: model.exercises, revisions: model.revisions) { model.acceptSaved($0) }
        }
        .sheet(item: $creating) { context in
            LearnerPlanCreationScreen(template: context.revision, repository: learnerRepository, clock: model.clock, localContext: localContext, onCreated: onProgrammeActivated)
        }
        .task { await model.loadIfNeeded() }
    }
    @ViewBuilder private func detail(id: LibraryProgrammeTemplateID) -> some View {
        if let template = model.templates.first(where: { $0.id == id }) {
            ProgrammeTemplateDetail(template: template, model: model,
                edit: { guard editing == nil && creating == nil else { return }; editing = ProgrammeEditingContext(template: template) },
                copy: { guard editing == nil && creating == nil else { return }; editing = ProgrammeEditingContext(copying: template.currentRevision) },
                createPlan: { guard editing == nil && creating == nil else { return }; creating = ProgrammeCreationContext(revision: template.currentRevision) },
                canCreatePlan: learnerRepository != nil)
        } else { ContentUnavailableView("Programme template unavailable", systemImage: "calendar") }
    }
}
private struct ProgrammeCreationContext: Identifiable {
    let id = UUID()
    let revision: LibraryProgrammeTemplateRevision
}
private struct ProgrammeEditingContext: Identifiable {
    let id = UUID()
    var template: LibraryProgrammeTemplate?
    var copying: LibraryProgrammeTemplateRevision?
    var starterWeeks: Int?
}
private struct ProgrammeTemplateFeedback: View {
    @ObservedObject var model: ProgrammeTemplateViewModel
    var body: some View {
        if model.loadState == .loading || model.actionState == .saving { ProgressView("Loading or saving programmes…") }
        if model.loadState == .unavailable { Text("Programme templates unavailable. Reopen Pianovo to try again.") }
        if model.loadState == .failed {
            Text("Programme templates or exercise versions could not be read. Previously loaded content is kept; editing is disabled until refresh succeeds.")
            Button("Retry loading") { Task { await model.load() } }
        }
        if case .failed(let failure) = model.actionState {
            Text(failure.message)
            Button("Retry") { Task { await model.retryArchive() } }
            Button("Refresh") { Task { await model.load() } }
        }
    }
}
private struct ProgrammeTemplateDetail: View {
    let template: LibraryProgrammeTemplate
    @ObservedObject var model: ProgrammeTemplateViewModel
    let edit: () -> Void
    let copy: () -> Void
    let createPlan: () -> Void
    let canCreatePlan: Bool
    @State private var confirmsArchive = false
    var body: some View {
        List {
            Section {
                Text(template.currentRevision.content.name).font(.title.bold())
                if template.isArchived { Label("Archived", systemImage: "archivebox") }
                Text("Reusable plan only. It is not an active learner programme and does not change Today.").foregroundStyle(.secondary)
                if let origin = template.currentRevision.origin { Text("Copied from: \(origin.name)").font(.caption) }
                ProgrammeTemplateFeedback(model: model)
                Button("Edit programme template", action: edit).disabled(template.isArchived || !model.allowsActions)
                Button("Use as my programme", action: createPlan).disabled(!model.allowsActions || template.isArchived || !canCreatePlan)
                Button("Create editable copy", action: copy).disabled(!model.allowsActions)
                Button(template.isArchived ? "Restore template" : "Archive template") { confirmsArchive = true }.disabled(!model.allowsActions)
            }
            ForEach(Array(template.currentRevision.content.weeks.enumerated()), id: \.element.id) { w, week in
                Section("Week \(w + 1)") {
                    ForEach(Array(week.days.enumerated()), id: \.element.id) { d, day in
                        DisclosureGroup("Day \(d + 1)\(day.isRecovery ? " — Recovery / reflection" : "")") {
                            ForEach(day.sections) { section in
                                Text(section.name).font(.headline)
                                if section.placements.isEmpty { Text("No exercises in this section").foregroundStyle(.secondary) }
                                ForEach(section.placements) { placement in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.revisions[placement.exercise]?.content.title ?? "Exercise version unavailable")
                                        Text("\(placement.minutes) min · \(placement.goal)").font(.caption)
                                        if let revision = model.revisions[placement.exercise] {
                                            Text(revision.content.instructions).font(.caption).foregroundStyle(.secondary)
                                            if revision.content.referenceMaterialID != nil { Text("Document access is not available here.").font(.caption) }
                                        }
                                    }
                                }
                            }
                            if day.sections.isEmpty { Text("No sections scheduled").foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Programme template").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(template.isArchived ? "Restore this template?" : "Archive this template?", isPresented: $confirmsArchive, titleVisibility: .visible) {
            Button(template.isArchived ? "Restore template" : "Archive template") { Task { await model.setArchived(template, archived: !template.isArchived) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Saved revisions and independent copies will be kept.") }
    }
}
private struct ProgrammeTemplateEditor: View {
    @StateObject var model: ProgrammeTemplateEditorViewModel
    let exercises: [LibraryExercise]
    let revisions: [LibraryExerciseReference: LibraryExerciseRevision]
    let saved: (LibraryProgrammeTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Programme template name", text: $model.draft.name)
                    Text("Add weeks and days, then add saved exercises to named sections. Use Edit to move or remove items. Recovery days may contain reflection work or be empty. Saving does not change Today.").font(.caption)
                }
                ForEach($model.draft.weeks) { $week in
                    Section("Week \((model.draft.weeks.firstIndex(where: { $0.id == week.id }) ?? 0) + 1)") {
                        ProgrammeWeekEditor(week: $week, model: model, exercises: exercises, revisions: revisions)
                    }
                }
                .onMove { model.draft.weeks.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { model.draft.weeks.remove(atOffsets: $0) }
                Button("Add week") { model.addWeek() }.disabled(model.draft.weeks.count >= 104)
            }
            .disabled(!model.canEdit)
            .safeAreaInset(edge: .bottom) {
                if case .failed(let failure) = model.saveState { Text(failure.message).font(.callout).padding().frame(maxWidth: .infinity).background(.regularMaterial) }
            }
            .navigationTitle(model.isEditing ? "Edit programme" : "New programme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if model.hasChanges { confirmsDiscard = true } else { dismiss() } }.disabled(model.saveState == .saving)
                }
                ToolbarItem(placement: .secondaryAction) { EditButton().disabled(!model.canEdit) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.canEdit ? "Save" : "Retry save") { Task { if let result = await model.save() { saved(result); dismiss() } } }
                        .disabled(model.saveState == .saving || model.saveState == .saved)
                }
            }
            .confirmationDialog("Close without another save attempt?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Close editor", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: { Text("Unsaved edits will be lost. A change already saved will not be deleted; refresh the list to check.") }
        }.interactiveDismissDisabled(model.hasChanges || model.saveState == .saving)
    }
}
struct ProgrammeWeekEditor<Model: ProgrammeDraftEditing>: View {
    @Binding var week: LibraryProgrammeWeek
    @ObservedObject var model: Model
    let exercises: [LibraryExercise]
    let revisions: [LibraryExerciseReference: LibraryExerciseRevision]
    var body: some View {
        ForEach($week.days) { $day in
            DisclosureGroup("Day \((week.days.firstIndex(where: { $0.id == day.id }) ?? 0) + 1)") {
                ProgrammeDayEditor(day: $day, weekID: week.id, model: model, exercises: exercises, revisions: revisions)
            }
        }
        .onDelete { week.days.remove(atOffsets: $0) }
        .onMove { week.days.move(fromOffsets: $0, toOffset: $1) }
        Button("Add day") { model.addDay(weekID: week.id) }.disabled(week.days.count >= 7)
    }
}
struct ProgrammeDayEditor<Model: ProgrammeDraftEditing>: View {
    @Binding var day: LibraryProgrammeDay
    let weekID: UUID
    @ObservedObject var model: Model
    let exercises: [LibraryExercise]
    let revisions: [LibraryExerciseReference: LibraryExerciseRevision]
    var body: some View {
        Toggle("Recovery / reflection day", isOn: $day.isRecovery)
        ForEach($day.sections) { $section in
            DisclosureGroup(section.name.isEmpty ? "Unnamed section" : section.name) {
                ProgrammeSectionEditor(section: $section, weekID: weekID, dayID: day.id, model: model, exercises: exercises, revisions: revisions)
            }
        }
        .onDelete { day.sections.remove(atOffsets: $0) }
        .onMove { day.sections.move(fromOffsets: $0, toOffset: $1) }
        Button("Add section") { model.addSection(weekID: weekID, dayID: day.id) }.disabled(day.sections.count >= 8)
    }
}
struct ProgrammeSectionEditor<Model: ProgrammeDraftEditing>: View {
    @Binding var section: LibraryProgrammeSection
    let weekID: UUID
    let dayID: UUID
    @ObservedObject var model: Model
    let exercises: [LibraryExercise]
    let revisions: [LibraryExerciseReference: LibraryExerciseRevision]
    var body: some View {
        TextField("Section name", text: $section.name)
        ForEach($section.placements) { $placement in
            VStack(alignment: .leading, spacing: 8) {
                Text(revisions[placement.exercise]?.content.title ?? "Exercise version unavailable").font(.headline)
                Text("Pinned saved exercise version").font(.caption).foregroundStyle(.secondary)
                TextField("Goal for this placement", text: $placement.goal, axis: .vertical)
                Stepper("Planned time: \(placement.minutes) min", value: $placement.minutes, in: 1...1440)
            }
        }
        .onDelete { section.placements.remove(atOffsets: $0) }
        .onMove { section.placements.move(fromOffsets: $0, toOffset: $1) }
        Menu {
            ForEach(exercises.filter { !$0.isArchived }) { exercise in
                Button(exercise.currentRevision.content.title) { model.addExercise(exercise, weekID: weekID, dayID: dayID, sectionID: section.id) }
            }
        } label: { Label("Add saved exercise", systemImage: "plus") }
        .disabled(exercises.allSatisfy(\.isArchived) || section.placements.count >= 100)
        if exercises.allSatisfy(\.isArchived) { Text("Create or restore an exercise in Library first.").font(.caption).foregroundStyle(.secondary) }
    }
}
