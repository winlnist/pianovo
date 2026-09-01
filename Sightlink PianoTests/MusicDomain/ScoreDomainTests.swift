import Testing
@testable import Sightlink_Piano

struct ScoreDomainTests {
    @Test func scorePreservesOrderedPartsMeasuresAndEvents() throws {
        let firstEvent = ScoreEvent.note(
            id: "event-1",
            pitch: Pitch(.c, octave: 4),
            position: .start,
            duration: .quarter,
            staffID: 1,
            voiceID: "upper"
        )
        let secondEvent = ScoreEvent.rest(
            id: "event-2",
            position: MusicalPosition(beat: 2),
            duration: .quarter,
            staffID: 1,
            voiceID: "upper"
        )
        let measure = ScoreMeasure(
            id: "measure-1",
            number: 1,
            timeSignature: .commonTime,
            events: [secondEvent, firstEvent]
        )
        let piano = ScorePart(
            id: "piano",
            name: "Piano",
            staves: [
                ScoreStaff(id: 1, initialClef: .treble),
                ScoreStaff(id: 2, initialClef: .bass)
            ],
            measures: [measure]
        )
        let score = Score(id: "score-1", title: "Fixture", parts: [piano])

        #expect(score.parts.map(\.id) == ["piano"])
        #expect(score.parts[0].measures.map(\.id) == ["measure-1"])
        #expect(score.parts[0].measures[0].events.map(\.id) == ["event-1", "event-2"])
    }

    @Test func timeSignaturesValidateCommonMeters() throws {
        #expect(TimeSignature(numerator: 4, denominator: 4) != nil)
        #expect(TimeSignature(numerator: 3, denominator: 4) != nil)
        #expect(TimeSignature(numerator: 6, denominator: 8) != nil)
        #expect(TimeSignature(numerator: 0, denominator: 4) == nil)
        #expect(TimeSignature(numerator: 4, denominator: 0) == nil)
        #expect(TimeSignature(numerator: 4, denominator: 3) == nil)
    }

    @Test func durationValuesCompareComposeAndSupportDots() throws {
        #expect(MusicalDuration.whole > .half)
        #expect(MusicalDuration.half > .quarter)
        #expect(MusicalDuration.quarter > .eighth)
        #expect(MusicalDuration.eighth > .sixteenth)
        #expect(MusicalDuration.quarter + .quarter == .half)
        #expect(MusicalDuration.quarter.dotted() == MusicalDuration(3, 8))
        #expect(MusicalDuration.quarter.dotted(2) == MusicalDuration(7, 16))
    }

    @Test func musicalPositionsAreExactAndCanShareOffsets() throws {
        let beatOne = MusicalPosition.start
        let beatTwo = MusicalPosition(beat: 2)
        let offBeat = try #require(MusicalPosition(3, 8))
        let anotherBeatTwo = try #require(MusicalPosition(1, 4))

        #expect(beatOne < beatTwo)
        #expect(beatTwo == anotherBeatTwo)
        #expect(offBeat > beatTwo)
        #expect(beatTwo + .quarter == MusicalPosition(beat: 3))
    }

    @Test func simultaneousEventsAcrossVoicesAndStavesCanSharePosition() {
        let upperVoice = ScoreEvent.note(
            id: "upper-voice",
            pitch: Pitch(.e, octave: 4),
            position: .start,
            duration: .quarter,
            staffID: 1,
            voiceID: "1"
        )
        let lowerVoice = ScoreEvent.note(
            id: "lower-voice",
            pitch: Pitch(.c, octave: 3),
            position: .start,
            duration: .quarter,
            staffID: 2,
            voiceID: "1"
        )

        #expect(upperVoice.position == lowerVoice.position)
        #expect(upperVoice.staffID != lowerVoice.staffID)
        #expect([lowerVoice, upperVoice].sorted().map(\.id) == ["upper-voice", "lower-voice"])
    }

    @Test func writtenPitchesPreserveEnharmonicSpelling() {
        let cSharp = ScoreEvent.note(
            id: "c-sharp",
            pitch: Pitch(.c, accidental: .sharp, octave: 4),
            position: .start,
            duration: .quarter,
            staffID: 1,
            voiceID: "1"
        )
        let dFlat = ScoreEvent.note(
            id: "d-flat",
            pitch: Pitch(.d, accidental: .flat, octave: 4),
            position: .start,
            duration: .quarter,
            staffID: 1,
            voiceID: "1"
        )

        #expect(cSharp.content != dFlat.content)
        #expect(Pitch(.c, accidental: .sharp, octave: 4).midiNoteNumber == Pitch(.d, accidental: .flat, octave: 4).midiNoteNumber)
    }

    @Test func chordsRepresentMultipleSimultaneousWrittenPitches() {
        let chord = ScoreEvent.chord(
            id: "chord-1",
            pitches: [
                Pitch(.c, octave: 4),
                Pitch(.e, octave: 4),
                Pitch(.g, octave: 4)
            ],
            position: .start,
            duration: .half,
            staffID: 1,
            voiceID: "1",
            tie: .starts
        )

        guard case .chord(let content) = chord.content else {
            Issue.record("Expected chord content.")
            return
        }

        #expect(content.pitches.count == 3)
        #expect(chord.duration == .half)
        #expect(content.tie == .starts)
    }

    @Test func restsAreFirstClassEventsWithoutPitches() {
        let rest = ScoreEvent.rest(
            id: "rest-1",
            position: MusicalPosition(beat: 3),
            duration: .quarter,
            staffID: 2,
            voiceID: "bass"
        )

        #expect(rest.content == .rest)
        #expect(rest.duration == .quarter)
        #expect(rest.position == MusicalPosition(beat: 3))
    }

    @Test func staffIdentityIsSeparateFromClefAndSupportsClefChanges() {
        let staff = ScoreStaff(
            id: 1,
            initialClef: .treble,
            clefChanges: [
                ClefChange(position: MusicalPosition(beat: 3), clef: .bass)
            ]
        )

        #expect(staff.id == 1)
        #expect(staff.initialClef == .treble)
        #expect(staff.clefChanges.first?.clef == .bass)
    }

    @Test func multipleVoicesCanCoexistInSameMeasureAndStaff() {
        let firstVoice = ScoreEvent.note(
            id: "voice-1",
            pitch: Pitch(.c, octave: 4),
            position: .start,
            duration: .half,
            staffID: 1,
            voiceID: "1"
        )
        let secondVoice = ScoreEvent.note(
            id: "voice-2",
            pitch: Pitch(.g, octave: 4),
            position: .start,
            duration: .quarter,
            staffID: 1,
            voiceID: "2"
        )

        #expect(firstVoice.staffID == secondVoice.staffID)
        #expect(firstVoice.position == secondVoice.position)
        #expect(firstVoice.voiceID != secondVoice.voiceID)
    }

    @Test func tieStatesAndKeySignaturesCanBeRepresented() throws {
        #expect(TieState.none != .starts)
        #expect(TieState.starts != .continues)
        #expect(TieState.continues != .ends)

        let key = try #require(KeySignature(fifths: -3, mode: .minor))
        #expect(key.fifths == -3)
        #expect(key.mode == .minor)
        #expect(KeySignature(fifths: 8) == nil)
    }

    @Test func scoreEventIDsHaveStableValueSemanticsForPracticeReferences() {
        let first: ScoreEventID = "score-event-1"
        let second = ScoreEventID(rawValue: "score-event-1")
        let third: ScoreEventID = "score-event-2"

        #expect(first == second)
        #expect(first != third)
        #expect(Set([first, second, third]).count == 2)
    }
}
