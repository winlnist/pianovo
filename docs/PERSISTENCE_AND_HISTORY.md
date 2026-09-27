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
