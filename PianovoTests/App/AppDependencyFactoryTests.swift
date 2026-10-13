import SwiftUI
import Testing
@testable import Pianovo

@MainActor
struct AppDependencyFactoryTests {
    @Test func productionDependenciesRetainModelContainer() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies(makeLibraryContainer: {
            try LibraryModelContainerFactory.makeContainer(inMemory: true)
        }, makeContainer: {
            try PracticeHistoryModelContainerFactory.makeContainer(inMemory: true)
        })

        #expect(dependencies.persistenceStatus == .available)
        #expect(dependencies.progressRepository != nil)
        #expect(dependencies.practiceHistoryRepository != nil)
        #expect(dependencies.retainsProductionModelContainer)
    }

    @Test func bootstrapFailureDoesNotSelectInMemoryPersistence() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies(makeLibraryContainer: {
            try LibraryModelContainerFactory.makeContainer(inMemory: true)
        }, makeContainer: {
            throw BootstrapFailure()
        })

        #expect(dependencies.persistenceStatus == .unavailable)
        #expect(dependencies.progressRepository == nil)
        #expect(dependencies.practiceHistoryRepository == nil)
        #expect(!dependencies.retainsProductionModelContainer)
    }

    @Test func libraryBootstrapFailureLeavesTodayAndPracticeAvailable() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies(
            makeLibraryContainer: { throw BootstrapFailure() },
            makeContainer: { try PracticeHistoryModelContainerFactory.makeContainer(inMemory: true) }
        )
        #expect(dependencies.persistenceStatus == .available)
        #expect(dependencies.progressRepository != nil)
        #expect(dependencies.libraryPersistenceStatus == .unavailable)
        #expect(dependencies.libraryRepository == nil)
        #expect(!dependencies.retainsLibraryModelContainer)
        _ = LibraryScreen(dependencies: dependencies)
    }

    @Test func historyBootstrapFailureLeavesDurableLibraryAvailable() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies(
            makeLibraryContainer: { try LibraryModelContainerFactory.makeContainer(inMemory: true) },
            makeContainer: { throw BootstrapFailure() }
        )
        #expect(dependencies.persistenceStatus == .unavailable)
        #expect(dependencies.libraryPersistenceStatus == .available)
        #expect(dependencies.libraryRepository != nil)
        #expect(dependencies.retainsLibraryModelContainer)
        #expect(!dependencies.retainsProductionModelContainer)
    }

    @Test func bootstrapFailureStillAllowsPracticeDestinationConstruction() throws {
        let dependencies = AppDependencyFactory.makeProductionDependencies(makeLibraryContainer: {
            try LibraryModelContainerFactory.makeContainer(inMemory: true)
        }, makeContainer: {
            throw BootstrapFailure()
        })

        let shell = AppShellView(dependencies: dependencies)

        #expect(shell.dependencies.persistenceStatus == .unavailable)
    }
}

private struct BootstrapFailure: Error {}
