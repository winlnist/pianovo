import SwiftUI

struct AssignmentPracticeScreen: View {
    @StateObject private var coordinator: AssignmentPracticeCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsExitConfirmation = false

    init(context: AssignmentPracticeContext, dependencies: AppDependencies) {
        _coordinator = StateObject(wrappedValue: AssignmentPracticeCoordinator(
            context: context, repository: dependencies.practiceHistoryRepository,
            clock: dependencies.clock, localContext: dependencies.localContextProvider,
            makeID: { PracticeSessionRecordID(UUID().uuidString)! }, practice: PracticeViewModel()
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.state {
                case .preparation:
                    AssignmentPreparationView(coordinator: coordinator, practice: coordinator.practice)
                case .active:
                    PracticeScreen(viewModel: coordinator.practice, locksConfiguration: true,
                                   assignedInput: coordinator.submit)
                case .starting, .finishing:
                    ProgressView(coordinator.state == .starting ? "Starting session…" : "Saving session…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .interrupted:
                    message("Session paused by backgrounding",
                            detail: "Your session stopped when Pianovo moved to the background. Save it or discard it before starting another session.")
                case .failed(let failure):
                    message("Session could not be saved", detail: failure.message)
                case .finished:
                    summary
                case .discarded:
                    Color.clear
                }
            }
            .navigationTitle(coordinator.context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(coordinator.state == .finished ? "Return to Today" : "Back") {
                        if coordinator.state == .preparation || coordinator.state == .finished {
                            dismiss()
                        } else {
                            showsExitConfirmation = true
                        }
                    }
                    .disabled(coordinator.state == .finishing || coordinator.state == .starting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if coordinator.canSave {
                        Button("End & Save") { Task { await coordinator.finish() } }
                    }
                }
            }
            .confirmationDialog("Leave this session?", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
                if coordinator.canSave {
                    Button("End & Save") { Task { await coordinator.finish() } }
                }
                Button("Discard session", role: .destructive) {
                    coordinator.discard()
                    dismiss()
                }
                Button(coordinator.state == .active ? "Continue practising" : "Keep session open", role: .cancel) {}
            } message: {
                Text("Discarding does not save this session or delete an earlier save. Unsaved sessions cannot be recovered after closing the app.")
            }
        }
        .interactiveDismissDisabled(coordinator.state != .preparation && coordinator.state != .finished)
        .onAppear { updateScene(scenePhase) }
        .onChange(of: scenePhase) { _, phase in updateScene(phase) }
        .onChange(of: showsExitConfirmation) { _, showing in
            coordinator.setForegroundActive(scenePhase == .active && !showing)
        }
        .onDisappear { coordinator.setForegroundActive(false) }
    }

    private func updateScene(_ phase: ScenePhase) {
        if phase == .background {
            coordinator.background()
        } else {
            coordinator.setForegroundActive(phase == .active && !showsExitConfirmation)
        }
    }

    private func message(_ title: String, detail: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(title, systemImage: "pause.circle")
                    .font(.title2.bold())
                Text(detail)
                if coordinator.canSave {
                    Button("End & Save") { Task { await coordinator.finish() } }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
                Button("Discard session", role: .destructive) { showsExitConfirmation = true }
                    .frame(minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Session saved", systemImage: "checkmark.circle")
                    .font(.title.bold())
                Text("Your assignment and programme position have not been marked complete or advanced.")
                if let stats = coordinator.summary {
                    Text("Feedback from this session").font(.title2.bold())
                    if stats.totalAttempts == 0 {
                        Text("No notes attempted")
                    } else {
                        LabeledContent("Pitch-answer accuracy", value: "\(Int(stats.accuracyPercentage.rounded()))%")
                    }
                    LabeledContent("Correct answers", value: "\(stats.correctAnswers)")
                    LabeledContent("Incorrect attempts", value: "\(stats.incorrectAttempts)")
                    LabeledContent("Total attempts", value: "\(stats.totalAttempts)")
                    LabeledContent("Completed prompts", value: "\(stats.promptsCompleted)")
                    LabeledContent("Current streak", value: "\(stats.currentStreak)")
                }
                Text("The session’s assignment and start/end times are saved. These numeric results are temporary and will disappear when you leave this summary.")
                    .foregroundStyle(.secondary)
                Button("Return to Today") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct AssignmentPreparationView: View {
    @ObservedObject var coordinator: AssignmentPracticeCoordinator
    @ObservedObject var practice: PracticeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(coordinator.context.title).font(.largeTitle.bold())
                Text(coordinator.context.goal)
                Label("\(coordinator.context.plannedDurationMinutes) minutes planned", systemImage: "clock")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading mode").font(.headline).accessibilityHidden(true)
                    Picker("Reading mode", selection: Binding(get: { practice.mode }, set: practice.updateMode)) {
                        ForEach(PracticeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .frame(minHeight: 44)
                }
                pitchPicker("Lowest note", pitch: practice.lowerPitch, update: practice.updateLowerPitch)
                pitchPicker("Highest note", pitch: practice.upperPitch, update: practice.updateUpperPitch)
                Text("Choose your range before starting. Mode, range, and reset controls are locked during this assigned session.")
                Text("Use a connected MIDI piano for generated sight-reading. End & Save records the session times; numeric results are shown only in the immediate summary. Unsaved sessions cannot be recovered after the app closes.")
                    .foregroundStyle(.secondary)
                Button("Start Session") { coordinator.start() }
                    .font(.headline)
                    .frame(minHeight: 44)
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.isForegroundActive)
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func pitchPicker(_ title: String, pitch: Pitch, update: @escaping (Pitch) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).accessibilityHidden(true)
            Picker(title, selection: Binding(get: { pitch }, set: update)) {
                ForEach(practice.pitchOptions, id: \.self) { option in
                    Text(PracticeViewModel.pitchName(option)).tag(option)
                }
            }
            .frame(minHeight: 44)
        }
    }
}

private extension AssignmentPracticeFailure {
    var message: String {
        switch self {
        case .persistenceUnavailable:
            "Saved sessions are unavailable. Return to Today and reopen Pianovo to try again. Standalone Practice remains available."
        case .invalidTimeRange:
            "The device clock moved before the session’s start time. This session cannot be saved. Discard it and check the device time."
        case .saveFailed:
            "Saving could not be confirmed. End & Save retries and checks the same session. Discarding will not delete a save that already reached storage. Keep the app open until you decide."
        case .conflictingRecord:
            "A different saved session has the same identity. It has not been replaced. This session cannot be saved."
        case .verificationFailed:
            "The saved session could not be verified. End & Save retries without creating a new session identity."
        }
    }
}
