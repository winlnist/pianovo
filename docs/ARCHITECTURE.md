# Architecture

Sightlink Piano should use a clean architecture that keeps musical truth, practice behavior, input adapters, rendering, persistence, and UI separate.

## Dependency Rule

Dependencies point inward:

```text
SwiftUI App/UI
  -> Programme Domain
  -> Practice Engine
  -> Music Domain

CoreMIDI Adapter
  -> Music Domain

Notation Renderers
  -> Renderer Adapters
  -> Music Domain

MusicXML Importer
  -> Music Domain

FullScoreRendering
  -> Verovio

Persistence
  -> Progress Models / Practice Results
  -> Stable Music Event IDs

Reference Material Resolution
  -> Programme Source IDs
  -> Logical Material Metadata
```

The Music Domain must not depend on SwiftUI, CoreMIDI, Verovio, networking, persistence, or infrastructure frameworks.

## Layers

### Music Domain

The framework-independent source of truth for music concepts:

- Pitch and octave.
- Accidentals.
- MIDI note number conversion rules.
- Clefs and grand staff assignment.
- Notes, chords, rhythm values, measures, score events.
- Stable identifiers for notes, chords, and score events.
- Staff position and ledger-line calculation.

The domain should be usable from unit tests without app launch, device input, rendering, or persistence.

Milestone 5.7 adds Full Score Domain types for future imported songs. The score model describes musical structure only:

```text
Score
  -> Parts
  -> Staves / Measures
  -> Voices / ScoreEvents
```

Score events can represent notes, chords, or rests with exact duration, exact position, staff identity, voice identity, tie state, and stable identity. This model remains independent from MusicXML, Verovio, MIDI, rendering coordinates, practice progress, and persistence.

### Programme Domain

Milestone 6D adds a Programme Domain for planned curriculum structure. It models `PracticeProgramme`, `ProgrammeWeek`, `PracticeDay`, `PracticeBlock`, `PracticeAssignment`, `ExerciseSource`, `MasteryRule`, and `MasteryState`.

The Programme Domain is reusable and framework-independent. It must not import SwiftUI, CoreMIDI, PDFKit, Verovio, WebKit, networking, or persistence frameworks. It also does not reference direct `ScoreEventID` values, Verovio positions, PDF pages, MusicXML element IDs, measures, notes, or fingerings. Assignments reference stable source IDs from an explicitly supplied `ExerciseSourceCatalogue`; later adapter layers can map those sources to inspected score material.

Validation is split into general structural validation and Pianovo policy validation. General validation checks stable identifiers, ordering, positive durations, required fields, and catalogue/rule references. Pianovo policy validation checks the approved twelve-week shape: seven days per week, six practice days, one recovery/reflection day, and morning/evening practice structure where applicable.

Mastery states describe learning status only: learning, stabilizing, nearly mastered, and mastered. Manual override is provenance for a future mastery-evaluation/progress layer, not a state in the Programme Domain.

### Import Adapters

Importers translate external file formats into Music Domain models. Milestone 6A adds a MusicXML adapter for a small supported `score-partwise` subset. The importer may use Foundation XML parsing, but MusicXML parser state, XML nodes, file UI, and format-specific details must not leak into the Full Score Domain.

### Practice Engine

The practice engine owns exercise behavior:

- Generated reading exercise.
- Ordered measures and musical events.
- Current event index.
- Expected answer.
- Played input interpretation.
- Matching rules.
- Correct and incorrect counts.
- Session progress.
- Advancement rules.

Practice logic is separate from rendering. A renderer displays exercises and highlights the active event; it does not decide whether a note is correct.

### Practice UI Coordination

The Version 0.1 practice screen uses a thin SwiftUI-facing view model to own a stable `PracticeSession`, selected reading mode, selected pitch range, and presentation-only feedback state. The screen owns a stable `MIDIInputService` for as long as the practice UI is alive, observes semantic `MIDIInputEvent` values, and passes note-press inputs into the view model.

Production practice UI presents a paper-like music sheet as the stable base layer and uses an auto-hiding overlay HUD for connection status, connected source name, reading mode, range controls, reset, and `PracticeStatistics`. Showing or hiding the HUD must not resize the sheet, change system layout, regenerate the exercise, or change the current event index. Raw MIDI source counts, endpoint references, OSStatus values, and debug logs stay isolated in `MIDIDebugView` for troubleshooting and are not part of the production launch experience.

Current app launch flow:

```text
Sightlink_PianoApp
  -> ContentView
  -> PracticeScreen
  -> PracticeViewModel / PracticeSession
  -> SightReadingPageView
```

Milestone 6F.2 adds explicit application dependency composition without changing the visible Practice destination. `Sightlink_PianoApp` creates `AppDependencies`, `ContentView` passes them into `AppShellView`, and Practice still constructs the existing `PracticeScreen`.

The future Today screen will consume a `@MainActor` `TodayViewModel` that loads presentation state from the Pianovo seed programme, persisted progress, latest mastery decisions, reference-material resolution, document availability, and deterministic temporal context. This is application-facing presentation state only; it does not start sessions, mutate progress, display PDFs, or perform MIDI/audio analysis.

Persisted active programme progress is authoritative. Today state does not advance week/day from calendar date, and first launch remains an explicit programme-not-started state until a future UI provides a Start Programme action.

Production dependency bootstrap creates and strongly retains the SwiftData `ModelContainer` for the dependency lifetime. If container creation fails, persistence is represented as unavailable; the app does not crash and does not silently switch to temporary in-memory storage.

### MIDI Adapter

MIDI is an input adapter:

- Detect CoreMIDI devices.
- Observe note-on and note-off messages.
- Convert MIDI note numbers into domain pitches.
- Publish domain-level input events to the practice engine.

The Music Domain can define pitch conversion behavior, but it must not import or depend on CoreMIDI.

The initial CoreMIDI implementation uses a compatibility-focused MIDI 1.0 input path (`MIDIClientCreateWithBlock`, `MIDIInputPortCreateWithBlock`, `MIDIPortConnectSource`, and `MIDIPacketList` callbacks). This matches the packet-list behavior of the known-working reference app for the current physical iPad/piano troubleshooting target. CoreMIDI resources and endpoint identifiers stay inside the MIDI adapter. The adapter emits semantic note press/release events containing domain `Pitch`, MIDI note number, velocity, and channel metadata.

CoreMIDI receive callbacks do minimal parsing work and hand semantic events to the main application context asynchronously. Device setup changes trigger source refresh so newly connected sources are attached and removed sources are disconnected.

Current MIDI-to-practice flow:

```text
Physical piano
  -> CoreMIDI
  -> MIDIInputService
  -> MIDIInputEvent
  -> PracticeViewModel
  -> PracticeSession
```

Physical MIDI input has been confirmed working on iPad using this reliable startup sequence: app not running, connect cable, power piano, then launch Sightlink Piano. Hot-plug/device-refresh code exists, but reconnect behavior has not been hardened or fully validated.

### Rendering

Rendering should be adapter-based. Renderers receive renderer-specific view models derived from the Music Domain.

For simple interactive drills, plan for a lightweight native SwiftUI/Core Graphics renderer. This should support the Version 0.1 grand staff and correct ledger-line rendering.

The Version 0.1 drill renderer owns notation font details. It bundles Bravura locally as a SMuFL-compatible font, registers it inside the rendering layer, and keeps SMuFL codepoints in renderer-specific glyph helpers. The Music Domain continues to expose only semantic staff placement and ledger-line data.

Milestone 5.6 adds a continuous sight-reading renderer for generated exercises. The musical structure is:

```text
ReadingExercise
  -> Measures
  -> Events
```

The page layout is separate:

```text
SightReadingLayout
  -> Systems
```

The same exercise may lay out as different systems in portrait and landscape without changing event identity, statistics, or current event index. The sheet surface remains white with black notation in both light and dark system appearances.

Milestone 6B adds Verovio as the current full-score rendering engine because it can render complex notation and consume structured music formats. The app should remain renderer-agnostic so Verovio can be replaced or supplemented later.

Current Milestone 6B flow uses parallel adapters over the same MusicXML source:

```text
MusicXML
  -> MusicXMLImporter
  -> Score Domain

MusicXML
  -> VerovioScoreRenderer
  -> SVG FullScoreRenderResult
  -> FullScoreDebugView
```

This does not make the Full Score Domain depend on source XML text. It also does not round-trip `Score` back into MusicXML yet.

Future full-score rendering may use an adapter from the Score Domain to the selected renderer. Renderer IDs, SVG IDs, pages, systems, coordinates, fonts, glyphs, SMuFL codepoints, and WebKit display details must stay outside the Score Domain.

The debug SVG display uses `WKWebView` inside `Rendering/FullScore` only. WebKit must not leak into MusicDomain, Practice, MIDI, or the native drill renderer.

### Persistence and Progress

Progress data is separate from musical score data.

Progress records should reference stable domain event identifiers rather than embedding score content. This allows practice results to point to specific notes, chords, or events across sessions.

Milestone 6E adds a Progress domain and a local SwiftData persistence adapter. Progress records and repository protocols remain Foundation-only and do not import SwiftData, Core Data, SwiftUI, MIDI, PDFKit, Verovio, networking, or renderer frameworks. SwiftData `@Model` types and `ModelContext` usage are isolated inside `Persistence/SwiftData`.

Programme progress stores student-specific state: active programme ID/version, current week/day references, assignment completions, sessions, attempts, reflections, and mastery decisions. It does not duplicate the immutable twelve-week seed programme. `ProgrammeProgressSnapshot` is assembled by repositories as a read model; assignment completion records are the authoritative completion source.

The SwiftData adapter is `@MainActor` because `ModelContext` is actor-confined. Domain repository protocols are `async throws`, allowing adapters to report validation, duplicate identity, not-found, and persistence failures without exposing SwiftData.

The latest mastery repository query returns one decision per assignment/source target for a programme. Newer timestamps win; if timestamps are equal, the lexicographically greater stable mastery-decision ID is the deterministic tie-breaker.

### Reference Materials

Milestone 6F.1 adds a Foundation-only reference-material catalogue and source-resolution boundary. Catalogue entries describe known materials with stable logical identifiers, expected-document metadata, format, language, attribution, rights status, access requirement, and optional components.

The reference-material catalogue must not hard-code development-machine paths or imply that inspected PDFs/audio are bundled, accessible, licensed for distribution, or score-aware. Document availability is supplied through a narrow provider protocol; the default provider reports known materials as unavailable until a later document-access adapter resolves user-imported documents, security-scoped references, application-managed copies, or legally approved bundled resources.

Programme assignments continue to reference `ExerciseSourceID`; mapping from `ExerciseSourceID` to `ReferenceMaterialID` lives in the reference-material resolver rather than in Programme Domain.

Beyer Op. 101 No. 63 is represented as one logical material with distinct required `Seconda` and `Prima` components for the inspected 88-page Edition Peters scan. PDF page locators distinguish zero-based PDFKit page indices from printed page labels, and exact crop rectangles remain deferred to later visual verification.

## Module Direction

The initial Xcode project has a single app target named Sightlink Piano. As the code grows, prefer grouping by responsibility before adding separate packages or frameworks.

Likely future groups:

- `MusicDomain`
- `Programme`
- `Practice`
- `MIDI`
- `Rendering`
- `Progress`
- `ReferenceMaterials`
- `App`

Separate Swift packages or framework targets can be considered when boundaries become valuable for build times, reuse, or stronger dependency enforcement.

## Testing Strategy

Each feature should have unit-testable domain logic.

Prioritize tests for:

- MIDI note number to pitch conversion.
- Pitch range generation.
- Clef assignment and staff placement.
- Ledger-line calculation.
- Expected answer matching.
- Chord matching.
- Session statistics.

UI and adapter tests can be added after the core domain and practice engine are stable.
