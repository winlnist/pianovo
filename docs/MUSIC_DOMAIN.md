# Music Domain

The Music Domain is the framework-independent source of truth for musical concepts in Pianovo.

It must not depend on SwiftUI, CoreMIDI, Verovio, networking, persistence, or other infrastructure frameworks.

## Responsibilities

The Music Domain should model:

- Pitch names and octaves.
- Accidentals.
- MIDI note number conversion rules.
- Pitch ranges.
- Notes and chords.
- Clefs and grand staff placement.
- Rhythm values.
- Measures and score events.
- Stable identifiers for musical events.
- Staff positions and ledger lines.

## Pitch Model

The app should initially support exercises around C2-C6. The domain should not be limited to that range. It should be capable of representing the full piano range later.

Recommended concepts:

- Pitch letter: A, B, C, D, E, F, G.
- Accidental: natural, sharp, flat, double sharp, double flat, or none where context requires.
- Octave number.
- MIDI note number mapping.

Middle C is C4 in scientific pitch notation and MIDI note number 60. The domain should document and test this convention.

## Notes, Chords, and Events

A single displayed note, chord, or rhythmic unit should be modeled as a musical event with a stable identifier.

Stable identifiers allow:

- Practice results to reference exact prompts.
- Imported scores to preserve event identity.
- Progress history to track repeated mistakes.
- Renderers to map user interaction back to domain events.

Do not store practice outcomes directly inside score events. The score describes music; progress describes user performance.

Milestone 5.7 adds a separate Full Score Domain for complete musical works and future imported songs. It models `Score`, ordered parts, staves, measures, voices, notes, chords, rests, exact durations, musical positions, time signatures, clef context, key signatures, ties, and stable score-event identities. See `docs/SCORE_DOMAIN.md` for the detailed boundaries.

Milestone 6A adds a MusicXML adapter that converts a limited supported `score-partwise` subset into the Full Score Domain. XML parsing remains outside the Music Domain.

The current `ReadingExercise` model remains a lightweight generated-practice model. A future adapter may transform selected score material into a `ReadingExercise`, but production practice is not migrated onto the full `Score` model yet.

## Clefs and Grand Staff

Version 0.1 should support a grand staff:

- Treble clef.
- Bass clef.
- Correct note placement.
- Correct ledger-line rendering.

The domain should provide testable calculations for staff position and ledger lines. Rendering code can decide how to draw those positions, but it should not invent placement rules.

For simple Version 0.1 drills, automatic grand-staff placement should default to treble clef for C4 and above, and bass clef for B3 and below. Middle C can still be represented relative to either staff: one ledger line below treble or one ledger line above bass.

## Accidentals

Accidentals should be represented in the domain even if Version 0.1 starts with natural notes only.

Future behavior should support:

- Explicit accidentals.
- Key signatures.
- Measure-level accidental rules.
- Enharmonic spelling where needed.

## Rhythm

Version 0.1 does not need full rhythm practice, but the domain should leave room for rhythm values because notes, chords, measures, MusicXML import, and full-score rendering all require duration.

Potential concepts:

- Whole, half, quarter, eighth, sixteenth, and dotted values.
- Ties.
- Rests.
- Time signatures.
- Beat position.

The Full Score Domain now represents duration and position with exact rational values. It does not yet implement rhythm grading, tuplets as semantic groups, or rendering behavior.

## Renderer Independence

The domain should not know whether music is rendered by SwiftUI/Core Graphics, Verovio, or another renderer. Renderer adapters should translate domain score events into renderer-specific view models.

## Test Priorities

- MIDI note 60 maps to C4.
- Configurable pitch ranges include expected boundaries.
- C2-C6 range generation is correct.
- Grand-staff placement is correct for treble and bass notes.
- Ledger-line counts are correct above, below, and between staves.
- Event identifiers remain stable when practice results reference them.
