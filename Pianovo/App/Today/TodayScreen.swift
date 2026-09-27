import SwiftUI

struct TodayScreen: View {
    @StateObject private var viewModel: TodayViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: TodayViewModel(dependencies: dependencies))
    }

    init(viewModel: TodayViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch viewModel.state {
                    case .idle, .loading:
                        ProgressView("Loading your programme…")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    case .programmeNotStarted(let programme):
                        welcome(programme)
                    case .loaded(let day):
                        TodayDayView(
                            day: day,
                            usesColumns: geometry.size.width >= 780 && !dynamicTypeSize.isAccessibilitySize
                        )
                    case .noProgrammeAvailable(let failure), .failure(let failure):
                        failureView(failure)
                    }
                }
                .padding(24)
                .frame(maxWidth: 1200, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private func welcome(_ programme: TodayProgrammeSummary) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Pianovo", systemImage: "music.note")
                .font(.title.bold())
            Text("A little structure for your practice")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(programme.title)
                .font(.headline)
            Text("A 12-week piano practice programme with morning and evening work, plus a weekly day for recovery and reflection.")
            Label("Begin at Week 1, Day 1", systemImage: "calendar")
                .font(.headline)
            Text("Your starting Beyer assignment is Op. 101 No. 63. Seconda and Prima are both required parts of this one exercise.")
            Text("Start when you are ready. Your programme position stays where you left it; the calendar does not move you forward.")
                .foregroundStyle(.secondary)
            if case .failed(let failure) = viewModel.startState {
                Label(startFailureMessage(failure), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Programme start failed. \(startFailureMessage(failure))")
            }
            Button {
                Task { await viewModel.startProgramme() }
            } label: {
                HStack {
                    if viewModel.startState == .starting {
                        ProgressView()
                    }
                    Text(viewModel.startState == .starting ? "Starting Programme…" : "Start Programme")
                        .font(.headline)
                }
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.startState == .starting)
            .accessibilityHint("Saves your starting programme position. Does not record a practice session.")
            Text("Reference documents cannot be opened here yet. You can still use the Practice destination at any time.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .todayCard()
    }

    private func startFailureMessage(_ failure: TodayStartFailure) -> String {
        switch failure {
        case .progressSaveFailed:
            "Your starting position could not be saved. Tap Start Programme to try again."
        case .progressLoadFailed:
            "Your existing progress could not be checked. Please retry before starting."
        case .persistenceUnavailable:
            "Saved progress is unavailable. Close and reopen Pianovo to try again."
        case .programmeDefinitionUnavailable:
            "The programme is not available in this version."
        }
    }

    private func failureView(_ failure: TodayLoadingFailure) -> some View {
        ContentUnavailableView {
            Label(failure.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            if failure.canRetry {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
            }
        }
    }
}

private struct TodayDayView: View {
    let day: TodayLoadedState
    let usesColumns: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(day.programme.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(day.weekTitle) · \(day.dayTitle)")
                    .font(.largeTitle.bold())
                    .accessibilityLabel("Programme position: \(day.weekTitle), \(day.dayTitle)")
                    .accessibilityAddTraits(.isHeader)
                Label(
                    day.dayKind == .recoveryReflection ? "Recovery and reflection" : "Your practice day",
                    systemImage: day.dayKind == .recoveryReflection ? "leaf" : "music.note"
                )
                .font(.title2.weight(.semibold))
                Text(day.dayKind == .recoveryReflection
                     ? "Make room to rest and reflect on what felt steady and what needs attention next."
                     : "Work at your own pace. Morning and evening plans stay available throughout the day.")
                Text("This is your saved programme position. It does not advance with the calendar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .todayCard()

            if day.hasPartialReferenceMaterialAvailability {
                Label("Some reference materials are unavailable. Your assignments are still shown below.",
                      systemImage: "doc.badge.ellipsis")
                    .font(.callout)
            }

            if day.dayKind == .recoveryReflection {
                TodayBlockSection(title: "Recovery and reflection", symbol: "leaf", blocks: day.recoveryBlocks)
            } else if usesColumns {
                HStack(alignment: .top, spacing: 24) {
                    morning
                    evening
                }
            } else {
                morning
                evening
            }
            Text("This page shows your plan and any saved status. Recording sessions, completing assignments, and opening documents will come in a later milestone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var morning: some View {
        TodayBlockSection(title: "Morning", symbol: "sun.max", blocks: day.morningBlocks)
    }

    private var evening: some View {
        TodayBlockSection(title: "Evening", symbol: "moon", blocks: day.eveningBlocks)
    }
}

private struct TodayBlockSection: View {
    let title: String
    let symbol: String
    let blocks: [TodayPracticeBlockState]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(blocks) { block in
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(block.title)
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        Label("\(block.targetDurationMinutes) minutes planned", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if block.isSuggested {
                            Label("Suggested for this time of day", systemImage: "sparkle")
                                .font(.caption)
                        }
                    }
                    ForEach(block.assignments) { assignment in
                        TodayAssignmentView(assignment: assignment)
                    }
                }
                .todayCard()
            }
            if blocks.isEmpty {
                Text("No work planned for this part of the day.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayAssignmentView: View {
    let assignment: TodayAssignmentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(assignment.sourceTitle)
                .font(.headline)
            Text(assignment.goal)
            Label(completionText, systemImage: completionSymbol)
                .font(.subheadline)
                .accessibilityLabel("Assignment status: \(completionText)")
            if let mastery = assignment.masteryState {
                Label(mastery.title, systemImage: "chart.bar")
                    .font(.subheadline)
                    .accessibilityLabel("Mastery state: \(mastery.title)")
            }
            material
        }
    }

    private var completionText: String {
        switch assignment.completionStatus {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .completed: "Completed"
        }
    }

    private var completionSymbol: String {
        switch assignment.completionStatus {
        case .notStarted: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .completed: "checkmark.circle"
        }
    }

    @ViewBuilder
    private var material: some View {
        switch assignment.referenceMaterial {
        case .unknownSource:
            Label("No linked reference material", systemImage: "doc")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Material availability: no linked reference material")
        case .knownUnavailable(let summary, let reason):
            materialSummary(summary, availability: reason.title, symbol: "doc.badge.ellipsis")
        case .available(let summary):
            materialSummary(summary, availability: "Material available; opening is not supported here yet", symbol: "doc")
        }
    }

    private func materialSummary(_ summary: TodayReferenceMaterialSummary, availability: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(summary.title).font(.subheadline.weight(.medium))
            Label(availability, systemImage: symbol)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Material availability: \(availability)")
            ForEach(summary.components) { component in
                Text("\(component.role.title)\(component.isRequiredForCompleteExercise ? " · Required" : "")")
                    .font(.subheadline)
            }
            if summary.components.contains(where: \.isRequiredForCompleteExercise) {
                Text("Required parts belong to this one exercise, not separate progression steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension View {
    func todayCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension MasteryState {
    var title: String {
        switch self {
        case .learning: "Learning"
        case .stabilizing: "Stabilising"
        case .nearlyMastered: "Nearly mastered"
        case .mastered: "Mastered"
        }
    }
}

private extension ReferenceMaterialComponentRole {
    var title: String {
        switch self {
        case .seconda: "Seconda"
        case .prima: "Prima"
        case .fullDocument: "Full document"
        case .pageRange: "Selected pages"
        case .audioTrack: "Audio track"
        }
    }
}

private extension DocumentUnavailableReason {
    var title: String {
        switch self {
        case .notImported: "Document unavailable · not imported"
        case .accessNotGranted: "Document unavailable · access not granted"
        case .missing: "Document unavailable · missing"
        }
    }
}

private extension TodayLoadingFailure {
    var title: String {
        switch self {
        case .persistenceUnavailable: "Saved progress unavailable"
        case .invalidPersistedPosition: "Programme position unavailable"
        case .programmeDefinitionUnavailable: "No programme available"
        case .progressLoadFailed, .masteryLoadFailed, .unknown: "Today could not be loaded"
        }
    }

    var message: String {
        switch self {
        case .persistenceUnavailable:
            "Close and reopen Pianovo to try again. Your saved progress will not be reset."
        case .invalidPersistedPosition:
            "Your saved week or day could not be found in this programme. Retry to check again; your position will not be reset."
        case .programmeDefinitionUnavailable:
            "The programme definition is unavailable in this version of Pianovo. Practice remains available from navigation."
        case .progressLoadFailed:
            "Your saved progress could not be read. Please try again."
        case .masteryLoadFailed:
            "Your saved mastery information could not be read. Please try again."
        case .unknown:
            "Please try loading your programme again."
        }
    }

    var canRetry: Bool {
        switch self {
        case .persistenceUnavailable, .programmeDefinitionUnavailable: false
        default: true
        }
    }
}
