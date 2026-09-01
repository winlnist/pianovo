# AGENTS.md

Guidance for future Codex work on Sightlink Piano.

## Before Implementing

- Inspect the current Xcode project structure before changing files.
- Read the relevant documentation before implementing a feature:
  - Product behavior: `docs/PRODUCT.md`
  - Architecture and boundaries: `docs/ARCHITECTURE.md`
  - Milestone scope: `docs/ROADMAP.md`
  - Music concepts: `docs/MUSIC_DOMAIN.md`
  - Practice behavior: `docs/PRACTICE_ENGINE.md`
  - Import work: `docs/IMPORT_PIPELINE.md`
- Keep changes scoped to the requested milestone or task.
- Do not silently change architecture. If an architectural direction needs to change, update the docs and call it out.

## Coding Rules

- Keep the project buildable after each task.
- Prefer small, composable Swift types.
- Prefer testable, reusable, readable Swift over cleverness.
- Avoid premature abstractions, but keep extension points explicit where the docs identify them.
- Do not place business logic in SwiftUI views.
- Keep Music Domain code independent of SwiftUI, CoreMIDI, Verovio, networking, persistence, and other infrastructure frameworks.
- Treat MIDI as an input adapter, not as part of the Music Domain.
- Keep practice logic separate from rendering.
- Keep progress and user-performance data separate from the musical score model.
- Use stable identifiers for musical events so practice results can reference specific notes, chords, or events.
- Add or update tests for domain and business logic.
- Do not introduce third-party dependencies without documenting the reason and trade-offs.
- Update documentation when architectural decisions change.

## Version Discipline

Version 0.1 is intentionally small. Do not implement PDF recognition, AI recognition, full-song playback, or full MusicXML song practice unless the current task explicitly moves the roadmap to those milestones.

For Version 0.1, focus on:

- Grand staff note-reading.
- Configurable pitch range.
- MIDI note input.
- Played-note matching.
- Session statistics.

## Repository Hygiene

- Keep documentation and implementation in sync.
- Prefer focused changes over broad refactors.
- Avoid unrelated formatting churn.
- If generated files or Xcode metadata change unexpectedly, inspect them before including them.
- If the workspace has user changes, preserve them unless the user explicitly asks otherwise.
