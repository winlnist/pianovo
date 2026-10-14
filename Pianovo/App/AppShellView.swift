import SwiftUI

struct AppShellView: View {
    let dependencies: AppDependencies
    @State private var assignmentPractice: AssignmentPracticeContext?
    @State private var selectedDestination: AppDestination? = .today
    @AppStorage("pianovo.hasSeenGettingStarted.v1") private var hasSeenGettingStarted = false
    @State private var showsGettingStarted = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationSplitView {
            List(AppDestination.availableDestinations, selection: $selectedDestination) { destination in
                Label(destination.title, systemImage: destination.systemImageName)
                    .tag(destination)
            }
            .navigationTitle(AppBrand.displayName)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Text(AppBrand.tagline)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } detail: {
            destinationView
                .navigationTitle((selectedDestination ?? .today).title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Getting started", systemImage: "questionmark.circle") {
                            showsGettingStarted = true
                        }
                        .accessibilityHint("Shows piano connection and local programme guidance.")
                    }
                }
        }
        .task { if !hasSeenGettingStarted { showsGettingStarted = true } }
        .sheet(isPresented: $showsGettingStarted, onDismiss: { hasSeenGettingStarted = true }) {
            GettingStartedScreen { destination in
                if let destination { selectedDestination = destination }
                showsGettingStarted = false
            }
        }
        .fullScreenCover(item: $assignmentPractice) { context in
            AssignmentPracticeScreen(context: context, dependencies: dependencies)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selectedDestination ?? .today {
        case .practice:
            PracticeScreen()
        case .today:
            TodayProgrammeScreen(dependencies: dependencies) { context in
                guard assignmentPractice == nil else { return }
                assignmentPractice = context
            }
        case .library:
            LibraryScreen(dependencies: dependencies) { selectedDestination = .today }
        case .history:
            HistoryScreen(dependencies: dependencies)
        case .progress, .askMyTeacher, .settings:
            ComingSoonView(destination: selectedDestination ?? .today)
        }
    }
}

private struct ComingSoonView: View {
    let destination: AppDestination

    var body: some View {
        ContentUnavailableView {
            Label(destination.title, systemImage: destination.systemImageName)
        } description: {
            Text("Coming in a later milestone.")
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    AppShellView(dependencies: .preview())
}
