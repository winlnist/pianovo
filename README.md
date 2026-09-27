# Pianovo

Pianovo is a native SwiftUI piano-learning app for iPhone and iPad. Its purpose is to help users practice music reading and piano by showing notation, listening to a physical MIDI piano, and comparing what the user plays against the expected musical material.

The current production practice experience is continuous single-staff sight reading. Users choose Treble Reading or Bass Reading, read ordered note events across a paper-like music page, and play each note on a physical MIDI piano. Correct MIDI input advances to the next event; incorrect input keeps the current event active. A fresh exercise is generated automatically after the final event.

## Product Direction

Pianovo should grow into an App Store-quality practice app that can support:

- Treble and bass staff reading.
- Configurable note ranges, initially around C2-C6.
- Correct notation rendering for ledger lines, accidentals, chords, rhythm, and eventually full scores.
- Physical MIDI piano input through CoreMIDI.
- Matching played notes and chords against expected notes and chords.
- Practice-session progress, accuracy, and history.
- MusicXML song import.
- Future PDF/photo sheet-music recognition that converts visual notation into structured interactive notation.

## Architecture Direction

The project should be built around a framework-independent Music Domain. The Music Domain is the single source of truth for musical concepts and must not depend on SwiftUI, CoreMIDI, Verovio, networking, persistence, or other infrastructure frameworks.

High-level boundaries:

- Music Domain: pitches, notes, chords, clefs, staff placement, rhythm, score events, stable event identifiers.
- Practice Engine: exercise state, expected answers, matching, scoring, session progress.
- Programme Domain: data-driven practice programme structure, source references, mastery rules, and validation.
- Progress/Persistence: local-first student progress records, repository protocols, and persistence adapters separated from Programme and Music domains.
- Reference Materials: logical catalogue metadata and source-resolution boundaries, separate from document access and PDF presentation.
- Rendering Adapters: convert domain notation into renderer-specific view models.
- MIDI Adapter: observes CoreMIDI and converts MIDI messages into domain input events.
- App/UI Layer: SwiftUI screens, app state composition, navigation, accessibility, user interaction.
- Persistence/Progress: user performance and session history, separate from score definitions.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the intended boundaries.

## Current Version 0.1 Scope

Version 0.1 currently includes:

- Continuous single-staff Treble Reading and Bass Reading exercises.
- Ordered reading events grouped into measures and responsive systems.
- Quarter-note notation with clefs, stems, barlines, ledger lines, and current-event highlighting.
- Configurable pitch range controls.
- Treble default range C4-C6.
- Bass default range C2-C4.
- Natural-note range options within C2-C6.
- Correct ledger-line rendering.
- MIDI device detection and note-on/note-off input.
- MIDI note number to domain pitch conversion.
- Correct/incorrect matching against the current reading event.
- Automatic advancement after a correct answer.
- Session-only statistics.
- MusicXML import foundation for a small supported subset mapped into the Full Score Domain.
- Debug-only Verovio full-score rendering for MusicXML fixtures.
- Framework-independent programme domain and twelve-week Pianovo seed structure.
- Local persistence and history foundation for student progress, verified through repository tests.

Version 0.1 does not include:

- Mixed/grand-staff continuous practice.
- Two-hand practice.
- Chords.
- Accidentals in generated practice.
- Rhythm variation, rests, ties, tuplets, or real time signatures.
- MusicXML file picker/import UI.
- Production imported-score UI.
- PDF recognition.
- AI recognition.
- Persistence/history.
- Programme UI, persisted mastery decisions, and adaptive Beyer sequencing.
- MIDI output or recording.
- Full-song playback.
- Full MusicXML song practice.

## MIDI Notes

Physical MIDI input has been confirmed working on iPad. The most reliable tested startup sequence is:

```text
app not running -> connect cable -> power piano -> launch Pianovo
```

Hot-plug/device-refresh code exists, but reconnect behavior has not yet been hardened or fully validated.

## Documentation Map

- [AGENTS.md](AGENTS.md): practical rules for future Codex work.
- [docs/PRODUCT.md](docs/PRODUCT.md): product goals, audience, and constraints.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): layers, boundaries, and dependency rules.
- [docs/ROADMAP.md](docs/ROADMAP.md): milestone plan.
- [docs/MUSIC_DOMAIN.md](docs/MUSIC_DOMAIN.md): core music model and notation concepts.
- [docs/SCORE_DOMAIN.md](docs/SCORE_DOMAIN.md): full score domain foundation and boundaries.
- [docs/PRACTICE_ENGINE.md](docs/PRACTICE_ENGINE.md): practice state, matching, scoring, and statistics.
- [docs/PROGRAMME_DOMAIN.md](docs/PROGRAMME_DOMAIN.md): programme structure, source references, mastery rules, validation, and seed-data boundaries.
- [docs/PERSISTENCE_AND_HISTORY.md](docs/PERSISTENCE_AND_HISTORY.md): progress records, local persistence boundaries, schema versioning, and deletion/reset semantics.
- [docs/REFERENCE_MATERIALS.md](docs/REFERENCE_MATERIALS.md): reference-material catalogue, availability, page terminology, and licensing boundaries.
- [docs/IMPORT_PIPELINE.md](docs/IMPORT_PIPELINE.md): MusicXML and future PDF/photo recognition plan.

## Development Notes

Prefer small, readable, unit-testable Swift types. Domain and business logic should be testable without launching SwiftUI, connecting a MIDI device, using a renderer, or touching persistence.

Third-party dependencies should be introduced only when there is a documented reason and trade-off. Verovio is currently integrated for debug-only full-score rendering, but the architecture should remain renderer-agnostic.
