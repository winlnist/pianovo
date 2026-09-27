import Testing
@testable import Pianovo

struct MusicDomainTests {
    @Test func midiMapsReferenceCOctaves() throws {
        #expect(Pitch(midiNoteNumber: 36) == Pitch(.c, octave: 2))
        #expect(Pitch(midiNoteNumber: 48) == Pitch(.c, octave: 3))
        #expect(Pitch(midiNoteNumber: 60) == Pitch(.c, octave: 4))
        #expect(Pitch(midiNoteNumber: 72) == Pitch(.c, octave: 5))
        #expect(Pitch(midiNoteNumber: 84) == Pitch(.c, octave: 6))
    }

    @Test func midiConversionUsesCanonicalSharpSpelling() throws {
        #expect(Pitch(midiNoteNumber: 61) == Pitch(.c, accidental: .sharp, octave: 4))
        #expect(Pitch(midiNoteNumber: 63) == Pitch(.d, accidental: .sharp, octave: 4))
        #expect(Pitch(midiNoteNumber: 66) == Pitch(.f, accidental: .sharp, octave: 4))
        #expect(Pitch(midiNoteNumber: 68) == Pitch(.g, accidental: .sharp, octave: 4))
        #expect(Pitch(midiNoteNumber: 70) == Pitch(.a, accidental: .sharp, octave: 4))
    }

    @Test func midiRoundTripsAcrossStandardPianoRange() throws {
        for midiNoteNumber in 21...108 {
            let pitch = try #require(Pitch(midiNoteNumber: midiNoteNumber))
            #expect(pitch.midiNoteNumber == midiNoteNumber)
        }
    }

    @Test func pitchOrderingUsesSoundingPitchAcrossOctaves() {
        let pitches = [
            Pitch(.c, octave: 4),
            Pitch(.b, octave: 3),
            Pitch(.c, accidental: .sharp, octave: 4),
            Pitch(.c, octave: 3)
        ]

        #expect(pitches.sorted() == [
            Pitch(.c, octave: 3),
            Pitch(.b, octave: 3),
            Pitch(.c, octave: 4),
            Pitch(.c, accidental: .sharp, octave: 4)
        ])
    }

    @Test func pitchRangeIncludesBoundaries() throws {
        let lower = Pitch(.c, octave: 2)
        let upper = Pitch(.c, octave: 6)
        let range = try #require(PitchRange(lowerBound: lower, upperBound: upper))

        #expect(range.contains(lower))
        #expect(range.contains(upper))
        #expect(range.pitches.first == lower)
        #expect(range.pitches.last == upper)
    }

    @Test func c2ThroughC6RangeGeneratesChromaticPitches() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 2), upperBound: Pitch(.c, octave: 6)))

        #expect(range.pitches.count == 49)
        #expect(range.pitches.map(\.midiNoteNumber) == Array(36...84))
    }

    @Test func reversedPitchRangeIsRejected() {
        #expect(PitchRange(lowerBound: Pitch(.c, octave: 6), upperBound: Pitch(.c, octave: 2)) == nil)
    }

    @Test func trebleClefPlacementUsesBottomLineE4() {
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.e, octave: 4)).stepFromBottomLine == 0)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.g, octave: 4)).stepFromBottomLine == 2)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.f, octave: 5)).stepFromBottomLine == 8)
    }

    @Test func bassClefPlacementUsesBottomLineG2() {
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.g, octave: 2)).stepFromBottomLine == 0)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.d, octave: 3)).stepFromBottomLine == 4)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.a, octave: 3)).stepFromBottomLine == 8)
    }

    @Test func middleCPlacementIsDocumentedForBothStavesAndDefaultGrandStaff() {
        let middleC = Pitch(.c, octave: 4)

        #expect(StaffPosition(clef: .treble, pitch: middleC).stepFromBottomLine == -2)
        #expect(StaffPosition(clef: .treble, pitch: middleC).ledgerLines.belowStaff == 1)
        #expect(StaffPosition(clef: .bass, pitch: middleC).stepFromBottomLine == 10)
        #expect(StaffPosition(clef: .bass, pitch: middleC).ledgerLines.aboveStaff == 1)
        #expect(GrandStaffPlacement(pitch: middleC).clef == .treble)
    }

    @Test func trebleLedgerLineCountsAreCorrectForRepresentativePitches() {
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.d, octave: 4)).ledgerLines.belowStaff == 0)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.c, octave: 4)).ledgerLines.belowStaff == 1)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.a, octave: 3)).ledgerLines.belowStaff == 2)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.g, octave: 5)).ledgerLines.aboveStaff == 0)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.a, octave: 5)).ledgerLines.aboveStaff == 1)
        #expect(StaffPosition(clef: .treble, pitch: Pitch(.c, octave: 6)).ledgerLines.aboveStaff == 2)
    }

    @Test func bassLedgerLineCountsAreCorrectForRepresentativePitches() {
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.f, octave: 2)).ledgerLines.belowStaff == 0)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.e, octave: 2)).ledgerLines.belowStaff == 1)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.c, octave: 2)).ledgerLines.belowStaff == 2)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.b, octave: 3)).ledgerLines.aboveStaff == 0)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.c, octave: 4)).ledgerLines.aboveStaff == 1)
        #expect(StaffPosition(clef: .bass, pitch: Pitch(.e, octave: 4)).ledgerLines.aboveStaff == 2)
    }

    @Test func stableEventIDsHaveValueSemantics() {
        let first = MusicEventID(rawValue: "event-1")
        let second: MusicEventID = "event-1"
        let third = MusicEventID(rawValue: "event-2")

        #expect(first == second)
        #expect(first != third)
        #expect(Set([first, second, third]).count == 2)
    }
}
