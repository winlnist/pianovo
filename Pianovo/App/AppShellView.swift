import SwiftUI

struct AppShellView: View {
    let dependencies: AppDependencies
    @State private var selectedDestination: AppDestination? = .today

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: $selectedDestination) { destination in
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
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selectedDestination ?? .today {
        case .practice:
            PracticeScreen()
        case .today:
            TodayScreen(dependencies: dependencies)
        case .progress, .library, .history, .askMyTeacher, .settings:
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
