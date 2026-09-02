import SwiftUI
import Testing
@testable import Sightlink_Piano

@MainActor
struct AppDependencyFactoryTests {
    @Test func productionDependenciesRetainModelContainer() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies {
            try PracticeHistoryModelContainerFactory.makeContainer(inMemory: true)
        }

        #expect(dependencies.persistenceStatus == .available)
        #expect(dependencies.progressRepository != nil)
        #expect(dependencies.practiceHistoryRepository != nil)
        #expect(dependencies.retainsProductionModelContainer)
    }

    @Test func bootstrapFailureDoesNotSelectInMemoryPersistence() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies {
            throw BootstrapFailure()
        }

        #expect(dependencies.persistenceStatus == .unavailable)
        #expect(dependencies.progressRepository == nil)
        #expect(dependencies.practiceHistoryRepository == nil)
        #expect(!dependencies.retainsProductionModelContainer)
    }

    @Test func bootstrapFailureStillAllowsPracticeDestinationConstruction() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies {
            throw BootstrapFailure()
        }

        let shell = AppShellView(dependencies: dependencies)

        #expect(shell.dependencies.persistenceStatus == .unavailable)
    }
}

private struct BootstrapFailure: Error {}
