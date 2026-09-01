import Foundation

enum MusicXMLImportError: Error, Equatable {
    case malformedXML(String)
    case unsupportedRoot(String)
    case missingParts
    case missingMeasureDuration(String)
    case invalidDuration(String)
    case invalidPitch(String)
    case invalidAccidental(String)
    case invalidTimeSignature(String)
    case invalidKeySignature(String)
    case unsupportedChord(String)
    case invalidCursorOperation(String)
}

struct MusicXMLImporter {
    func importScore(from data: Data, scoreID: ScoreID = "musicxml-import") throws -> Score {
        let delegate = MusicXMLParserDelegate(scoreID: scoreID)
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            if let importError = delegate.importError {
                throw importError
            }

            let message = parser.parserError?.localizedDescription ?? "The MusicXML document could not be parsed."
            throw MusicXMLImportError.malformedXML(message)
        }

        return try delegate.makeScore()
    }

    func importScore(from xmlString: String, scoreID: ScoreID = "musicxml-import") throws -> Score {
        try importScore(from: Data(xmlString.utf8), scoreID: scoreID)
    }
}

private final class MusicXMLParserDelegate: NSObject, XMLParserDelegate {
    private let scoreID: ScoreID
    private(set) var importError: MusicXMLImportError?
    private var rootElement: String?
    private var elementStack: [String] = []
    private var textBuffer = ""

    private var scoreTitle: String?
    private var partNamesByID: [String: String] = [:]
    private var currentScorePartID: String?

    private var parts: [PartBuilder] = []
    private var currentPart: PartBuilder?
    private var currentMeasure: MeasureBuilder?
    private var currentNote: NoteBuilder?
    private var currentCursorMove: CursorMoveBuilder?
    private var currentClef: ClefBuilder?

    init(scoreID: ScoreID) {
        self.scoreID = scoreID
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if rootElement == nil {
            rootElement = elementName
        }

        elementStack.append(elementName)
        textBuffer = ""

        switch elementName {
        case "score-part":
            currentScorePartID = attributeDict["id"]
        case "part":
            if let id = attributeDict["id"] {
                currentPart = PartBuilder(id: id, name: partNamesByID[id])
            }
        case "measure":
            let fallbackNumber = (currentPart?.measures.count ?? 0) + 1
            let numberText = attributeDict["number"] ?? "\(fallbackNumber)"
            let number = Int(numberText) ?? fallbackNumber
            currentMeasure = MeasureBuilder(number: number)
        case "note":
            currentNote = NoteBuilder()
        case "backup":
            currentCursorMove = CursorMoveBuilder(direction: .backup)
        case "forward":
            currentCursorMove = CursorMoveBuilder(direction: .forward)
        case "chord":
            currentNote?.isChordTone = true
        case "rest":
            currentNote?.isRest = true
        case "tie":
            if var note = currentNote {
                note.tieState = note.tieState.combined(with: TieState(musicXMLType: attributeDict["type"]))
                currentNote = note
            }
        case "clef":
            let number = Int(attributeDict["number"] ?? "") ?? 1
            currentClef = ClefBuilder(staffID: StaffID(rawValue: number))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "work-title", "movement-title":
            if !text.isEmpty, scoreTitle == nil {
                scoreTitle = text
            }
        case "part-name":
            if let id = currentScorePartID, !text.isEmpty {
                partNamesByID[id] = text
            }
        case "score-part":
            currentScorePartID = nil
        case "divisions":
            if let divisions = Int(text), divisions > 0 {
                currentPart?.divisions = divisions
            }
        case "beats":
            currentMeasure?.timeSignatureNumerator = Int(text)
        case "beat-type":
            currentMeasure?.timeSignatureDenominator = Int(text)
        case "fifths":
            currentMeasure?.keyFifths = Int(text)
        case "mode":
            currentMeasure?.keyMode = KeyMode(rawValue: text)
        case "sign":
            currentClef?.sign = text
        case "line":
            currentClef?.line = Int(text)
        case "clef":
            if let clefBuilder = currentClef, let clef = clefBuilder.clef {
                currentPart?.register(clef: clef, for: clefBuilder.staffID)
            }
            currentClef = nil
        case "step":
            currentNote?.step = text
        case "alter":
            currentNote?.alter = Int(text)
        case "octave":
            currentNote?.octave = Int(text)
        case "duration":
            if currentCursorMove != nil {
                currentCursorMove?.durationUnits = Int(text)
            } else {
                currentNote?.durationUnits = Int(text)
            }
        case "voice":
            if !text.isEmpty {
                currentNote?.voiceID = VoiceID(rawValue: text)
            }
        case "staff":
            if let staffNumber = Int(text) {
                currentNote?.staffID = StaffID(rawValue: staffNumber)
            }
        case "dot":
            currentNote?.dotCount += 1
        case "note":
            if let note = currentNote {
                currentMeasure?.items.append(.note(note))
            }
            currentNote = nil
        case "backup", "forward":
            if let cursorMove = currentCursorMove {
                currentMeasure?.items.append(.cursorMove(cursorMove))
            }
            currentCursorMove = nil
        case "measure":
            if let measureBuilder = currentMeasure, var part = currentPart {
                do {
                    let measure = try measureBuilder.makeMeasure(partID: part.id, part: &part)
                    part.measures.append(measure)
                    currentPart = part
                } catch {
                    importError = error as? MusicXMLImportError ?? .malformedXML("\(error)")
                    parser.abortParsing()
                }
            }
            currentMeasure = nil
        case "part":
            if let part = currentPart {
                parts.append(part)
            }
            currentPart = nil
        default:
            break
        }

        if elementStack.last == elementName {
            _ = elementStack.popLast()
        }
        textBuffer = ""
    }

    func makeScore() throws -> Score {
        guard rootElement == "score-partwise" else {
            throw MusicXMLImportError.unsupportedRoot(rootElement ?? "missing root element")
        }

        guard !parts.isEmpty else {
            throw MusicXMLImportError.missingParts
        }

        return Score(
            id: scoreID,
            title: scoreTitle,
            parts: parts.map { $0.makePart() }
        )
    }
}

private struct PartBuilder {
    let id: String
    let name: String?
    var divisions = 1
    var activeTimeSignature = TimeSignature.commonTime
    var activeKeySignature: KeySignature?
    var measures: [ScoreMeasure] = []
    private var stavesByID: [StaffID: ScoreStaff] = [:]

    init(id: String, name: String?) {
        self.id = id
        self.name = name
    }

    mutating func register(clef: Clef, for staffID: StaffID) {
        guard stavesByID[staffID] == nil else {
            let existing = stavesByID[staffID]!
            stavesByID[staffID] = ScoreStaff(
                id: existing.id,
                initialClef: existing.initialClef,
                clefChanges: existing.clefChanges + [ClefChange(position: .start, clef: clef)]
            )
            return
        }

        stavesByID[staffID] = ScoreStaff(id: staffID, initialClef: clef)
    }

    mutating func ensureStaff(_ staffID: StaffID) {
        guard stavesByID[staffID] == nil else {
            return
        }

        stavesByID[staffID] = ScoreStaff(id: staffID, initialClef: staffID.rawValue == 2 ? .bass : .treble)
    }

    func makePart() -> ScorePart {
        ScorePart(
            id: ScorePartID(rawValue: id),
            name: name,
            staves: stavesByID.values.sorted { $0.id < $1.id },
            measures: measures
        )
    }
}

private struct MeasureBuilder {
    let number: Int
    var timeSignatureNumerator: Int?
    var timeSignatureDenominator: Int?
    var keyFifths: Int?
    var keyMode: KeyMode?
    var items: [MeasureItem] = []

    func makeMeasure(partID: String, part: inout PartBuilder) throws -> ScoreMeasure {
        let measureID = ScoreMeasureID(rawValue: "\(partID)-measure-\(number)")
        let timeSignature = try makeTimeSignature(fallback: part.activeTimeSignature)
        part.activeTimeSignature = timeSignature
        let keySignature = try makeKeySignature(fallback: part.activeKeySignature)
        part.activeKeySignature = keySignature
        var cursor = MusicalPosition.start
        var events: [ScoreEvent] = []
        var eventCounter = 0

        for item in items {
            switch item {
            case .note(let note):
                let duration = try note.makeDuration(divisions: part.divisions)
                let position = cursor
                part.ensureStaff(note.staffID)

                if note.isChordTone {
                    try appendChordTone(note, duration: duration, events: &events)
                    continue
                }

                eventCounter += 1
                let eventID = ScoreEventID(rawValue: "\(measureID.rawValue)-event-\(eventCounter)")

                let event: ScoreEvent
                if note.isRest {
                    event = .rest(
                        id: eventID,
                        position: position,
                        duration: duration,
                        staffID: note.staffID,
                        voiceID: note.voiceID
                    )
                } else {
                    event = .note(
                        id: eventID,
                        pitch: try note.makePitch(),
                        position: position,
                        duration: duration,
                        staffID: note.staffID,
                        voiceID: note.voiceID,
                        tie: note.tieState
                    )
                }

                events.append(event)
                cursor = position + duration
            case .cursorMove(let cursorMove):
                cursor = try cursorMove.apply(to: cursor, divisions: part.divisions)
            }
        }

        return ScoreMeasure(
            id: measureID,
            number: number,
            timeSignature: timeSignature,
            keySignature: keySignature,
            events: events
        )
    }

    private func appendChordTone(
        _ note: NoteBuilder,
        duration: MusicalDuration,
        events: inout [ScoreEvent]
    ) throws {
        guard let existingIndex = events.indices.last,
              events[existingIndex].staffID == note.staffID,
              events[existingIndex].voiceID == note.voiceID,
              events[existingIndex].duration == duration else {
            throw MusicXMLImportError.unsupportedChord("Chord tone appeared before a compatible base note.")
        }

        let pitch = try note.makePitch()
        let existing = events[existingIndex]

        switch existing.content {
        case .note(let scoreNote):
            events[existingIndex] = ScoreEvent.chord(
                id: existing.id,
                pitches: [scoreNote.pitch, pitch],
                position: existing.position,
                duration: existing.duration,
                staffID: existing.staffID,
                voiceID: existing.voiceID,
                tie: scoreNote.tie.combined(with: note.tieState)
            )
        case .chord(let scoreChord):
            events[existingIndex] = ScoreEvent.chord(
                id: existing.id,
                pitches: scoreChord.pitches + [pitch],
                position: existing.position,
                duration: existing.duration,
                staffID: existing.staffID,
                voiceID: existing.voiceID,
                tie: scoreChord.tie.combined(with: note.tieState)
            )
        case .rest:
            throw MusicXMLImportError.unsupportedChord("Chord tone cannot attach to a rest.")
        }
    }

    private func makeTimeSignature(fallback: TimeSignature) throws -> TimeSignature {
        guard let numerator = timeSignatureNumerator, let denominator = timeSignatureDenominator else {
            return fallback
        }

        guard let timeSignature = TimeSignature(numerator: numerator, denominator: denominator) else {
            throw MusicXMLImportError.invalidTimeSignature("\(numerator)/\(denominator)")
        }

        return timeSignature
    }

    private func makeKeySignature(fallback: KeySignature?) throws -> KeySignature? {
        guard let fifths = keyFifths else {
            return fallback
        }

        guard let keySignature = KeySignature(fifths: fifths, mode: keyMode ?? .major) else {
            throw MusicXMLImportError.invalidKeySignature("\(fifths)")
        }

        return keySignature
    }
}

private enum MeasureItem {
    case note(NoteBuilder)
    case cursorMove(CursorMoveBuilder)
}

private enum CursorMoveDirection {
    case backup
    case forward
}

private struct CursorMoveBuilder {
    let direction: CursorMoveDirection
    var durationUnits: Int?

    func apply(to position: MusicalPosition, divisions: Int) throws -> MusicalPosition {
        guard let durationUnits, durationUnits > 0 else {
            throw MusicXMLImportError.invalidCursorOperation("Cursor movement requires a positive duration.")
        }

        guard let movement = MusicalFraction(durationUnits, divisions * 4) else {
            throw MusicXMLImportError.invalidCursorOperation("Invalid cursor movement duration \(durationUnits) with divisions=\(divisions).")
        }

        switch direction {
        case .forward:
            return MusicalPosition(offset: position.offset + movement)
        case .backup:
            let backedUp = position.offset - movement
            guard backedUp.numerator >= 0 else {
                throw MusicXMLImportError.invalidCursorOperation("Backup cannot move before the start of the measure.")
            }

            return MusicalPosition(offset: backedUp)
        }
    }
}

private struct NoteBuilder {
    var isChordTone = false
    var isRest = false
    var step: String?
    var alter: Int?
    var octave: Int?
    var durationUnits: Int?
    var dotCount = 0
    var staffID = StaffID(rawValue: 1)
    var voiceID = VoiceID(rawValue: "1")
    var tieState: TieState = .none

    func makePitch() throws -> Pitch {
        guard let step else {
            throw MusicXMLImportError.invalidPitch("Missing pitch step.")
        }

        guard let letter = PitchLetter(musicXMLStep: step), let octave else {
            throw MusicXMLImportError.invalidPitch(step)
        }

        return Pitch(letter, accidental: try makeAccidental(), octave: octave)
    }

    func makeDuration(divisions: Int) throws -> MusicalDuration {
        guard let durationUnits, durationUnits > 0 else {
            throw MusicXMLImportError.missingMeasureDuration("A supported note or rest needs a positive MusicXML duration.")
        }

        guard let duration = MusicalDuration(durationUnits, divisions * 4) else {
            throw MusicXMLImportError.invalidDuration("\(durationUnits) divisions with divisions=\(divisions)")
        }

        return duration
    }

    private func makeAccidental() throws -> Accidental {
        switch alter ?? 0 {
        case -2:
            return .doubleFlat
        case -1:
            return .flat
        case 0:
            return .natural
        case 1:
            return .sharp
        case 2:
            return .doubleSharp
        case let value:
            throw MusicXMLImportError.invalidAccidental("\(value)")
        }
    }
}

private struct ClefBuilder {
    let staffID: StaffID
    var sign: String?
    var line: Int?

    var clef: Clef? {
        switch sign {
        case "G":
            return .treble
        case "F":
            return .bass
        default:
            return nil
        }
    }
}

private extension MusicalFraction {
    static func - (lhs: MusicalFraction, rhs: MusicalFraction) -> MusicalFraction {
        MusicalFraction(
            (lhs.numerator * rhs.denominator) - (rhs.numerator * lhs.denominator),
            lhs.denominator * rhs.denominator
        )!
    }
}

private extension MusicalPosition {
    init(offset: MusicalFraction) {
        self.init(offset.numerator, offset.denominator)!
    }
}

private extension PitchLetter {
    init?(musicXMLStep: String) {
        switch musicXMLStep {
        case "A":
            self = .a
        case "B":
            self = .b
        case "C":
            self = .c
        case "D":
            self = .d
        case "E":
            self = .e
        case "F":
            self = .f
        case "G":
            self = .g
        default:
            return nil
        }
    }
}

private extension TieState {
    init(musicXMLType: String?) {
        switch musicXMLType {
        case "start":
            self = .starts
        case "stop":
            self = .ends
        default:
            self = .none
        }
    }

    func combined(with other: TieState) -> TieState {
        switch (self, other) {
        case (.none, let value), (let value, .none):
            return value
        case (.starts, .ends), (.ends, .starts), (.continues, _), (_, .continues):
            return .continues
        case (.starts, .starts):
            return .starts
        case (.ends, .ends):
            return .ends
        }
    }
}
