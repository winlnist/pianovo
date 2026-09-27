import SwiftUI

struct FullScoreDebugView: View {
    @State private var selectedFixture: FullScoreFixture = .pianoGrandStaff
    @State private var selectedPage = 1
    @State private var renderResult: FullScoreRenderResult?
    @State private var errorMessage: String?

    private let fixtureLoader = FullScoreFixtureLoader()

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            Group {
                if let renderResult {
                    ScrollView([.vertical, .horizontal]) {
                        FullScoreSVGView(svg: renderResult.svg)
                            .frame(width: 900)
                            .background(Color.white)
                            .padding()
                    }
                    .background(Color(white: 0.92))
                } else if let errorMessage {
                    ContentUnavailableView("Score Render Failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            renderSelectedFixture()
        }
        .onChange(of: selectedFixture) { _, _ in
            selectedPage = 1
            renderSelectedFixture()
        }
        .onChange(of: selectedPage) { _, _ in
            renderSelectedFixture()
        }
    }

    private var toolbar: some View {
        HStack {
            Picker("Fixture", selection: $selectedFixture) {
                ForEach(FullScoreFixture.allCases) { fixture in
                    Text(fixture.displayName).tag(fixture)
                }
            }

            Spacer()

            if let renderResult {
                Stepper(
                    "Page \(selectedPage) of \(renderResult.pageCount)",
                    value: $selectedPage,
                    in: 1...max(1, renderResult.pageCount)
                )
                .fixedSize()

                Text("\(renderResult.verovioVersion) - \(renderResult.renderDuration.formatted(.number.precision(.fractionLength(3))))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func renderSelectedFixture() {
        do {
            let musicXML = try fixtureLoader.musicXML(for: selectedFixture)
            _ = try MusicXMLImporter().importScore(from: musicXML)
            let renderer = try VerovioScoreRenderer()
            let result = try renderer.render(musicXML: musicXML, pageNumber: selectedPage)
            renderResult = result
            errorMessage = nil
        } catch {
            renderResult = nil
            errorMessage = "\(error)"
        }
    }
}

#Preview("Full Score Debug") {
    FullScoreDebugView()
}
