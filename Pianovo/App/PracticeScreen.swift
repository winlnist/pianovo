import Combine
import SwiftUI

struct PracticeScreen: View {
    @StateObject private var viewModel: PracticeViewModel
    @StateObject private var midiService: MIDIInputService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    private let locksConfiguration: Bool
    private let assignedInput: ((MIDIInputEvent) -> Void)?
    @State private var isHUDVisible = true
    @State private var hideHUDTask: Task<Void, Never>?

    init() {
        locksConfiguration = false
        assignedInput = nil
        _viewModel = StateObject(wrappedValue: PracticeViewModel())
        _midiService = StateObject(wrappedValue: MIDIInputService())
    }

    init(viewModel: PracticeViewModel, midiService: MIDIInputService = MIDIInputService(),
         locksConfiguration: Bool = false, assignedInput: ((MIDIInputEvent) -> Void)? = nil) {
        self.locksConfiguration = locksConfiguration
        self.assignedInput = assignedInput
        _viewModel = StateObject(wrappedValue: viewModel)
        _midiService = StateObject(wrappedValue: midiService)
    }

    var body: some View {
        ZStack {
            musicSheet
                .onTapGesture {
                    revealHUD()
                }

            if isHUDVisible {
                hud
                    .transition(.opacity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onReceive(midiService.$lastEvent.compactMap { $0 }) { event in
            guard isVisible, scenePhase == .active else { return }
            if let assignedInput { assignedInput(event) } else { viewModel.submit(event) }
        }
        .onAppear {
            isVisible = true
            scheduleHUDHide()
        }
        .onDisappear {
            isVisible = false
            hideHUDTask?.cancel()
        }
    }

    private var musicSheet: some View {
        SightReadingPageView(
            exercise: viewModel.exercise,
            currentEventIndex: viewModel.currentEventIndex,
            feedback: viewModel.feedback
        )
        .padding(horizontalSizeClass == .regular ? 24 : 12)
        .accessibilitySortPriority(2)
    }

    private var midiSourceName: String? {
        midiService.connectedSources.first?.name
    }

    private var hud: some View {
        VStack {
            topHUD
            Spacer()
            bottomHUD
        }
        .padding(horizontalSizeClass == .regular ? 20 : 12)
        .animation(.easeInOut(duration: 0.18), value: isHUDVisible)
        .onTapGesture {
            revealHUD()
        }
    }

    private var topHUD: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AppBrand.displayName)
                    .font(.headline.weight(.semibold))
                Text("\(viewModel.mode.rawValue) - \(viewModel.progressLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MIDIStatusBadge(isConnected: midiService.isConnected, sourceName: midiSourceName)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private var bottomHUD: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 12) {
                    modeControls.disabled(locksConfiguration)
                    rangeControls.disabled(locksConfiguration)
                    statistics
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    modeControls.disabled(locksConfiguration)
                    rangeControls.disabled(locksConfiguration)
                    statistics
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private var modeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mode")
                .font(.headline)

            Picker("Practice mode", selection: Binding(get: {
                viewModel.mode
            }, set: { mode in
                revealHUD()
                viewModel.updateMode(mode)
            })) {
                ForEach(PracticeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Practice mode, \(viewModel.mode.rawValue)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Range")
                .font(.headline)

            HStack(spacing: 12) {
                pitchPicker(
                    title: "Lowest",
                    selection: viewModel.lowerPitch,
                    options: viewModel.pitchOptions,
                    action: viewModel.updateLowerPitch
                )

                pitchPicker(
                    title: "Highest",
                    selection: viewModel.upperPitch,
                    options: viewModel.pitchOptions,
                    action: viewModel.updateUpperPitch
                )
            }

            Button {
                revealHUD()
                viewModel.resetSession()
            } label: {
                Label("Reset Session", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func pitchPicker(
        title: String,
        selection: Pitch,
        options: [Pitch],
        action: @escaping (Pitch) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { pitch in
                Button(PracticeViewModel.pitchName(pitch)) {
                    revealHUD()
                    action(pitch)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(PracticeViewModel.pitchName(selection))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("\(title) pitch, \(PracticeViewModel.pitchName(selection))")
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session")
                .font(.headline)

            let stats = viewModel.statistics
            LazyVGrid(columns: statisticColumns, alignment: .leading, spacing: 10) {
                statistic("Correct", "\(stats.correctAnswers)")
                statistic("Wrong", "\(stats.incorrectAttempts)")
                statistic("Attempts", "\(stats.totalAttempts)")
                statistic("Accuracy", "\(Int(stats.accuracyPercentage.rounded()))%")
                statistic("Streak", "\(stats.currentStreak)")
                statistic("Completed", "\(stats.promptsCompleted)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var statisticColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        }

        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    }

    private func statistic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private func revealHUD() {
        isHUDVisible = true
        scheduleHUDHide()
    }

    private func scheduleHUDHide() {
        hideHUDTask?.cancel()
        hideHUDTask = Task {
            try? await Task.sleep(for: .seconds(2))

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHUDVisible = false
                }
            }
        }
    }
}

private struct MIDIStatusBadge: View {
    let isConnected: Bool
    let sourceName: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label(isConnected ? "MIDI Connected" : "No MIDI Piano", systemImage: isConnected ? "circle.fill" : "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isConnected ? .green : .secondary)
                .labelStyle(.titleAndIcon)

            if let sourceName, isConnected {
                Text(sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isConnected, let sourceName {
            return "MIDI connected, \(sourceName)"
        }

        return isConnected ? "MIDI connected" : "No MIDI piano connected"
    }
}

private struct PracticeFeedbackBanner: View {
    let feedback: PracticeFeedback

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .imageScale(.medium)
            Text(message)
                .font(.headline)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private var message: String {
        switch feedback {
        case .neutral:
            return "Play the note shown on the staff"
        case .correct:
            return "Correct"
        case .incorrect(let playedPitch):
            return "Not quite - played \(PracticeViewModel.pitchName(playedPitch))"
        }
    }

    private var iconName: String {
        switch feedback {
        case .neutral:
            return "music.note"
        case .correct:
            return "checkmark.circle.fill"
        case .incorrect:
            return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch feedback {
        case .neutral:
            return .secondary
        case .correct:
            return .green
        case .incorrect:
            return .red
        }
    }
}

#Preview("Practice iPad") {
    PracticeScreen()
        .frame(width: 1024, height: 760)
}

#Preview("Practice iPhone") {
    PracticeScreen()
        .frame(width: 393, height: 760)
}

#Preview("Feedback States") {
    VStack(spacing: 12) {
        PracticeFeedbackBanner(feedback: .neutral)
        PracticeFeedbackBanner(feedback: .correct(playedPitch: Pitch(.c, octave: 4)))
        PracticeFeedbackBanner(feedback: .incorrect(playedPitch: Pitch(.g, octave: 2)))
    }
    .padding()
}

#Preview("MIDI Status") {
    VStack(alignment: .trailing, spacing: 16) {
        MIDIStatusBadge(isConnected: true, sourceName: "Digital Piano")
        MIDIStatusBadge(isConnected: false, sourceName: nil)
    }
    .padding()
}
