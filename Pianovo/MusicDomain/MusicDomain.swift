nonisolated enum PitchLetter: String, CaseIterable, Codable, Hashable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case f = "F"
    case g = "G"

    var naturalSemitoneOffsetFromC: Int {
        switch self {
        case .c: 0
        case .d: 2
        case .e: 4
        case .f: 5
        case .g: 7
        case .a: 9
        case .b: 11
        }
    }

    var diatonicOffsetFromC: Int {
        switch self {
        case .c: 0
        case .d: 1
        case .e: 2
        case .f: 3
        case .g: 4
        case .a: 5
        case .b: 6
        }
    }
}

nonisolated enum Accidental: String, Codable, Hashable {
    case unspecified
    case natural
    case sharp
    case flat
    case doubleSharp
    case doubleFlat

    var semitoneOffset: Int {
        switch self {
        case .unspecified, .natural: 0
        case .sharp: 1
        case .flat: -1
        case .doubleSharp: 2
        case .doubleFlat: -2
        }
    }
}

nonisolated struct Pitch: Codable, Hashable {
    let letter: PitchLetter
    let accidental: Accidental
    let octave: Int

    init(_ letter: PitchLetter, accidental: Accidental = .natural, octave: Int) {
        self.letter = letter
        self.accidental = accidental
        self.octave = octave
    }

    var midiNoteNumber: Int {
        ((octave + 1) * 12) + letter.naturalSemitoneOffsetFromC + accidental.semitoneOffset
    }

    var diatonicIndex: Int {
        (octave * 7) + letter.diatonicOffsetFromC
    }

    init?(midiNoteNumber: Int) {
        guard (0...127).contains(midiNoteNumber) else {
            return nil
        }

        let octave = (midiNoteNumber / 12) - 1

        switch midiNoteNumber % 12 {
        case 0: self.init(.c, octave: octave)
        case 1: self.init(.c, accidental: .sharp, octave: octave)
        case 2: self.init(.d, octave: octave)
        case 3: self.init(.d, accidental: .sharp, octave: octave)
        case 4: self.init(.e, octave: octave)
        case 5: self.init(.f, octave: octave)
        case 6: self.init(.f, accidental: .sharp, octave: octave)
        case 7: self.init(.g, octave: octave)
        case 8: self.init(.g, accidental: .sharp, octave: octave)
        case 9: self.init(.a, octave: octave)
        case 10: self.init(.a, accidental: .sharp, octave: octave)
        case 11: self.init(.b, octave: octave)
        default: return nil
        }
    }
}

nonisolated extension Pitch: Comparable {
    static func < (lhs: Pitch, rhs: Pitch) -> Bool {
        if lhs.midiNoteNumber != rhs.midiNoteNumber {
            return lhs.midiNoteNumber < rhs.midiNoteNumber
        }

        if lhs.octave != rhs.octave {
            return lhs.octave < rhs.octave
        }

        if lhs.letter.diatonicOffsetFromC != rhs.letter.diatonicOffsetFromC {
            return lhs.letter.diatonicOffsetFromC < rhs.letter.diatonicOffsetFromC
        }

        return lhs.accidental.semitoneOffset < rhs.accidental.semitoneOffset
    }
}

nonisolated struct PitchRange: Codable, Hashable {
    let lowerBound: Pitch
    let upperBound: Pitch

    init?(lowerBound: Pitch, upperBound: Pitch) {
        guard lowerBound <= upperBound else {
            return nil
        }

        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    var pitches: [Pitch] {
        (lowerBound.midiNoteNumber...upperBound.midiNoteNumber).compactMap(Pitch.init(midiNoteNumber:))
    }

    func contains(_ pitch: Pitch) -> Bool {
        lowerBound <= pitch && pitch <= upperBound
    }
}

nonisolated enum Clef: String, Codable, Hashable {
    case treble
    case bass
}

nonisolated struct StaffPosition: Codable, Hashable {
    let clef: Clef
    let stepFromBottomLine: Int

    init(clef: Clef, pitch: Pitch) {
        self.clef = clef

        let bottomLineDiatonicIndex: Int
        switch clef {
        case .treble:
            bottomLineDiatonicIndex = Pitch(.e, octave: 4).diatonicIndex
        case .bass:
            bottomLineDiatonicIndex = Pitch(.g, octave: 2).diatonicIndex
        }

        stepFromBottomLine = pitch.diatonicIndex - bottomLineDiatonicIndex
    }

    var ledgerLines: LedgerLines {
        LedgerLines(staffPosition: self)
    }
}

nonisolated struct LedgerLines: Codable, Hashable {
    let belowStaff: Int
    let aboveStaff: Int

    init(staffPosition: StaffPosition) {
        if staffPosition.stepFromBottomLine < -1 {
            belowStaff = -staffPosition.stepFromBottomLine / 2
        } else {
            belowStaff = 0
        }

        if staffPosition.stepFromBottomLine > 9 {
            aboveStaff = (staffPosition.stepFromBottomLine - 8) / 2
        } else {
            aboveStaff = 0
        }
    }
}

nonisolated struct GrandStaffPlacement: Codable, Hashable {
    let clef: Clef
    let staffPosition: StaffPosition

    init(pitch: Pitch, preferredClef: Clef? = nil) {
        let clef = preferredClef ?? GrandStaffPlacement.defaultClef(for: pitch)
        self.clef = clef
        staffPosition = StaffPosition(clef: clef, pitch: pitch)
    }

    static func defaultClef(for pitch: Pitch) -> Clef {
        pitch >= Pitch(.c, octave: 4) ? .treble : .bass
    }
}

nonisolated struct MusicEventID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}
