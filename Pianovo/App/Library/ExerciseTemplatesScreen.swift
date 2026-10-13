import SwiftUI

struct ExerciseTemplatesScreen: View {
    @StateObject private var model: ExerciseTemplateViewModel
    private let exerciseRepository: (any LibraryExerciseRepository)?
    private let exerciseSaved: (LibraryExercise) -> Void
    @State private var search = ""
    @State private var showsArchived = false
    @State private var editing: TemplateEditingContext?
    @State private var usingTemplate: TemplateUseContext?
    @State private var showsCreatedMessage = false
    @State private var pendingCreatedMessage = false

    init(repository: (any LibraryExerciseTemplateRepository)?, exerciseRepository: (any LibraryExerciseRepository)?,
         clock: any PracticeClock, exerciseSaved: @escaping (LibraryExercise) -> Void) {
        _model = StateObject(wrappedValue: ExerciseTemplateViewModel(repository: repository, clock: clock))
        self.exerciseRepository = exerciseRepository
        self.exerciseSaved = exerciseSaved
    }

    var body: some View {
        List {
            Section {
                Text("Keep reusable defaults here. Use a template to create an independent exercise, then adapt its text before saving.")
                    .foregroundStyle(.secondary)
                Picker("Template list", selection: $showsArchived) {
                    Text("Active").tag(false)
                    Text("Archived").tag(true)
                }.pickerStyle(.segmented)
            }
            Section { TemplateFeedback(model: model) }
            Section {
                ForEach(model.visibleTemplates(archived: showsArchived, search: search)) { template in
                    NavigationLink {
                        templateDetail(id: template.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.currentRevision.content.name).font(.headline)
                            Text(template.currentRevision.content.defaults.category.title).foregroundStyle(.secondary)
                        }
                    }
                }
                if model.loadState == .ready && model.visibleTemplates(archived: showsArchived, search: search).isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No templates here yet" : "No matching templates", systemImage: "doc.on.doc",
                        description: Text("Create a template or choose a starter pattern from New Template."))
                }
            }
        }
        .navigationTitle("Exercise templates")
        .searchable(text: $search, prompt: "Find a template")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Blank template") { editing = TemplateEditingContext(template: nil, starter: nil) }
                    Section("Starter patterns") {
                        ForEach(LibraryStarterPattern.allCases, id: \.self) { starter in
                            Button(starter.draft.name) { editing = TemplateEditingContext(template: nil, starter: starter) }
                        }
                    }
                } label: { Label("New Template", systemImage: "plus") }
                .disabled(!model.allowsActions || editing != nil || usingTemplate != nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }
                    .disabled(model.loadState == .loading || model.actionState == .saving)
            }
        }
        .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { context in
            TemplateEditor(model: ExerciseTemplateEditorViewModel(template: context.template, starter: context.starter,
                repository: model.repository, clock: model.clock)) { model.acceptSaved($0) }
        }
        .sheet(item: $usingTemplate, onDismiss: {
            if pendingCreatedMessage { showsCreatedMessage = true; pendingCreatedMessage = false }
        }) { context in
            LibraryExerciseEditor(model: LibraryEditorViewModel(template: context.revision, repository: exerciseRepository, clock: model.clock)) {
                exerciseSaved($0)
                pendingCreatedMessage = true
            }
        }
        .alert("Exercise created", isPresented: $showsCreatedMessage) {
            Button("OK", role: .cancel) {}
        } message: { Text("Find your new exercise in Library’s Active list. It is independent of this template and has not been added to Today.") }
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private func templateDetail(id: LibraryTemplateID) -> some View {
        if let template = model.templates.first(where: { $0.id == id }) {
            TemplateDetail(template: template, model: model,
                edit: {
                    guard editing == nil && usingTemplate == nil else { return }
                    editing = TemplateEditingContext(template: template, starter: nil)
                },
                use: {
                    guard editing == nil && usingTemplate == nil else { return }
                    usingTemplate = TemplateUseContext(revision: template.currentRevision)
                }, canCreateExercise: exerciseRepository != nil)
        } else { ContentUnavailableView("Template unavailable", systemImage: "doc.on.doc") }
    }
}

private struct TemplateEditingContext: Identifiable {
    let id = UUID()
    let template: LibraryExerciseTemplate?
    let starter: LibraryStarterPattern?
}
private struct TemplateUseContext: Identifiable {
    let id = UUID()
    let revision: LibraryExerciseTemplateRevision
}

private struct TemplateDetail: View {
    let template: LibraryExerciseTemplate
    @ObservedObject var model: ExerciseTemplateViewModel
    let edit: () -> Void
    let use: () -> Void
    let canCreateExercise: Bool
    @State private var confirmsArchive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(template.currentRevision.content.name).font(.largeTitle.bold())
                if template.isArchived { Label("Archived", systemImage: "archivebox") }
                Text("Exercise defaults").font(.headline)
                Text(template.currentRevision.content.defaults.title).font(.title2)
                Text(template.currentRevision.content.defaults.category.title)
                Text(template.currentRevision.content.defaults.learningPurpose)
                Text(template.currentRevision.content.defaults.instructions)
                if template.currentRevision.content.defaults.referenceMaterialID != nil {
                    Text("A logical reference is linked. Documents cannot be opened here yet.").foregroundStyle(.secondary)
                }
                if template.currentRevision.starterPattern != nil { Text("Adapted from a Pianovo starter pattern.").font(.caption) }
                Text("Creating an exercise copies these defaults and keeps this template version as its origin. Editing this template does not change exercises already created.")
                    .foregroundStyle(.secondary)
                TemplateFeedback(model: model)
                Button("Create exercise", action: use).buttonStyle(.borderedProminent)
                    .frame(minHeight: 44).disabled(template.isArchived || !model.allowsActions || !canCreateExercise)
                Button("Edit template", action: edit).buttonStyle(.bordered)
                    .frame(minHeight: 44).disabled(template.isArchived || !model.allowsActions)
                Button(template.isArchived ? "Restore template" : "Archive template") { confirmsArchive = true }
                    .buttonStyle(.bordered).frame(minHeight: 44).disabled(!model.allowsActions)
            }.padding(24).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
        }
        .navigationTitle("Template").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(template.isArchived ? "Restore this template?" : "Archive this template?", isPresented: $confirmsArchive, titleVisibility: .visible) {
            Button(template.isArchived ? "Restore template" : "Archive template") {
                Task { await model.setArchived(template, archived: !template.isArchived) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Saved versions and exercises created from this template will be kept.") }
    }
}

private struct TemplateFeedback: View {
    @ObservedObject var model: ExerciseTemplateViewModel
    var body: some View {
        if model.loadState == .loading || model.actionState == .saving { ProgressView("Loading or saving templates…") }
        if model.loadState == .unavailable { Text("Saved templates unavailable. Reopen Pianovo to try again.") }
        if model.loadState == .failed {
            Text("Templates could not be read. Previously loaded content is kept until refresh.")
            Button("Retry loading") { Task { await model.load() } }
        }
        if case .failed(let failure) = model.actionState {
            Label("Template change could not be confirmed", systemImage: "exclamationmark.triangle")
            Text(failure.message)
            Button("Retry") { Task { await model.retryArchive() } }
            Button("Refresh templates") { Task { await model.load() } }
        }
    }
}

private struct TemplateEditor: View {
    @StateObject var model: ExerciseTemplateEditorViewModel
    let saved: (LibraryExerciseTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Template name", text: $model.draft.name)
                    if model.usesStarter { Text("Based on a Pianovo starter pattern. Adapt its defaults for your own use.").font(.caption) }
                }.disabled(!model.canEdit)
                Section("Exercise defaults") {
                    TextField("Exercise title", text: $model.draft.defaults.title)
                    Picker("Category", selection: $model.draft.defaults.category) {
                        ForEach(LibraryExerciseCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Learning purpose", text: $model.draft.defaults.learningPurpose, axis: .vertical).lineLimit(2...5)
                    TextField("Instructions", text: $model.draft.defaults.instructions, axis: .vertical).lineLimit(5...12)
                }.disabled(!model.canEdit)
                Section { Text("These are written defaults. Each new exercise can be adapted before saving; no notation or programme assignment is generated.") }
                if case .failed(let failure) = model.saveState {
                    Section { Label("Save could not be confirmed", systemImage: "exclamationmark.triangle")
                        Text(failure.message)
                        if !model.canEdit { Text("Retry keeps the same attempted change. Closing does not delete a change already saved.") } }
                }
            }
            .navigationTitle(model.isEditing ? "Edit template" : "New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if model.hasChanges { confirmsDiscard = true } else { dismiss() } }
                        .disabled(model.saveState == .saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.saveState == .saving ? "Saving…" : (model.canEdit ? "Save" : "Retry save")) {
                        Task { if let result = await model.save() { saved(result); dismiss() } }
                    }.disabled(model.saveState == .saving || model.saveState == .saved)
                }
            }
            .confirmationDialog("Close without another save attempt?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Close editor", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: { Text("Unsaved changes will be lost. A save that reached storage will not be deleted; refresh templates to check.") }
        }.interactiveDismissDisabled(model.hasChanges || model.saveState == .saving)
    }
}
