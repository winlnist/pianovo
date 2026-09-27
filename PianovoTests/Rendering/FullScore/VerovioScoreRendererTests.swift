import Testing
@testable import Pianovo

struct VerovioScoreRendererTests {
    @Test func rendererInitializesSuccessfully() throws {
        let renderer = try VerovioScoreRenderer()

        #expect(!renderer.verovioVersion.isEmpty)
    }

    @Test func validMusicXMLProducesNonEmptySVGOutput() throws {
        let musicXML = try FullScoreFixtureLoader().musicXML(for: .simpleMelody)
        let result = try VerovioScoreRenderer().render(musicXML: musicXML)

        #expect(result.pageNumber == 1)
        #expect(result.pageCount >= 1)
        #expect(result.svg.contains("<svg"))
        #expect(result.svg.count > 500)
        #expect(!result.verovioVersion.isEmpty)
        #expect(result.renderDuration >= 0)
    }

    @Test func simpleMelodyFixtureRenders() throws {
        let result = try renderFixture(.simpleMelody)

        #expect(result.pageCount >= 1)
        #expect(result.svg.contains("<svg"))
    }

    @Test func pianoGrandStaffFixtureRenders() throws {
        let result = try renderFixture(.pianoGrandStaff)

        #expect(result.pageCount >= 1)
        #expect(result.svg.contains("<svg"))
    }

    @Test func supportedFixturesRenderNonEmptySVG() throws {
        for fixture in FullScoreFixture.allCases {
            let result = try renderFixture(fixture)

            #expect(result.pageNumber == 1)
            #expect(result.pageCount >= 1)
            #expect(result.svg.contains("<svg"))
            #expect(result.svg.count > 500)
        }
    }

    @Test func sameFixtureImportsToScoreDomainAndRendersWithVerovio() throws {
        let musicXML = try FullScoreFixtureLoader().musicXML(for: .pianoGrandStaff)
        let score = try MusicXMLImporter().importScore(from: musicXML)
        let renderResult = try VerovioScoreRenderer().render(musicXML: musicXML)

        #expect(score.parts.count == 1)
        #expect(score.parts.first?.staves.map(\.initialClef) == [.treble, .bass])
        #expect(renderResult.svg.contains("<svg"))
        #expect(renderResult.pageCount >= 1)
    }

    @Test func malformedMusicXMLReturnsRenderingError() throws {
        do {
            _ = try VerovioScoreRenderer().render(musicXML: "<score-partwise><part></score-partwise>")
            Issue.record("Expected malformed MusicXML to fail rendering.")
        } catch FullScoreRenderingError.invalidMusicXMLInput(let message) {
            #expect(!message.isEmpty)
        }
    }

    @Test func invalidPageReturnsRenderingError() throws {
        let musicXML = try FullScoreFixtureLoader().musicXML(for: .simpleMelody)

        do {
            _ = try VerovioScoreRenderer().render(musicXML: musicXML, pageNumber: 99)
            Issue.record("Expected invalid page to fail rendering.")
        } catch FullScoreRenderingError.invalidPage(let requested, let pageCount) {
            #expect(requested == 99)
            #expect(pageCount >= 1)
        }
    }

    @Test func emptyMusicXMLInputReturnsRenderingError() throws {
        #expect(throws: FullScoreRenderingError.emptyMusicXMLInput) {
            _ = try VerovioScoreRenderer().render(musicXML: "   ")
        }
    }

    private func renderFixture(_ fixture: FullScoreFixture) throws -> FullScoreRenderResult {
        let musicXML = try FullScoreFixtureLoader().musicXML(for: fixture)
        return try VerovioScoreRenderer().render(musicXML: musicXML)
    }
}
