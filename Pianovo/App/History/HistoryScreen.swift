import SwiftUI

struct HistoryScreen: View {
    @StateObject private var model: HistoryViewModel
    @State private var editing: NoteEditingContext?
    @Environment(\.scenePhase) private var phase
    init(dependencies: AppDependencies) { _model = StateObject(wrappedValue: HistoryViewModel(dependencies: dependencies)) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Saved sessions, learner reports and private notes. Standalone Practice does not save sessions. Accuracy and tempo are not recorded here.").foregroundStyle(.secondary)
                    if model.loading { ProgressView("Loading history…") }
                    ForEach(model.issues, id: \.self) { Text($0).foregroundStyle(.secondary) }
                    if !model.issues.isEmpty { Button("Retry loading") { Task { await model.load() } } }
                }
                ForEach(model.entries) { entry in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(entry.title).font(.headline)
                        Text(entry.detail)
                        Text(entry.recordedTime).font(.caption)
                        Text("Recorded day: \(entry.timestamp.localDay.dayKey) · \(entry.timestamp.localDay.timeZoneIdentifier)").font(.caption).foregroundStyle(.secondary)
                        if let context = entry.noteContext {
                            Button("Add private note") { editing = NoteEditingContext(context: context) }
                                .disabled(model.dependencies.privateNoteRepository == nil || model.loading)
                        }
                    }.padding(.vertical, 6)
                }
                if !model.loading && model.entries.isEmpty && model.issues.isEmpty {
                    ContentUnavailableView("No saved history yet", systemImage: "clock", description: Text("End & Save an assigned session, report work on your learner programme, or add a private note to a started programme day."))
                }
            }.navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Note on current day", systemImage: "square.and.pencil") { if let context = model.currentDayContext { editing = NoteEditingContext(context: context) } }
                            .disabled(model.currentDayContext == nil || model.dependencies.privateNoteRepository == nil || model.loading)
                    }
                    ToolbarItem(placement: .secondaryAction) { Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }.disabled(model.loading) }
                }
                .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { context in
                    PrivateNoteEditorScreen(context: context.context, dependencies: model.dependencies)
                }
                .task { await model.load() }
                .onChange(of: phase) { _, value in if value == .active && editing == nil { Task { await model.load() } } }
        }
    }
}
private struct NoteEditingContext: Identifiable { let id = UUID(); let context: LearnerNoteContext }
private struct PrivateNoteEditorScreen: View {
    let context: LearnerNoteContext
    @StateObject private var model: PrivateNoteEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var discard = false
    init(context: LearnerNoteContext, dependencies: AppDependencies) {
        self.context = context
        _model = StateObject(wrappedValue: PrivateNoteEditorViewModel(context: context, repository: dependencies.privateNoteRepository,
            clock: dependencies.clock, localContext: dependencies.localContextProvider))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(context.title).font(.headline)
                    Text("Private learner note · stored on this device. Not shared with a teacher or community.").foregroundStyle(.secondary)
                    TextField("What did you notice? What would you like to work on next?", text: $model.text, axis: .vertical).lineLimit(8...20).disabled(!model.canEdit)
                    Text("This note does not complete work, move your programme, or evaluate mastery.").font(.caption)
                }
                if let error = model.error { Section { Text(error) } }
            }.navigationTitle("Private note").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if model.hasChanges { discard = true } else { dismiss() } }.disabled(model.saving) }
                    ToolbarItem(placement: .confirmationAction) { Button(model.canEdit ? "Save" : "Retry save") { Task { if await model.save() { dismiss() } } }.disabled(model.saving) }
                }
                .confirmationDialog("Close without another save attempt?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Close note", role: .destructive) { dismiss() }; Button("Keep writing", role: .cancel) {}
                } message: { Text("Unsaved text will be lost. A note already saved will not be deleted; refresh History to check.") }
        }.interactiveDismissDisabled(model.hasChanges || model.saving)
    }
}
