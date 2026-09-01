# Score Domain

The Full Score Domain describes complete musical scores independently from rendering, importing, practice state, MIDI, and persistence.

## Responsibilities

The score model owns musical structure:

- Scores.
- Parts.
- Staves.
- Measures.
- Voices.
- Notes, chords, and rests.
- Musical duration and position.
- Time signatures.
- Clef context.
- Lightweight key signatures.
- Stable score, part, measure, and event identity.

It does not own user progress, correctness, MIDI input, rendered page layout, Verovio element IDs, MusicXML parser details, PDF/photo recognition output, or UI state.

## Structural Hierarchy

```text
Score
  -> ordered ScorePart values
      -> ScoreStaff definitions
      -> ordered ScoreMeasure values
          -> ordered ScoreEvent values
```

Measures are musical containers, not rendered rectangles. Systems, pages, coordinates, and glyphs belong to renderers or renderer adapters.

## Timeline And Events

`ScoreEvent` is the common timeline item for:

- `note`
- `chord`
- `rest`

Every score event has:

- stable `ScoreEventID`
- exact `MusicalPosition`
- exact `MusicalDuration`
- `StaffID`
- `VoiceID`
- event content

Events are sorted deterministically by position, staff, voice, and event ID. Multiple events may share the same position, which supports simultaneity across voices and staves without turning the score into a flat prompt list.

## Duration And Position

Durations and positions use normalized rational values rather than seconds or floating-point time. This keeps notation timing exact for whole, half, quarter, eighth, sixteenth, dotted durations, and future subdivisions such as tuplets.

Tuplet semantics are not implemented yet. The rational model leaves room for them without committing to an engraving or import strategy.

## Staff, Clef, And Voice

`StaffID` identifies a staff. It is intentionally separate from `Clef` because real scores can change clef over time.

`ScoreStaff` stores an initial clef and optional future `ClefChange` values. Complex mid-measure clef-change behavior is not implemented yet.

`VoiceID` distinguishes independent musical voices within a staff or measure. The domain does not implement voice-leading or engraving rules.

## Written Pitch

Notes and chords reuse the existing `Pitch` model. Written enharmonic spelling is preserved: C sharp and D flat remain distinct score pitches even when they share the same sounding MIDI note number.

MIDI conversion remains a sounding-pitch adapter concern and must not be used as the source of notation spelling for imported score events.

## Relationship To ReadingExercise

The current practice experience continues to use the lightweight generated exercise model:

```text
ReadingExercise
  -> ReadingMeasure
  -> ReadingEvent
```

Milestone 5.7 does not migrate production practice onto `Score`.

A future practice adapter can derive exercises from a score:

```text
Score
  -> selected part / staff / measure range
  -> practice transformation
  -> ReadingExercise
```

The original score should remain intact while practice sessions track current event, attempts, feedback, and statistics separately.

## Relationship To MusicXML

Milestone 6A adds a MusicXML adapter that maps a small supported `score-partwise` subset into the Score Domain. XML parser state and MusicXML-specific details stay outside the core score types.

The importer should expose domain `Score` values rather than XML nodes. Broader MusicXML coverage remains future work.

MusicXML `<backup>` and `<forward>` cursor operations are handled inside the importer using exact `MusicalFraction` values derived from the active MusicXML `divisions`. The resulting `ScoreEvent.position` values describe musical positions without retaining cursor-operation nodes in the Score Domain.

## Relationship To Verovio

Verovio remains a future renderer candidate. The Score Domain does not store Verovio IDs, SVG IDs, coordinates, page numbers, systems, fonts, glyphs, or SMuFL codepoints.

A future Verovio adapter can keep renderer-specific mappings outside the domain.

## Non-Goals

Milestone 5.7 does not implement:

- Verovio integration.
- Score UI.
- Imported-song practice.
- PDF/photo import.
- Optical music recognition.
- AI recognition.
- Playback.
- MIDI output.
- Metronome.
- Rhythm grading.
- Persistence/history.
- Practice-model refactoring.
- Mixed-clef or two-hand practice UI.
