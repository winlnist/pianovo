import Testing
@testable import Pianovo

struct AppBrandTests {
    @Test func pianovoWorkingBrandCopyIsCentralized() {
        #expect(AppBrand.displayName == "Pianovo")
        #expect(AppBrand.tagline == "Practice measured. Progress earned.")
    }

    @Test func appDestinationsHaveStableOrderAndIdentifiers() {
        #expect(AppDestination.allCases.map(\.id) == [
            "today",
            "practice",
            "progress",
            "library",
            "history",
            "askMyTeacher",
            "settings"
        ])

        #expect(AppDestination.allCases.map(\.title) == [
            "Today",
            "Practice",
            "Progress",
            "Library",
            "History",
            "Ask My Teacher",
            "Settings"
        ])
    }
}
