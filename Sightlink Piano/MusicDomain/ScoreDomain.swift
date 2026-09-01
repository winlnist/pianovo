nonisolated struct ScoreID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

nonisolated struct ScorePartID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

nonisolated struct ScoreMeasureID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

typealias ScoreEventID = MusicEventID

nonisolated struct StaffID: RawRepresentable, Codable, Comparable, Hashable, ExpressibleByIntegerLiteral {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(integerLiteral value: Int) {
        rawValue = value
    }

    static func < (lhs: StaffID, rhs: StaffID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated struct VoiceID: RawRepresentable, Codable, Comparable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }

    static func < (lhs: VoiceID, rhs: VoiceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated struct Score: Codable, Hashable {
    let id: ScoreID
    let title: String?
    let parts: [ScorePart]

    init(id: ScoreID, title: String? = nil, parts: [ScorePart]) {
        self.id = id
        self.title = title
        self.parts = parts
    }
}

nonisolated struct ScorePart: Identifiable, Codable, Hashable {
    let id: ScorePartID
    let name: String?
    let staves: [ScoreStaff]
    let measures: [ScoreMeasure]

    init(id: ScorePartID, name: String? = nil, staves: [ScoreStaff], measures: [ScoreMeasure]) {
        self.id = id
        self.name = name
        self.staves = staves
        self.measures = measures
    }
}

nonisolated struct ScoreStaff: Identifiable, Codable, Hashable {
    let id: StaffID
    let initialClef: Clef
    let clefChanges: [ClefChange]

    init(id: StaffID, initialClef: Clef, clefChanges: [ClefChange] = []) {
        self.id = id
        self.initialClef = initialClef
        self.clefChanges = clefChanges
    }
}

nonisolated struct ClefChange: Codable, Hashable {
    let position: MusicalPosition
    let clef: Clef
}

nonisolated struct ScoreMeasure: Identifiable, Codable, Hashable {
    let id: ScoreMeasureID
    let number: Int
    let timeSignature: TimeSignature
    let keySignature: KeySignature?
    let events: [ScoreEvent]

    init(
        id: ScoreMeasureID,
        number: Int,
        timeSignature: TimeSignature,
        keySignature: KeySignature? = nil,
        events: [ScoreEvent]
    ) {
        self.id = id
        self.number = number
        self.timeSignature = timeSignature
        self.keySignature = keySignature
        self.events = events.sorted()
    }
}

nonisolated struct ScoreEvent: Identifiable, Codable, Comparable, Hashable {
    let id: ScoreEventID
    let position: MusicalPosition
    let duration: MusicalDuration
    let staffID: StaffID
    let voiceID: VoiceID
    let content: ScoreEventContent

    init(
        id: ScoreEventID,
        position: MusicalPosition,
        duration: MusicalDuration,
        staffID: StaffID,
        voiceID: VoiceID,
        content: ScoreEventContent
    ) {
        self.id = id
        self.position = position
        self.duration = duration
        self.staffID = staffID
        self.voiceID = voiceID
        self.content = content
    }

    static func note(
        id: ScoreEventID,
        pitch: Pitch,
        position: MusicalPosition,
        duration: MusicalDuration,
        staffID: StaffID,
        voiceID: VoiceID,
        tie: TieState = .none
    ) -> ScoreEvent {
        ScoreEvent(
            id: id,
            position: position,
            duration: duration,
            staffID: staffID,
            voiceID: voiceID,
            content: .note(ScoreNote(pitch: pitch, tie: tie))
        )
    }

    static func chord(
        id: ScoreEventID,
        pitches: [Pitch],
        position: MusicalPosition,
        duration: MusicalDuration,
        staffID: StaffID,
        voiceID: VoiceID,
        tie: TieState = .none
    ) -> ScoreEvent {
        ScoreEvent(
            id: id,
            position: position,
            duration: duration,
            staffID: staffID,
            voiceID: voiceID,
            content: .chord(ScoreChord(pitches: pitches, tie: tie))
        )
    }

    static func rest(
        id: ScoreEventID,
        position: MusicalPosition,
        duration: MusicalDuration,
        staffID: StaffID,
        voiceID: VoiceID
    ) -> ScoreEvent {
        ScoreEvent(
            id: id,
            position: position,
            duration: duration,
            staffID: staffID,
            voiceID: voiceID,
            content: .rest
        )
    }

    static func < (lhs: ScoreEvent, rhs: ScoreEvent) -> Bool {
        if lhs.position != rhs.position {
            return lhs.position < rhs.position
        }

        if lhs.staffID != rhs.staffID {
            return lhs.staffID < rhs.staffID
        }

        if lhs.voiceID != rhs.voiceID {
            return lhs.voiceID < rhs.voiceID
        }

        return lhs.id.rawValue < rhs.id.rawValue
    }
}

nonisolated enum ScoreEventContent: Codable, Hashable {
    case note(ScoreNote)
    case chord(ScoreChord)
    case rest
}

nonisolated struct ScoreNote: Codable, Hashable {
    let pitch: Pitch
    let tie: TieState

    init(pitch: Pitch, tie: TieState = .none) {
        self.pitch = pitch
        self.tie = tie
    }
}

nonisolated struct ScoreChord: Codable, Hashable {
    let pitches: [Pitch]
    let tie: TieState

    init(pitches: [Pitch], tie: TieState = .none) {
        precondition(pitches.count >= 2, "A score chord requires at least two pitches.")
        self.pitches = pitches
        self.tie = tie
    }
}

nonisolated enum TieState: String, Codable, Hashable {
    case none
    case starts
    case continues
    case ends
}

nonisolated struct MusicalDuration: Codable, Comparable, Hashable {
    static let whole = MusicalDuration(1, 1)!
    static let half = MusicalDuration(1, 2)!
    static let quarter = MusicalDuration(1, 4)!
    static let eighth = MusicalDuration(1, 8)!
    static let sixteenth = MusicalDuration(1, 16)!

    let fraction: MusicalFraction

    init?(_ numerator: Int, _ denominator: Int) {
        guard let fraction = MusicalFraction(numerator, denominator), fraction.numerator > 0 else {
            return nil
        }

        self.fraction = fraction
    }

    func dotted(_ dotCount: Int = 1) -> MusicalDuration {
        precondition(dotCount >= 0, "Dot count cannot be negative.")

        var total = fraction
        var addition = fraction

        for _ in 0..<dotCount {
            addition = addition / 2
            total = total + addition
        }

        return MusicalDuration(fraction: total)
    }

    static func + (lhs: MusicalDuration, rhs: MusicalDuration) -> MusicalDuration {
        MusicalDuration(fraction: lhs.fraction + rhs.fraction)
    }

    static func < (lhs: MusicalDuration, rhs: MusicalDuration) -> Bool {
        lhs.fraction < rhs.fraction
    }

    private init(fraction: MusicalFraction) {
        self.fraction = fraction
    }
}

nonisolated struct MusicalPosition: Codable, Comparable, Hashable {
    static let start = MusicalPosition(0, 1)!

    let offset: MusicalFraction

    init?(_ numerator: Int, _ denominator: Int) {
        guard let offset = MusicalFraction(numerator, denominator), offset.numerator >= 0 else {
            return nil
        }

        self.offset = offset
    }

    init(beat: Int, beatUnitDenominator: Int = 4, subdivision: Int = 1) {
        precondition(beat >= 1, "Beats are 1-based.")
        precondition(beatUnitDenominator > 0, "Beat unit denominator must be positive.")
        precondition(subdivision > 0, "Subdivision must be positive.")
        self.offset = MusicalFraction((beat - 1) * subdivision, beatUnitDenominator * subdivision)!
    }

    static func + (lhs: MusicalPosition, rhs: MusicalDuration) -> MusicalPosition {
        MusicalPosition(offset: lhs.offset + rhs.fraction)
    }

    static func < (lhs: MusicalPosition, rhs: MusicalPosition) -> Bool {
        lhs.offset < rhs.offset
    }

    private init(offset: MusicalFraction) {
        self.offset = offset
    }
}

nonisolated struct MusicalFraction: Codable, Comparable, Hashable {
    let numerator: Int
    let denominator: Int

    init?(_ numerator: Int, _ denominator: Int) {
        guard denominator > 0 else {
            return nil
        }

        let divisor = MusicalFraction.greatestCommonDivisor(abs(numerator), denominator)
        self.numerator = numerator / divisor
        self.denominator = denominator / divisor
    }

    static func + (lhs: MusicalFraction, rhs: MusicalFraction) -> MusicalFraction {
        MusicalFraction(
            (lhs.numerator * rhs.denominator) + (rhs.numerator * lhs.denominator),
            lhs.denominator * rhs.denominator
        )!
    }

    static func / (lhs: MusicalFraction, rhs: Int) -> MusicalFraction {
        precondition(rhs > 0, "Divisor must be positive.")
        return MusicalFraction(lhs.numerator, lhs.denominator * rhs)!
    }

    static func < (lhs: MusicalFraction, rhs: MusicalFraction) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs

        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }

        return max(a, 1)
    }
}

nonisolated struct TimeSignature: Codable, Hashable {
    let numerator: Int
    let denominator: Int

    init?(numerator: Int, denominator: Int) {
        guard numerator > 0, Self.validDenominators.contains(denominator) else {
            return nil
        }

        self.numerator = numerator
        self.denominator = denominator
    }

    static let commonTime = TimeSignature(numerator: 4, denominator: 4)!
    private static let validDenominators: Set<Int> = [1, 2, 4, 8, 16, 32, 64]
}

nonisolated struct KeySignature: Codable, Hashable {
    let fifths: Int
    let mode: KeyMode

    init?(fifths: Int, mode: KeyMode = .major) {
        guard (-7...7).contains(fifths) else {
            return nil
        }

        self.fifths = fifths
        self.mode = mode
    }
}

nonisolated enum KeyMode: String, Codable, Hashable {
    case major
    case minor
}
