import Foundation

struct FullScoreRenderConfiguration: Hashable {
    let pageWidth: Int
    let pageHeight: Int
    let scale: Int
    let pageMarginTop: Int
    let pageMarginRight: Int
    let pageMarginBottom: Int
    let pageMarginLeft: Int

    init(
        pageWidth: Int = 1800,
        pageHeight: Int = 2400,
        scale: Int = 42,
        pageMarginTop: Int = 50,
        pageMarginRight: Int = 50,
        pageMarginBottom: Int = 50,
        pageMarginLeft: Int = 50
    ) {
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.scale = scale
        self.pageMarginTop = pageMarginTop
        self.pageMarginRight = pageMarginRight
        self.pageMarginBottom = pageMarginBottom
        self.pageMarginLeft = pageMarginLeft
    }

    var jsonOptions: String {
        """
        {
          "pageWidth": \(pageWidth),
          "pageHeight": \(pageHeight),
          "scale": \(scale),
          "pageMarginTop": \(pageMarginTop),
          "pageMarginRight": \(pageMarginRight),
          "pageMarginBottom": \(pageMarginBottom),
          "pageMarginLeft": \(pageMarginLeft)
        }
        """
    }
}

struct FullScoreRenderResult: Hashable {
    let svg: String
    let pageNumber: Int
    let pageCount: Int
    let verovioVersion: String
    let renderDuration: TimeInterval
}

enum FullScoreRenderingError: Error, Equatable {
    case missingFixture(String)
    case emptyMusicXMLInput
    case invalidMusicXMLInput(String)
    case resourcePathUnavailable
    case resourcePathRejected(String)
    case optionConfigurationFailed(String)
    case loadFailed(String)
    case invalidPage(requested: Int, pageCount: Int)
    case emptyRenderOutput(page: Int)
}
