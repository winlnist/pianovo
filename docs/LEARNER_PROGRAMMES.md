# Individual Learner Programmes and Today Integration (6F.10)

## Status

Implemented locally, with interactive device validation pending. The 6F.9 programme-template editor has passed 282 tests across 30 suites and a clean build; the user has confirmed initial use, with broader manual checks still pending. Its uncommitted changes must remain intact. The confirmed policies allow advancement after an unfinished-work warning and preserve the selectable original programme.

## Findings from the current implementation

- `TodayViewModel` loads the code-defined seed directly. Completion validation checks that same definition, version and current saved position. It cannot safely be pointed at a template without a separate instance/resolution boundary.
- Legacy position, completions and practice history reference `PracticeProgrammeID`, definition version, and stable week/day/block/assignment/source IDs. They do not reference authored exercise revisions or distinguish repeated template instantiations.
- `LibraryProgrammeTemplateRevision` stores ordered weeks/days/named sections with unique placement UUIDs and pinned exercise revisions. Those placement IDs belong to the reusable template, not a learner's progress records.
- Template sections have arbitrary names. Today currently groups legacy blocks by Morning, Evening and Recovery. A new projection must preserve section names and order rather than infer time-of-day behaviour from their text.
- Authored exercises are written guidance. The generated-MIDI practice action currently requires its explicit supported source ID and category. An authored sight-reading category alone cannot enable MIDI practice.

## Identity and instantiation

Instantiate a reviewed template revision into a private learner-plan draft. Allocate new plan, plan-revision, week, day, section and assignment-occurrence identities. Two uses of one template, and repeated exercises within one day, must never share completion identities. Retain source template/revision/name and creator attribution, and preserve pinned exercise references.

Validate and resolve every referenced exercise revision before creating the plan. Persist enough immutable content/context to interpret a saved plan and its historical records. Later exercise/template edits or archiving must not change already instantiated work. New template changes are adopted explicitly rather than silently on load.

Personal plan editing creates immutable revisions. Unchanged assignment occurrences retain their identity only if their referenced work and meaning remain unchanged. Replacement exercises get new occurrence identities. Existing completion and history remain attached to the revision/occurrence originally practised; copying a plan does not copy completed status.

## Legacy compatibility

Preserve the original progress/history schema, seed identifiers, saved position, completions and session records. Do not relabel old progress as belonging to a newly instantiated plan, copy completion to unrelated assignments, or infer history that was not recorded.

Introduce an explicit selection boundary between the legacy programme and independently instantiated plans. The original Today route remains the default until a learner explicitly creates/selects another programme. Selection failures must leave the previously acknowledged selection and legacy records intact. A read or migration failure cannot mean an empty programme, a new start, or an in-memory production fallback.

The first compatibility path can retain legacy records in their existing store and expose them through a legacy resolver. This is an explicit coexistence strategy, not conversion of the seed into authored Library exercises. Automatically importing the seeded Beyer/reference catalogue or making unsupported assignments playable is outside this step.

## Confirmed progression policy

- Only an explicit action changes the saved day. Calendar dates, time of day, assignment completion and End & Save do not advance it.
- Next Day moves through the saved order, including recovery days and week boundaries. It does not select a new Beyer exercise or infer mastery.
- If work is unfinished, disclose it before advancement. Confirmation may continue without completing it.
- Keep past unfinished/completed assignments and their original context available; navigating back must not reset or copy status.
- On the last day, present an explicit end-of-plan state. No wrap to Day 1, implicit reset, new template instantiation, or automatic mastery is allowed.
- Switching programmes preserves each plan's acknowledged position and records. The original twelve-week programme remains selectable with its saved position and records.

## Persistence and application boundaries

Learner-plan content, selected plan, position, occurrence-level completion, and provenance require explicit storage/repository boundaries rather than overloading template records or legacy progress protocols. The exact schema upgrade is V3-to-V4 as described below. Retain the original V1/V2/V3 Library model definitions and existing progress store models; verify real disk migrations and reopening.

Use fresh writer contexts with autosave disabled, rollback on failed transactions, and durable verification through a fresh reader. Freeze operation identities, expected revisions and intended content before suspension; creation, editing and completion also freeze timestamp/local-day context; retries must be idempotent. Concurrent actions and stale edits must fail without replacing newer state. Changing selected plans and advancing a day must not produce optimistic success before persistence acknowledges it.

Today consumes a resolved learner-plan projection with saved position, section order/names, exercise instructions, contextual goals/durations, and honest reference-material availability. Business rules and storage orchestration stay outside SwiftUI. Completion remains learner-reported and undoable; mastery, PDF access, tempo analysis, raw MIDI recording and numeric statistic persistence are not implied by this integration.

## Verification required before publication

- Two template instantiations and repeated exercise placements have distinct occurrence/progress identities.
- Plan editing, copying and source-template/exercise edits preserve provenance, pinned content, and existing records.
- Activation/switching, advancement, previous-day navigation, recovery/week transitions and final-day behaviour follow the confirmed policies and survive reopening.
- Unfinished work and failed/ambiguous writes remain honest; retry, stale-revision checks and concurrent-action gates prevent duplicate or lost records.
- Exact legacy stores retain seed position, completion, history and identifiers through the compatibility path. Fresh installs and failed migration/bootstrap paths remain explicit.
- Arbitrary section names and order appear correctly on iPhone/iPad. Written guidance does not acquire an unsupported MIDI launch action.
- The complete Pianovo suite and a clean app build pass without new warnings. Existing Today/MIDI Practice remains operational.

6F.11 adds local History/private notes separately. Hosted accounts, teacher sharing, AI, document import and commercial features remain later milestones.


## Local implementation and compatibility decision

`LibrarySchemaV4` adds learner-plan heads, immutable learner content revisions, one Today selection record, and idempotency receipts in the existing local Library container. Each head stores current content revision, position/end marker and self-report completion records; each completion retains its original revision/day/occurrence/exercise/time context. The V3-to-V4 lightweight stage retains all V1/V2/V3 model definitions. The separate progress V1 store and its legacy protocols/models remain unchanged. This is a coexistence compatibility path, not a conversion or re-keying of legacy progress.

`LearnerProgrammeRepository` is a separate MainActor async/throwing boundary. Programme and exercise revisions are verified before instantiation; learner revisions retain immutable exercise snapshots and typed source references. A single transaction creates/selects a new learner plan. Version/selection tokens reject stale activation, position changes, edits and confirmation intents. Exact operation receipts allow ambiguous retries to return acknowledged state without reapplying a prior command, even after subsequent navigation or selection.

`TodayProgrammeScreen` resolves the acknowledged selection. The original programme continues to use the unchanged Today view model and assigned MIDI flow; learner plans use their own projection/completion/navigation model. Named sections keep saved order rather than being guessed from labels. A failed selection read shows an explicit failure; an optional View original programme action does not rewrite an unreadable selection. Foreground refresh does not silently abandon a failed pending write.

Library → Programme templates → Use as my programme lets a learner review the selected saved template and name the independent programme, then explicitly create/select it at its first day. Today → Programmes switches between plans and the original programme. Today → Edit my programme adapts the learner copy, not the template. It preserves the current day and rejects its removal; move to another day before deleting it. Unchanged work in the same week/day/section keeps its occurrence ID. Changed goal, duration, exercise or placement context gets a fresh occurrence ID; old completion remains tied to its original revision. Changed plan content clears a previous end marker without resetting position or completion.

Next/Previous Day applies only to the new learner plans in this step. The original seed's existing presentation, completion, assigned sessions and saved position remain unchanged. Finishing the last saved day marks that plan's end without wrapping, starting another programme, completing unfinished work or creating mastery. Previous Day revisits earlier saved work. Exercise/category labels do not grant a generated-MIDI action; all newly authored assignments remain written guidance.

The Library container now physically holds both reusable local content and private learner records behind separate repositories. Future publication/sync must explicitly exclude learner records from template/exercise sharing and apply independent access controls. No remote sync, API, accounts, notes/history UI, numeric performance statistics, raw MIDI, mastery or PDF access is added here. Automatic conversion of the legacy seed into editable authored content remains a separate compatibility step.
