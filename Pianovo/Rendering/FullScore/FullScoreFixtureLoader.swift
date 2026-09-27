import Foundation

enum FullScoreFixture: String, CaseIterable, Identifiable {
    case simpleMelody = "simple-melody"
    case pianoGrandStaff = "piano-grand-staff"
    case chord
    case rests
    case multipleVoices = "multiple-voices"
    case accidentals
    case ties

    var id: String {
        rawValue
    }

    var fileName: String {
        "\(rawValue).musicxml"
    }

    var displayName: String {
        switch self {
        case .simpleMelody:
            "Simple Melody"
        case .pianoGrandStaff:
            "Piano Grand Staff"
        case .chord:
            "Chord"
        case .rests:
            "Rests"
        case .multipleVoices:
            "Multiple Voices"
        case .accidentals:
            "Accidentals"
        case .ties:
            "Ties"
        }
    }
}

struct FullScoreFixtureLoader {
    func musicXML(for fixture: FullScoreFixture) throws -> String {
        let data = try musicXMLData(for: fixture)
        return String(decoding: data, as: UTF8.self)
    }

    func musicXMLData(for fixture: FullScoreFixture) throws -> Data {
        if let bundledURL = Bundle.main.url(forResource: fixture.rawValue, withExtension: "musicxml") {
            return try Data(contentsOf: bundledURL)
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PianovoTests")
            .appendingPathComponent("Resources")
            .appendingPathComponent("MusicXML")
            .appendingPathComponent(fixture.fileName)

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw FullScoreRenderingError.missingFixture(fixture.fileName)
        }

        return try Data(contentsOf: sourceURL)
    }
}
