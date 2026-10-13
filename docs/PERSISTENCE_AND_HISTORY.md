# Persistence and History

Milestone 6E adds a local-first persistence foundation for student progress and practice history. It does not add screens, app-root wiring, MIDI capture, audio recording, coach/API integration, cloud sync, automatic score assessment, Beyer PDFs, or 6F work.

## Boundary

Progress domain records and repository protocols live outside SwiftData. They import Foundation and may reference stable Programme Domain IDs such as `PracticeProgrammeID`, `ProgrammeWeekID`, `PracticeDayID`, `PracticeBlockID`, `PracticeAssignmentID`, `ExerciseSourceID`, `MasteryRuleID`, and `MasteryState`.

SwiftData-specific `@Model` classes, `ModelContext`, schema declarations, and migration-plan details stay inside `Persistence/SwiftData`. Domain protocols do not expose SwiftData types, fetch descriptors, persistent identifiers, SwiftUI, MIDI, PDFKit, Verovio, networking, or persistence-framework details.

## Authoritative Progress Representation

The authoritative persisted progress state is:

- One active programme progress record per programme.
- Separate assignment completion records.
- Separate practice sessions, attempts, reflections, and mastery decisions.

`ProgrammeProgressSnapshot` is a domain-facing read model assembled by the repository. It is not persisted as a duplicate summary. The immutable twelve-week Pianovo seed programme remains source-defined; persistence stores programme ID/version and stable references into that definition rather than copying the full programme into local storage.

## Records

- `ActiveProgrammeProgress`: active programme identity/version and current week/day position.
- `AssignmentCompletionState`: canonical assignment completion state.
- `PracticeSessionRecord`: session identity, programme/version, assignment/source context, absolute start/end timestamps, local-day context, and lifecycle outcome.
- `PerformanceAttemptRecord`: minimal attempt identity, existing session reference, programme/version, assignment/source context, timestamp, and lifecycle outcome.
- `StudentReflectionRecord`: note text plus programme-day and/or session context.
- `MasteryDecisionRecord`: automatic/manual provenance, resulting `MasteryState`, assignment/source, rule ID/version when applicable, optional reason, and timestamp.

`PerformanceAttemptRecord` intentionally avoids speculative tempo, accuracy, raw MIDI, score-analysis, or audio fields. Milestone 6G can add analysis results through an extension layer after MIDI capture and assessment are designed.

## Write Semantics

Session, attempt, reflection, and mastery-decision IDs are stable insert-only identities. Recording the same ID twice returns a duplicate-ID repository error.

Active programme progress and assignment completions are upserts because each programme and programme-assignment pair has one canonical current state.

Repository operations are `async throws` so local persistence failures and future adapter implementations can report errors without changing the domain API.

`latestMasteryDecisions(programmeID:)` supports application-facing summary state without loading complete chronological history. It returns the latest applicable mastery decision per assignment/source target. Decisions are returned in deterministic assignment/source target order; when two decisions for the same target have equal timestamps, the lexicographically greater stable mastery-decision ID is treated as latest.

## Date Strategy

Every temporal record stores:

- Absolute `Date`.
- IANA time-zone identifier, such as `Europe/London`.
- Supported calendar identifier.
- Local-day key derived at record creation.

Historical local-day keys must not be recalculated using the device's current time zone. The initial supported calendar is Gregorian; unsupported calendar types are not stored as arbitrary strings.

## Schema Versioning

SwiftData uses `PracticeHistorySchemaV1` as a real `VersionedSchema` and `PracticeHistoryMigrationPlan` as the migration plan. Version one has no migration stages because there is no older schema to migrate from.

To introduce version two later:

1. Add `PracticeHistorySchemaV2` with the new model shape.
2. Append it to `PracticeHistoryMigrationPlan.schemas`.
3. Add the required lightweight or custom `MigrationStage`.
4. Add round-trip and migration tests using sample version-one data.

## Deletion and Reset

`deleteSession` is an atomic repository operation where practical. It deletes the session, attempts belonging to that session, and reflections attached to that session. Day-level reflections that are not attached to the deleted session remain.

`resetProgrammeProgress` keeps historical sessions, attempts, and reflections. It clears active programme position, assignment completion state, and current mastery/progression state for the programme. It does not silently delete practice history.

`deleteAllPersonalPracticeData` deletes persisted programme progress, assignment completions, sessions, attempts, reflections, and mastery decisions. It does not delete immutable programme seed definitions or bundled source metadata.

## App Bootstrap

Milestone 6F.2 wires production persistence at the application composition root. `AppDependencyFactory` creates the SwiftData `ModelContainer`, creates repository adapters from a `ModelContext`, and keeps the container strongly retained by `AppDependencies`.

If SwiftData bootstrap fails, dependencies expose persistence as unavailable and repository references are nil. The app must not silently substitute in-memory persistence in production because that could make practice data appear saved when it will disappear. Existing non-persistence features should still be constructible so the app can present an honest recovery state in future UI milestones.

## Testing

Milestone 6E uses both an in-memory repository and SwiftData tests with an in-memory `ModelContainer`. Tests cover duplicate IDs, validation failures, local-day stability, reset semantics, cascade deletion, schema versioning, and repository round trips without creating persistent personal data files.

## Assigned Sessions (6F.4)

Assigned generated sight-reading prepares an active session in memory. No record is inserted at start. End & Save inserts one immutable `PracticeSessionRecord` with `.stopped`, its original stable context, start/end timestamps, and local-day contexts. Backgrounding freezes the observed end; force-quit recovery is deferred. Discard does not write or delete history. A previously successful but ambiguously reported save is never deleted by discarding its in-memory copy.

Numeric `PracticeStatistics` are shown only in the immediate summary. V1 has no metric fields, and none are added. Session start/end do not create attempts, reflections, completions, mastery decisions, or programme-position updates. Optional end fields remain part of V1 but are not used as a mutable active-session contract.

`recordSession` uses a fresh context with autosave disabled, rolls back that context on failure, and verifies success using a separate reader. This does not roll back pending work in the repository's original context. Session events in `chronologicalHistory` are read from a fresh context so duplicate reconciliation cannot mistake an unsaved insertion for durable success. Other repository operations retain their existing semantics.

Retry preserves the exact identity, context, timestamps, and outcome. An existing identical durable record confirms success; a conflicting duplicate is a structured failure and is never overwritten. No schema migration or repository protocol change is required.

## Self-Reported Assignment Completion (6F.5)

Today writes the existing `AssignmentCompletionState` on an explicit learner confirmation. All current-day assignments are eligible, including outside-app work. Beyer required-part confirmations are transient UI acknowledgements checked by the application layer, not persisted component records. There is no automatic completion from session saving or inferred mastery.

Mark complete uses one injected timestamp for `updatedAt` and `completedAt`; Undo completion writes `.notStarted`, a new `updatedAt`, and nil `completedAt`. Existing notes remain intact. Programme position, session/history records, and mastery records are unchanged.

Completion upserts use an isolated context with autosave disabled, rollback on failure, and a separate durable reader. `loadProgress` reads completion models from a fresh context; its active-progress read retains its existing semantics. Pending changes in the original context are not saved or rolled back by completion writes. The V1 schema and repository protocols stay unchanged.

The application serializes actions, checks the saved position before writing, and verifies durable completion afterward. Retry preserves the original intent and timestamp; a matching desired status already in storage needs no new write. Refresh reads stored state and clears the pending retry without undoing a save that reached storage. Independent concurrent progress writers and component-level progress remain future work.


## Local History and private learner notes (6F.11)

History now presents real saved original sessions/reflections/attempts/mastery decisions, independent learner-plan completion/undo records, and private learner notes in deterministic reverse timestamp order. Session duration comes only from saved start/end times. Numeric accuracy, tempo, raw MIDI and performance statistics are not fabricated. Canonical original assignment completion is not expanded into a made-up historical event stream. Stored local-day/time-zone context is displayed without rebucketing into the current device zone.

Notes can be explicitly added to a saved session, a recorded learner assignment/day, or the currently selected started programme day. Context is frozen when opening the form; saves freeze UUID, trimmed text, timestamp/local-day and audience before suspension. Notes are append-only in this step: no editing, deletion or automatic reflection generation is offered. Retry reconciles only an exactly matching durable note. Cancel does not write, and closing after an ambiguous save does not delete a note already saved.

`PrivateLearnerNoteRepository` is a separate MainActor async/throwing boundary. `LibrarySchemaV5` adds one private-note model with an explicit V4-to-V5 lightweight migration, retaining all previous Library model definitions and the unchanged original progress V1 store. Its adapter writes through a fresh context with autosave disabled, rolls back failures and verifies using a fresh reader. Notes retain their captured context even if their original session is later deleted through an existing lower-level API; they do not recreate that session. Existing legacy reset/delete-all APIs remain scoped to legacy records and do not claim to clear newer Library learner data. A future combined deletion/settings workflow must explicitly cover both stores and private notes.

History loads legacy records, learner records and notes independently. A failed/unavailable source is labelled; previously read rows are retained and an incomplete load is never presented as a complete empty history. Note creation never records a session, attempt, completion, mastery decision, or position change. The production note adapter has no in-memory fallback.

| Note audience | Current boundary |
| --- | --- |
| Private learner note/reflection | Implemented locally; not shared |
| Student-visible teacher feedback | Planned; requires author identity and authorised relationship |
| Private teacher lesson note | Planned; teacher-only audience and access rules required |
| Shared lesson note | Planned; explicit recipients and permissions required |

The only new stored audience is `privateLearner`. Teacher notes, collaboration, account roles, community publishing and sync remain unimplemented. Future content publication must exclude private learner history/notes. Manual validation confirmed using History and adding private notes. Restoration after reopening and broader workflow checks remain unconfirmed.
