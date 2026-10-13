import SwiftUI

struct LibraryScreen: View {
    @StateObject private var model: LibraryViewModel
    private let onProgrammeActivated: (() -> Void)?
    private let learnerProgrammeRepository: (any LearnerProgrammeRepository)?
    private let localContext: any PracticeLocalContextProviding
    private let programmeTemplateRepository: (any LibraryProgrammeTemplateRepository)?
    private let templateRepository: (any LibraryExerciseTemplateRepository)?
    @State private var search = ""
    @State private var showsArchived = false
    @State private var editing: LibraryEditingContext?

    init(dependencies: AppDependencies, onProgrammeActivated: (() -> Void)? = nil) {
        self.onProgrammeActivated = onProgrammeActivated
        learnerProgrammeRepository = dependencies.learnerProgrammeRepository
        localContext = dependencies.localContextProvider
        programmeTemplateRepository = dependencies.programmeTemplateRepository
        templateRepository = dependencies.templateRepository
        _model = StateObject(wrappedValue: LibraryViewModel(repository: dependencies.libraryRepository, clock: dependencies.clock))
    }

    init(viewModel: LibraryViewModel) { onProgrammeActivated = nil; learnerProgrammeRepository = nil; localContext = SystemPracticeLocalContextProvider(); programmeTemplateRepository = nil; templateRepository = nil; _model = StateObject(wrappedValue: viewModel) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Create reusable practice guidance. Exercises stay private on this device. Add saved versions to programme templates to organise your practice.")
                        .foregroundStyle(.secondary)
                    Picker("Exercise list", selection: $showsArchived) {
                        Text("Active").tag(false)
                        Text("Archived").tag(true)
                    }.pickerStyle(.segmented)
                }
                Section {
                    NavigationLink {
                        ExerciseTemplatesScreen(repository: templateRepository, exerciseRepository: model.repository, clock: model.clock) {
                            model.acceptSaved($0)
                        }
                    } label: { Label("Exercise templates", systemImage: "doc.on.doc") }
                }
                Section {
                    NavigationLink {
                        ProgrammeTemplatesScreen(repository: programmeTemplateRepository, exerciseRepository: model.repository, clock: model.clock, learnerRepository: learnerProgrammeRepository, localContext: localContext, onProgrammeActivated: onProgrammeActivated)
                    } label: { Label("Programme templates", systemImage: "calendar") }
                }
                feedback
                Section {
                    ForEach(model.visibleExercises(archived: showsArchived, search: search)) { exercise in
                        NavigationLink(value: exercise.id) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(exercise.currentRevision.content.title).font(.headline)
                                Text(exercise.currentRevision.content.category.title).font(.subheadline).foregroundStyle(.secondary)
                                Text(exercise.currentRevision.content.learningPurpose).lineLimit(2).font(.callout)
                            }.padding(.vertical, 4)
                        }
                    }
                    if model.loadState == .ready && model.visibleExercises(archived: showsArchived, search: search).isEmpty {
                        ContentUnavailableView(
                            search.isEmpty ? (showsArchived ? "No archived exercises" : "Your exercise Library is empty") : "No matching exercises",
                            systemImage: showsArchived ? "archivebox" : "books.vertical",
                            description: Text(showsArchived ? "Archived exercises remain available here." : "Use New Exercise to write your first activity.")
                        )
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $search, prompt: "Find an exercise")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Exercise", systemImage: "plus") { editing = LibraryEditingContext(exercise: nil) }
                        .disabled(!model.allowsActions)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }
                        .disabled(model.loadState == .loading || model.archiveState == .saving)
                }
            }
            .navigationDestination(for: LibraryExerciseID.self) { id in
                if let exercise = model.exercises.first(where: { $0.id == id }) {
                    LibraryExerciseDetail(exercise: exercise, model: model,
                        edit: { editing = LibraryEditingContext(exercise: exercise) },
                        archive: { Task { await model.setArchived(exercise, archived: !exercise.isArchived) } })
                } else { ContentUnavailableView("Exercise unavailable", systemImage: "books.vertical") }
            }
        }
        .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { context in
            LibraryExerciseEditor(model: LibraryEditorViewModel(exercise: context.exercise, repository: model.repository, clock: model.clock)) {
                model.acceptSaved($0)
            }
        }
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder private var feedback: some View {
        if model.loadState == .loading { ProgressView("Loading your Library…") }
        if model.loadState == .unavailable {
            Section { Label("Saved Library unavailable", systemImage: "exclamationmark.triangle")
                Text("Close and reopen Pianovo to try again. Library changes cannot be saved right now.") }
        }
        if model.loadState == .failed {
            Section { Label("Your Library could not be read", systemImage: "exclamationmark.triangle")
                Text("Previously loaded exercises are shown until you refresh. No data has been reset.")
                Button("Retry loading") { Task { await model.load() } } }
        }
        if model.archiveState == .saving { ProgressView("Saving archive status…") }
        if case .failed(let failure) = model.archiveState {
            Section { Label("Archive status could not be confirmed", systemImage: "exclamationmark.triangle")
                Text(failure.message)
                Button("Retry") { Task { await model.retryArchive() } }
                Button("Refresh Library") { Task { await model.load() } } }
        }
    }
}

private struct LibraryEditingContext: Identifiable {
    let id = UUID()
    let exercise: LibraryExercise?
}

private struct LibraryExerciseDetail: View {
    let exercise: LibraryExercise
    @ObservedObject var model: LibraryViewModel
    let edit: () -> Void
    let archive: () -> Void
    @State private var confirmsArchive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(exercise.currentRevision.content.title).font(.largeTitle.bold())
                Label(exercise.currentRevision.content.category.title, systemImage: "music.note")
                if exercise.isArchived { Label("Archived", systemImage: "archivebox") }
                Text("Learning purpose").font(.headline).accessibilityAddTraits(.isHeader)
                Text(exercise.currentRevision.content.learningPurpose)
                Text("Instructions").font(.headline).accessibilityAddTraits(.isHeader)
                Text(exercise.currentRevision.content.instructions)
                if let id = exercise.currentRevision.content.referenceMaterialID {
                    let material = PianovoReferenceMaterialCatalogue.catalogue().material(withID: id)
                    Label(material?.title ?? "Unknown reference material", systemImage: "doc")
                    Text("Document unavailable in Library. Opening and importing are not supported yet.").foregroundStyle(.secondary)
                }
                Text("Written guidance only. Add a saved version to a programme template to plan it; this Library view does not launch MIDI Practice.")
                    .foregroundStyle(.secondary)
                if model.archiveState == .saving { ProgressView("Saving archive status…") }
                if case .failed(let failure) = model.archiveState {
                    Label("Archive status could not be confirmed", systemImage: "exclamationmark.triangle")
                    Text(failure.message)
                    Button("Retry") { Task { await model.retryArchive() } }
                    Button("Refresh Library") { Task { await model.load() } }
                }
                if model.loadState == .failed {
                    Text("Your Library could not be read. Refresh before making another change.")
                    Button("Retry loading") { Task { await model.load() } }
                }
                Text("Saved \(exercise.currentRevision.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                if let attribution = exercise.currentRevision.origin?.creatorAttribution { Text("Original creator: \(attribution)") }
                if let origin = exercise.currentRevision.templateOrigin {
                    Text("Created from template: \(origin.name)")
                    Text("This exercise keeps the template version used. Later template edits do not change it.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let creator = origin.creatorAttribution { Text(creator).font(.caption) }
                }
                HStack {
                    Button("Edit exercise", action: edit).buttonStyle(.borderedProminent)
                        .disabled(exercise.isArchived || !model.allowsActions)
                    Button(exercise.isArchived ? "Restore exercise" : "Archive exercise") { confirmsArchive = true }
                        .buttonStyle(.bordered).disabled(!model.allowsActions)
                }.frame(minHeight: 44)
            }.padding(24).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(exercise.isArchived ? "Restore this exercise?" : "Archive this exercise?", isPresented: $confirmsArchive, titleVisibility: .visible) {
            Button(exercise.isArchived ? "Restore exercise" : "Archive exercise", action: archive)
            Button("Cancel", role: .cancel) {}
        } message: { Text("Archiving keeps the exercise and all its saved versions. You can restore it from Archived.") }
    }
}

struct LibraryExerciseEditor: View {
    @StateObject var model: LibraryEditorViewModel
    let saved: (LibraryExercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Title", text: $model.draft.title)
                    Picker("Category", selection: $model.draft.category) {
                        ForEach(LibraryExerciseCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Learning purpose", text: $model.draft.learningPurpose, axis: .vertical).lineLimit(2...5)
                    TextField("Instructions", text: $model.draft.instructions, axis: .vertical).lineLimit(5...12)
                }.disabled(!model.canEdit)
                Section {
                    Text("Write an activity to practise yourself. This saves guidance, not generated notation or a programme assignment.")
                    if model.isEditing { Text("Editing keeps earlier saved versions.") }
                }
                if case .failed(let failure) = model.saveState {
                    Section { Label("Save could not be confirmed", systemImage: "exclamationmark.triangle")
                        Text(failure.message)
                        if !model.canEdit { Text("The attempted change is kept for retry. Closing this editor will not undo a save that already reached storage.") } }
                }
            }
            .navigationTitle(model.isEditing ? "Edit exercise" : "New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if model.hasChanges { confirmsDiscard = true } else { dismiss() }
                    }.disabled(model.saveState == .saving)
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
            } message: { Text("Unsaved changes will be lost. A change that already reached storage will not be deleted. Refresh Library to check its saved status.") }
        }
        .interactiveDismissDisabled(model.hasChanges || model.saveState == .saving)
    }
}

extension LibraryExerciseCategory {
    var title: String {
        switch self {
        case .warmUp: "Warm-up"
        case .technique: "Technique"
        case .beyer: "Beyer"
        case .repertoireHarmony: "Repertoire and harmony"
        case .sightReading: "Sight-reading"
        case .review: "Review"
        case .reflection: "Reflection"
        }
    }
}

extension LibraryActionFailure {
    var message: String {
        switch self {
        case .unavailable: "Saved Library is unavailable. Reopen Pianovo to try again."
        case .storage: "Saving could not be confirmed. Retry the same change or close and refresh Library to check its stored status."
        case .conflict: "This content changed or was archived. Close and refresh before editing it again."
        case .invalid(let issues): issues.map {
            switch $0 {
            case .templateNameRequired: "Enter a template name."
            case .titleRequired: "Enter a title."
            case .instructionsRequired: "Enter instructions."
            case .purposeRequired: "Enter a learning purpose."
            }
        }.joined(separator: " ")
        }
    }
}

#Preview { LibraryScreen(dependencies: .preview()) }
