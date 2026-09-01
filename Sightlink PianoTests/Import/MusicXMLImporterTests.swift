import Foundation
import Testing
@testable import Sightlink_Piano

struct MusicXMLImporterTests {
    @Test func importsScorePartwiseIntoFullScoreDomain() throws {
        let score = try MusicXMLImporter().importScore(from: """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <work>
            <work-title>Two Staff Fixture</work-title>
          </work>
          <part-list>
            <score-part id="P1">
              <part-name>Piano</part-name>
            </score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <attributes>
                <divisions>2</divisions>
                <key>
                  <fifths>-1</fifths>
                  <mode>minor</mode>
                </key>
                <time>
                  <beats>3</beats>
                  <beat-type>4</beat-type>
                </time>
                <staves>2</staves>
                <clef number="1">
                  <sign>G</sign>
                  <line>2</line>
                </clef>
                <clef number="2">
                  <sign>F</sign>
                  <line>4</line>
                </clef>
              </attributes>
              <note>
                <pitch>
                  <step>C</step>
                  <octave>4</octave>
                </pitch>
                <duration>2</duration>
                <tie type="start"/>
                <voice>1</voice>
                <staff>1</staff>
              </note>
              <note>
                <chord/>
                <pitch>
                  <step>E</step>
                  <octave>4</octave>
                </pitch>
                <duration>2</duration>
                <voice>1</voice>
                <staff>1</staff>
              </note>
              <note>
                <rest/>
                <duration>2</duration>
                <voice>1</voice>
                <staff>1</staff>
              </note>
              <backup>
                <duration>4</duration>
              </backup>
              <note>
                <pitch>
                  <step>F</step>
                  <alter>1</alter>
                  <octave>3</octave>
                </pitch>
                <duration>3</duration>
                <dot/>
                <voice>2</voice>
                <staff>2</staff>
              </note>
            </measure>
            <measure number="2">
              <note>
                <pitch>
                  <step>D</step>
                  <alter>-1</alter>
                  <octave>4</octave>
                </pitch>
                <duration>2</duration>
                <voice>1</voice>
                <staff>1</staff>
              </note>
            </measure>
          </part>
        </score-partwise>
        """)

        #expect(score.id == "musicxml-import")
        #expect(score.title == "Two Staff Fixture")
        #expect(score.parts.count == 1)

        let part = try #require(score.parts.first)
        #expect(part.id == "P1")
        #expect(part.name == "Piano")
        #expect(part.staves.map(\.id) == [1, 2])
        #expect(part.staves.map(\.initialClef) == [.treble, .bass])
        #expect(part.measures.count == 2)

        let firstMeasure = part.measures[0]
        #expect(firstMeasure.id == "P1-measure-1")
        #expect(firstMeasure.number == 1)
        #expect(firstMeasure.timeSignature == TimeSignature(numerator: 3, denominator: 4))
        #expect(firstMeasure.keySignature == KeySignature(fifths: -1, mode: .minor))
        #expect(firstMeasure.events.map(\.id) == [
            "P1-measure-1-event-1",
            "P1-measure-1-event-3",
            "P1-measure-1-event-2"
        ])

        guard case .chord(let chord) = firstMeasure.events[0].content else {
            Issue.record("Expected the first two MusicXML notes to import as one chord event.")
            return
        }

        #expect(chord.pitches == [Pitch(.c, octave: 4), Pitch(.e, octave: 4)])
        #expect(chord.tie == .starts)
        #expect(firstMeasure.events[0].position == .start)
        #expect(firstMeasure.events[0].duration == .quarter)
        #expect(firstMeasure.events[0].staffID == 1)
        #expect(firstMeasure.events[0].voiceID == "1")

        guard case .note(let lowerStaffNote) = firstMeasure.events[1].content else {
            Issue.record("Expected lower staff note content.")
            return
        }

        #expect(lowerStaffNote.pitch == Pitch(.f, accidental: .sharp, octave: 3))
        #expect(firstMeasure.events[1].position == .start)
        #expect(firstMeasure.events[1].duration == MusicalDuration(3, 8))
        #expect(firstMeasure.events[1].staffID == 2)
        #expect(firstMeasure.events[1].voiceID == "2")

        #expect(firstMeasure.events[2].content == .rest)
        #expect(firstMeasure.events[2].position == MusicalPosition(1, 4))
        #expect(firstMeasure.events[2].duration == .quarter)

        let secondMeasure = part.measures[1]
        #expect(secondMeasure.timeSignature == TimeSignature(numerator: 3, denominator: 4))
        #expect(secondMeasure.keySignature == KeySignature(fifths: -1, mode: .minor))

        guard case .note(let secondMeasureNote) = try #require(secondMeasure.events.first).content else {
            Issue.record("Expected note content in second measure.")
            return
        }

        #expect(secondMeasureNote.pitch == Pitch(.d, accidental: .flat, octave: 4))
    }

    @Test func importsSimpleMelodyFixture() throws {
        let score = try importFixture("simple-melody.musicxml")
        let part = try #require(score.parts.first)
        let events = try #require(part.measures.first?.events)

        #expect(score.title == "Simple Melody")
        #expect(part.name == "Piano")
        #expect(events.count == 2)
        #expect(events.map(\.position) == [.start, MusicalPosition(1, 4)])

        guard case .note(let firstNote) = events[0].content else {
            Issue.record("Expected first melody event to be a note.")
            return
        }

        guard case .note(let secondNote) = events[1].content else {
            Issue.record("Expected second melody event to be a note.")
            return
        }

        #expect(firstNote.pitch == Pitch(.c, octave: 4))
        #expect(secondNote.pitch == Pitch(.d, octave: 4))
    }

    @Test func importsPianoGrandStaffFixtureWithBackup() throws {
        let score = try importFixture("piano-grand-staff.musicxml")
        let part = try #require(score.parts.first)
        let measure = try #require(part.measures.first)

        #expect(score.title == "Piano Grand Staff")
        #expect(part.staves.map(\.id) == [1, 2])
        #expect(part.staves.map(\.initialClef) == [.treble, .bass])
        #expect(measure.events.count == 2)
        #expect(measure.events.map(\.position) == [.start, .start])
        #expect(measure.events.map(\.staffID) == [1, 2])
        #expect(measure.events.map(\.voiceID) == ["1", "2"])

        guard case .note(let trebleNote) = measure.events[0].content else {
            Issue.record("Expected staff 1 event to be a note.")
            return
        }

        guard case .note(let bassNote) = measure.events[1].content else {
            Issue.record("Expected staff 2 event to be a note.")
            return
        }

        #expect(trebleNote.pitch == Pitch(.c, octave: 5))
        #expect(bassNote.pitch == Pitch(.c, octave: 3))
    }

    @Test func importsChordFixtureAsSingleExplicitChordEvent() throws {
        let score = try importFixture("chord.musicxml")
        let events = try #require(score.parts.first?.measures.first?.events)

        #expect(events.count == 1)

        guard case .chord(let chord) = events[0].content else {
            Issue.record("Expected explicit MusicXML chord to import as a chord.")
            return
        }

        #expect(chord.pitches == [
            Pitch(.c, octave: 4),
            Pitch(.e, octave: 4),
            Pitch(.g, octave: 4)
        ])
        #expect(events[0].position == .start)
        #expect(events[0].duration == .half)
    }

    @Test func importsRestsFixtureWithForwardCursorMovement() throws {
        let score = try importFixture("rests.musicxml")
        let events = try #require(score.parts.first?.measures.first?.events)

        #expect(events.count == 2)
        #expect(events[0].content == .rest)
        #expect(events[0].position == .start)
        #expect(events[0].duration == .quarter)
        #expect(events[1].content == .rest)
        #expect(events[1].position == MusicalPosition(3, 8))
        #expect(events[1].duration == MusicalDuration(1, 8))
    }

    @Test func importsMultipleVoicesFixtureUsingBackupAndForwardCursorMovement() throws {
        let score = try importFixture("multiple-voices.musicxml")
        let events = try #require(score.parts.first?.measures.first?.events)

        #expect(events.count == 4)
        #expect(events.map(\.id) == [
            "P1-measure-1-event-1",
            "P1-measure-1-event-3",
            "P1-measure-1-event-2",
            "P1-measure-1-event-4"
        ])
        #expect(events.map(\.position) == [
            .start,
            .start,
            MusicalPosition(1, 4),
            MusicalPosition(3, 4)
        ])
        #expect(events.map(\.voiceID) == ["1", "2", "1", "2"])
        #expect(events.allSatisfy { event in
            if case .chord = event.content {
                return false
            }
            return true
        })

        guard case .note(let firstVoiceFirstNote) = events[0].content,
              case .note(let secondVoiceFirstNote) = events[1].content,
              case .note(let firstVoiceSecondNote) = events[2].content,
              case .note(let secondVoiceSecondNote) = events[3].content else {
            Issue.record("Expected simultaneous voices to remain separate note events.")
            return
        }

        #expect(firstVoiceFirstNote.pitch == Pitch(.c, octave: 4))
        #expect(secondVoiceFirstNote.pitch == Pitch(.e, octave: 3))
        #expect(firstVoiceSecondNote.pitch == Pitch(.d, octave: 4))
        #expect(secondVoiceSecondNote.pitch == Pitch(.g, octave: 3))
    }

    @Test func importsAccidentalsFixture() throws {
        let score = try importFixture("accidentals.musicxml")
        let measure = try #require(score.parts.first?.measures.first)

        #expect(measure.keySignature == KeySignature(fifths: 2, mode: .major))

        let pitches = try measure.events.map { event -> Pitch in
            guard case .note(let note) = event.content else {
                throw MusicXMLImportError.invalidPitch("Expected note content.")
            }
            return note.pitch
        }

        #expect(pitches == [
            Pitch(.c, accidental: .sharp, octave: 4),
            Pitch(.d, accidental: .flat, octave: 4),
            Pitch(.f, accidental: .doubleSharp, octave: 4),
            Pitch(.b, accidental: .doubleFlat, octave: 3)
        ])
    }

    @Test func importsTiesFixture() throws {
        let score = try importFixture("ties.musicxml")
        let measures = try #require(score.parts.first?.measures)

        guard case .note(let tiedStart) = measures[0].events[0].content,
              case .note(let tiedEnd) = measures[1].events[0].content else {
            Issue.record("Expected tied notes in fixture.")
            return
        }

        #expect(tiedStart.tie == .starts)
        #expect(tiedEnd.tie == .ends)
        #expect(tiedStart.pitch == tiedEnd.pitch)
    }

    @Test func importsMultiplePartsInDocumentOrder() throws {
        let score = try MusicXMLImporter().importScore(from: """
        <score-partwise>
          <part-list>
            <score-part id="P1"><part-name>Right Hand</part-name></score-part>
            <score-part id="P2"><part-name>Left Hand</part-name></score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration></note>
            </measure>
          </part>
          <part id="P2">
            <measure number="1">
              <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration></note>
            </measure>
          </part>
        </score-partwise>
        """, scoreID: "fixture-score")

        #expect(score.id == "fixture-score")
        #expect(score.parts.map(\.id) == ["P1", "P2"])
        #expect(score.parts.map(\.name) == ["Right Hand", "Left Hand"])
    }

    @Test func importsTieStopAndDoubleAccidentals() throws {
        let score = try MusicXMLImporter().importScore(from: """
        <score-partwise>
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <note>
                <pitch><step>G</step><alter>2</alter><octave>4</octave></pitch>
                <duration>1</duration>
                <tie type="stop"/>
              </note>
              <note>
                <pitch><step>B</step><alter>-2</alter><octave>3</octave></pitch>
                <duration>1</duration>
              </note>
            </measure>
          </part>
        </score-partwise>
        """)

        let events = try #require(score.parts.first?.measures.first?.events)

        guard case .note(let firstNote) = events[0].content else {
            Issue.record("Expected first event to be a note.")
            return
        }

        guard case .note(let secondNote) = events[1].content else {
            Issue.record("Expected second event to be a note.")
            return
        }

        #expect(firstNote.pitch == Pitch(.g, accidental: .doubleSharp, octave: 4))
        #expect(firstNote.tie == .ends)
        #expect(secondNote.pitch == Pitch(.b, accidental: .doubleFlat, octave: 3))
    }

    @Test func rejectsUnsupportedRootElement() throws {
        #expect(throws: MusicXMLImportError.unsupportedRoot("score-timewise")) {
            _ = try MusicXMLImporter().importScore(from: "<score-timewise/>")
        }
    }

    @Test func rejectsChordToneWithoutBaseNote() throws {
        #expect(throws: MusicXMLImportError.unsupportedChord("Chord tone appeared before a compatible base note.")) {
            _ = try MusicXMLImporter().importScore(from: """
            <score-partwise>
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1">
                <measure number="1">
                  <note>
                    <chord/>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """)
        }
    }

    @Test func rejectsNotesWithoutPositiveDuration() throws {
        #expect(throws: MusicXMLImportError.missingMeasureDuration("A supported note or rest needs a positive MusicXML duration.")) {
            _ = try MusicXMLImporter().importScore(from: """
            <score-partwise>
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1">
                <measure number="1">
                  <note><pitch><step>C</step><octave>4</octave></pitch></note>
                </measure>
              </part>
            </score-partwise>
            """)
        }
    }

    @Test func rejectsBackupBeforeMeasureStart() throws {
        #expect(throws: MusicXMLImportError.invalidCursorOperation("Backup cannot move before the start of the measure.")) {
            _ = try MusicXMLImporter().importScore(from: """
            <score-partwise>
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <backup><duration>1</duration></backup>
                </measure>
              </part>
            </score-partwise>
            """)
        }
    }

    @Test func rejectsCursorMoveWithoutPositiveDuration() throws {
        #expect(throws: MusicXMLImportError.invalidCursorOperation("Cursor movement requires a positive duration.")) {
            _ = try MusicXMLImporter().importScore(from: """
            <score-partwise>
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <forward><duration>0</duration></forward>
                </measure>
              </part>
            </score-partwise>
            """)
        }
    }

    private func importFixture(_ name: String) throws -> Score {
        try MusicXMLImporter().importScore(from: fixtureData(named: name))
    }

    private func fixtureData(named name: String) throws -> Data {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let fixtureURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("MusicXML")
            .appendingPathComponent(name)
        return try Data(contentsOf: fixtureURL)
    }
}
