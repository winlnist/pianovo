# Pianovo

*Practice measured. Progress earned.*

Pianovo is a native SwiftUI piano-practice app for iPhone and iPad. Today provides a saved programme plan, while Practice turns a physical MIDI piano into an interactive sight-reading exercise: the app generates notation, listens for played notes through CoreMIDI, and advances only when the learner plays the expected pitch.

The project began with a personal learning problem. Static sheet music shows *what* to play, but it does not organise practice, measure the attempt, or help a learner and teacher agree on what comes next. Pianovo combines a working MIDI practice loop with a Today experience for starting a structured twelve-week programme and viewing its saved day. Local History is implemented and ready for device validation; document access and teacher-guided planning remain future workflows.

> **Development status:** active portfolio project. Today, Practice, and the private local exercise Library are user-facing. Milestone 6F.4 connects Today’s generated sight-reading assignments to MIDI Practice and saved session records. Milestone 6F.5 adds explicit learner-reported assignment completion and undo. Personal learner programmes and explicit day navigation are implemented locally and ready for device validation. Document access and teacher workflows remain planned.

## App preview

| Practice controls | Distraction-free score |
| --- | --- |
| ![Pianovo running on an iPad simulator with the Practice destination, generated treble score, range controls, MIDI status, and session statistics](docs/images/pianovo-practice-ipad-controls.png) | ![Pianovo running on an iPad simulator with its controls hidden and generated treble score filling the practice surface](docs/images/pianovo-practice-ipad-score.png) |

Both images are direct captures of the running app on an iPad Pro 11-inch (M5) simulator. The disconnected MIDI state is expected in the simulator.

## What works today

### Original twelve-week programme in Today

- On initial use, Today offers an explicit **Start Programme** action that initializes the original twelve-week programme at **Week 1, Day 1**.
- Persists and restores the current programme position across app launches; repeated starts preserve existing progress, and calendar dates do not advance the saved day.
- Shows **Morning** and **Evening** practice sections, plus a distinct recovery/reflection-day presentation for saved recovery days.
- Presents assignment goals, planned duration, and completion/mastery status when records exist.
- Begins Beyer work at **Op. 101 No. 63**, with **Seconda** and **Prima** shown as required components of one exercise.
- Represents reference-material availability honestly, keeping assignments visible even when documents are unavailable.
- Provides structured loading, unavailable, and failure states, with retry where appropriate.
- Uses responsive native iPhone/iPad layouts, including two columns at suitable widths, Dynamic Type, and VoiceOver labels.

### Self-reported assignment completion

- **Mark complete** and **Undo completion** work for every assignment in the current saved day, including outside-app practice and recovery/reflection work.
- Beyer No. 63 requires confirmation that both **Seconda** and **Prima** were practised before completing the one assignment.
- Completion status persists across app launches. Failed changes support retry or a fresh read of Today.
- Completion is the learner’s report, not an assessment of mastery. Undo returns the assignment to Not started while preserving practice history and mastery status.

Completion is separate from saving a session and does not advance programme position.

### Assigned sight-reading sessions

- Launch a generated sight-reading assignment from Today, review its goal and planned duration, and choose Treble/Bass and a natural-note range before **Start Session**.
- Practise with MIDI input using the existing notation and statistics; mode, range, and reset controls are locked during the assigned session.
- **End & Save** stores the assignment context, start/end times and local-day context, and a stopped outcome, then shows an immediate summary of the actual session statistics.
- Retry a failed save using the same session identity. Backgrounding freezes the session; returning offers save or discard without resuming or counting background time.

Only generated sight-reading assignments can launch in-app MIDI Practice; other material has no in-app practice action. Saving does not mark an assignment complete, evaluate mastery, or advance the programme. Numeric statistics remain temporary, and Today cannot open reference documents.

### MIDI sight-reading Practice

- Continuous single-staff **Treble Reading** and **Bass Reading** exercises.
- Responsive notation arranged into measures and systems on a paper-like practice surface.
- Quarter notes, stems, barlines, ledger lines, and a highlighted current event.
- Configurable natural-note ranges: C4-C6 for treble and C2-C4 for bass.
- Physical piano input through CoreMIDI, validated with a Yamaha P-45 and iPad.
- Correct notes advance the exercise; incorrect notes keep the current event active.
- A new 64-note exercise is generated after the current exercise is completed.
- Session-only counts for correct answers, wrong attempts, accuracy, streak, and completed prompts.
- Adaptive iPhone/iPad layout and an auto-hiding practice HUD that does not reflow the score.

Navigation exposes Today, Practice, Library, and History. Progress, Ask My Teacher, and Settings remain planned and are hidden from navigation.

### Private local exercise Library

- Create exercises with a title, category, instructions, and learning purpose.
- Browse/search, view details, edit, archive, and restore them from the Archived list.
- Retain stable exercise identity and earlier saved revisions across edits and app launches.
- Retry failed writes or refresh to check durable saved status.

Library exercises are private written guidance on the device. Saved versions can appear in Today through independent learner programmes; they do not launch MIDI Practice. Document import, teacher sharing, cloud sync, and AI coaching remain planned. Exercise creation, archiving, and restoration have been manually validated.

### Reusable exercise templates

- Create or edit private templates with a name and exercise defaults; optionally begin with a Pianovo starter pattern.
- Browse/search, archive, and restore templates in Library → Exercise templates.
- **Create exercise** opens a pre-filled form you can adapt before saving an independent exercise.
- Preserve the source template version as origin; later template changes leave existing exercises untouched.

Templates contain written defaults, not automatically generated notation or programme assignments. Sharing and AI remain future work; learner-programme integration is added below. The Library V1-to-V2 migration preserves existing exercises and revisions. Manual validation confirmed template navigation and exercise creation from a template.

### Programme templates — ready for device validation

- Arrange saved exercise versions into ordered weeks, days, and named sections, with a goal and planned minutes for each placement.
- Add recovery/reflection days and adapt blank or Morning/Evening starter structures; configure longer programmes up to 104 weeks.
- Edit, reorder, copy, archive, and restore private templates while preserving earlier revisions and source origin.

This local editor creates reusable templates. Use as my programme creates an independent learner plan through 6F.10 below. Initial 6F.9 use has been manually confirmed; broader programme-editor checks remain pending.

### Your own programme in Today — ready for device validation

- Create an independent learner plan from a programme template, retaining the selected exercise versions and source origin.
- View its saved day in Today, report completion/undo, and explicitly move through days and weeks. Unfinished-work warnings allow continuing while keeping the recorded status.
- Edit the personal plan without changing its template; replacement work starts uncompleted and earlier records are preserved.
- Switch back to the original twelve-week programme with its position and history intact. Finishing a learner plan does not wrap or infer mastery.

Authored exercises remain written guidance. The original assigned sight-reading flow and standalone MIDI Practice remain available; authored category labels do not make exercises MIDI-playable. Interactive 6F.10 validation is pending.

### Local History and private notes — ready for device validation

- Browse actual saved sessions, learner completion/undo, and private reflections with recorded dates and local-day context.
- Add a private note to a saved session, learner assignment/day, or the currently selected started programme day.
- Keep failed-save retries tied to the same note, context and timestamp; notes do not change progress or mastery.

Notes are append-only and private on this device. Accuracy, tempo and numeric statistics are not invented. Teacher/shared notes, Progress and remote collaboration remain planned. Manual validation confirmed using History and adding private notes. Restoration after reopening and broader workflow checks remain unconfirmed.

## Implemented foundations

These implemented and tested components support the app and future work; their presence does **not** imply complete user-facing workflows:

- A framework-independent Music Domain and Full Score Domain with stable event identifiers.
- A limited MusicXML `score-partwise` importer.
- Development-only full-score rendering of MusicXML fixtures with Verovio.
- A validated twelve-week programme model used by the original Today route; advancement/editing of this original seed remains deferred.
- SwiftData repositories for programme progress, sessions, attempts, reflections, and mastery decisions.
- A logical reference-material catalogue that keeps licensing and file availability explicit.
- Production dependency composition and Today presentation state, now connected to the working Today screen.

This distinction is deliberate: having a persistence model or view model in the codebase does not mean learners can already use the corresponding feature in the app.

## Engineering highlights

- **Native interaction:** SwiftUI and CoreMIDI provide a responsive practice loop with physical-instrument input.
- **Separated domains:** music, practice behaviour, curriculum, progress, rendering, and infrastructure have explicit boundaries.
- **Renderer strategy:** lightweight native notation supports interactive drills; Verovio is isolated behind a separate adapter for future full scores.
- **Stable identity:** score events, programme elements, assignments, and persisted records use stable identifiers.
- **Local-first persistence:** SwiftData is confined to an adapter layer behind asynchronous repository protocols.
- **Deterministic tests:** injected clocks, time zones, calendars, random sources, and in-memory stores avoid dependence on device state.
- **Responsible source handling:** reference PDFs and audio are not committed or bundled while usage rights remain unverified.

## Technology

- Swift, SwiftUI, and Swift Testing
- CoreMIDI
- SwiftData with a versioned schema and migration-plan scaffold
- Foundation `XMLParser` for the supported MusicXML subset
- Native SwiftUI/Core Graphics notation with the bundled Bravura SMuFL font
- Verovio through Swift Package Manager for development-facing full-score rendering
- WebKit, isolated to the Verovio SVG debug view

## My role

I created Pianovo to combine my experience in learning design with hands-on product and software development. I defined the learner problem, product direction, milestones, acceptance criteria, architecture boundaries, and test strategy; guided the iterative Swift implementation; reviewed each change; and validated MIDI behaviour on a Yamaha P-45.

The implementation has been developed with Codex as an AI coding collaborator. My contribution is therefore best described as product ownership and AI-assisted engineering: translating a real learning need into technical requirements, evaluating trade-offs, testing the result, diagnosing integration issues, and maintaining the product and repository documentation.

## Build and run

### Requirements

- A Mac with Xcode and an iOS/iPadOS 26.5 SDK or later.
- iOS/iPadOS deployment target 26.5.
- An iPhone or iPad simulator for the interface, or a compatible physical device for CoreMIDI input.
- Optional: a class-compliant MIDI piano and the appropriate USB connection. The hardware path has been validated with a Yamaha P-45 connected by USB-B to USB-C.

No API key is required for the current build. Verovio resolves automatically through Swift Package Manager at the revision pinned in `Package.resolved`.

### Xcode

1. Clone the repository: `git clone https://github.com/winlnist/pianovo.git`.
2. Open `Pianovo.xcodeproj`.
3. Select the shared `Pianovo` scheme.
4. Choose an iPhone/iPad simulator or a configured physical device.
5. Build and run.

For the most reliable physical MIDI startup sequence, connect the cable, power on the piano, and then launch Pianovo.

### Command line

Replace the destination when that simulator is not installed locally:

```bash
xcodebuild \
  -project Pianovo.xcodeproj \
  -scheme Pianovo \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  build

xcodebuild \
  -project Pianovo.xcodeproj \
  -scheme Pianovo \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  test
```

### Verified baseline

Milestone 6F.4 completed a clean simulator build and all **213 tests across 22 suites passed** using an iPad Pro 11-inch (M5) simulator. The existing Practice portfolio captures were produced from the running app on iPadOS 27.0.

The Today experience was manually validated on a physical iPad: initial navigation, explicit start at Week 1 Day 1, Morning/Evening sections, Beyer No. 63 with Seconda and Prima, honest document availability, position restoration after reopening, and portrait/landscape layouts. Practice remained operational.

The current Practice experience was also manually verified on 27 September 2026 using a physical iPad Pro with an M5 processor and a Yamaha P-45 digital piano connected directly by a USB-B to USB-C cable for USB MIDI. Pianovo received the played notes, correctly played notes advanced the sight-reading exercise, and session statistics updated, confirming that the core Practice workflow operated successfully on physical hardware.

The 6F.4 assigned sight-reading flow was also manually validated on a physical iPad with a Yamaha P-45: preparation, session start, MIDI input and statistics, assigned-session controls, End & Save and its immediate summary, return to Today with programme position preserved, and the tested interruption/background behaviour. Standalone Practice remained operational.

Milestone 6F.5 automated verification passed **231 tests across 23 suites**, including completion/undo restoration and save-failure handling. The completion controls were also manually validated on a physical iPad: marking complete, undoing completion, restoration after reopening, required Beyer parts, and independence from assigned-session saving.

Milestone 6F.7 automated verification passed **255 tests across 26 suites** and a clean simulator app build. Library validation covers disk restoration, immutable revisions, failed-save retry, stale edits, archive/restore, and preservation of the existing progress store. Manual validation confirmed exercise creation, archiving, and restoration.

Milestone 6F.8 automated verification passed **269 tests across 28 suites** and a clean simulator build, including a real V1-to-V2 Library migration and independent exercise creation from template revisions. Manual validation confirmed template navigation and exercise creation from a template.

Milestone 6F.9 automated verification passed **282 tests across 30 suites** and a clean simulator build, including exact legacy Library migrations, pinned exercise versions, independent programme-template copies, and failed-save retries. Initial use has been manually confirmed; broader programme-editor checks remain pending.

Milestone 6F.10 automated verification passed **298 tests across 32 suites** and a clean simulator build, including independent learner-plan identities, real legacy-store preservation, explicit selection/navigation, immutable content, completion/undo, and idempotent failed-save retries. Interactive learner-programme validation is pending.

Milestone 6F.11 automated verification passed **305 tests across 33 suites** and a clean simulator build, including real History projection, private-note validation/retry/durable restoration, and a V4-to-V5 migration preserving existing learner plans. Manual validation confirmed using History and adding private notes. Restoration after reopening and broader workflow checks remain unconfirmed.

## Current limitations

- Practice is single-staff and one note at a time; there is no mixed grand staff, two-hand, chord, or rhythm-aware practice yet.
- Generated exercises use natural pitches and quarter-note notation rather than full musical context.
- Assigned sight-reading saves session context and times, but numeric statistics remain temporary. Standalone Practice does not save sessions.
- Today has no automatic mastery evaluation. Only independent learner plans have explicit day navigation; the original seeded programme has no advancement controls.
- Unsaved assigned sessions cannot be recovered after the app closes; force-quit recovery is deferred.
- Progress, Ask My Teacher, and Settings remain planned and are hidden from navigation.
- Today cannot open, import, crop, or display the Beyer PDF; reference-material availability is informational.
- MusicXML importing and Verovio rendering are development foundations without a production file picker or interactive-song UI.
- PDF/photo import, optical music recognition, audio or raw MIDI performance recording, tempo/rhythm analysis, teacher accounts and teacher-created plans, Ask My Teacher chat, coach API, cloud sync, and collaboration remain planned workflows.
- MIDI reconnect/hot-plug behaviour needs more real-device hardening.
- The project retains known compiler-warning cleanup tasks despite the green build and test suite.

## Next milestones

1. Validate programme-template, learner-plan, History and private-note workflows on device.
2. Introduce document access and licensed/user-imported reference-material presentation.
3. Add score-aligned MIDI timing and correctness analysis.
4. Build learner progress and teacher planning workflows before considering accounts or cloud sync.

See the detailed [roadmap](docs/ROADMAP.md) for completed milestones and longer-term work.

## Documentation

- [Product](docs/PRODUCT.md) — problem, audiences, present experience, and product direction.
- [Architecture](docs/ARCHITECTURE.md) — layers, dependencies, adapters, and persistence boundaries.
- [Roadmap](docs/ROADMAP.md) — completed milestones and planned work.
- [Music Domain](docs/MUSIC_DOMAIN.md) and [Score Domain](docs/SCORE_DOMAIN.md) — musical concepts and full-score model.
- [Practice Engine](docs/PRACTICE_ENGINE.md) — exercise generation, matching, and statistics.
- [Programme Domain](docs/PROGRAMME_DOMAIN.md) — twelve-week structure and mastery rules.
- [Content and Programmes](docs/CONTENT_AND_PROGRAMMES.md) — planned reusable exercises/templates, individual plans, and future sharing/backend boundaries.
- [Persistence and History](docs/PERSISTENCE_AND_HISTORY.md) — stored records, schema, and deletion semantics.
- [Reference Materials](docs/REFERENCE_MATERIALS.md) — logical catalogue and document-access boundaries.
- [Import Pipeline](docs/IMPORT_PIPELINE.md) — MusicXML support and future PDF/photo recognition.
- [Contributor guidance](AGENTS.md) — constraints for future development work.
