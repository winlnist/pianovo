import Foundation
import VerovioToolkit

final class VerovioScoreRenderer {
    private let toolkit: VerovioToolkit
    private let configuration: FullScoreRenderConfiguration

    init(configuration: FullScoreRenderConfiguration = FullScoreRenderConfiguration()) throws {
        self.configuration = configuration
        toolkit = VerovioToolkit()

        guard let resourceURL = VerovioResources.bundle.url(forResource: "data", withExtension: nil) else {
            throw FullScoreRenderingError.resourcePathUnavailable
        }

        let resourcePath = resourceURL.path
        guard toolkit.setResourcePath(resourcePath) else {
            throw FullScoreRenderingError.resourcePathRejected(resourcePath)
        }

        guard toolkit.setOptions(configuration.jsonOptions) else {
            throw FullScoreRenderingError.optionConfigurationFailed(configuration.jsonOptions)
        }
    }

    var verovioVersion: String {
        toolkit.getVersion()
    }

    func render(musicXML: String, pageNumber: Int = 1) throws -> FullScoreRenderResult {
        let trimmedMusicXML = musicXML.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMusicXML.isEmpty else {
            throw FullScoreRenderingError.emptyMusicXMLInput
        }
        try validateXMLIsWellFormed(trimmedMusicXML)

        let start = Date()
        toolkit.resetOptions()

        guard toolkit.setOptions(configuration.jsonOptions) else {
            throw FullScoreRenderingError.optionConfigurationFailed(configuration.jsonOptions)
        }

        _ = toolkit.setInputFrom("musicxml")

        guard toolkit.loadData(trimmedMusicXML) else {
            throw FullScoreRenderingError.loadFailed(nonEmptyLog(fallback: "Verovio could not load the MusicXML input."))
        }

        let pageCount = toolkit.getPageCount()
        guard pageCount > 0 else {
            throw FullScoreRenderingError.emptyRenderOutput(page: pageNumber)
        }

        guard (1...pageCount).contains(pageNumber) else {
            throw FullScoreRenderingError.invalidPage(requested: pageNumber, pageCount: pageCount)
        }

        let svg = toolkit.renderToSVG(pageNumber, false)
        guard !svg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FullScoreRenderingError.emptyRenderOutput(page: pageNumber)
        }

        return FullScoreRenderResult(
            svg: svg,
            pageNumber: pageNumber,
            pageCount: pageCount,
            verovioVersion: verovioVersion,
            renderDuration: Date().timeIntervalSince(start)
        )
    }

    private func nonEmptyLog(fallback: String) -> String {
        let log = toolkit.getLog().trimmingCharacters(in: .whitespacesAndNewlines)
        return log.isEmpty ? fallback : log
    }

    private func validateXMLIsWellFormed(_ musicXML: String) throws {
        let parser = XMLParser(data: Data(musicXML.utf8))
        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "The MusicXML input is not well formed XML."
            throw FullScoreRenderingError.invalidMusicXMLInput(message)
        }
    }
}
