# Hosted Accounts, Sync and Teacher Collaboration (6F.12)

## Status

6F.12A implements local queue/account-transition contracts and an undeployed private backend schema. No hosted project, account flow, SDK, live API, network sync worker, paid resource or data transfer has been created. The current app remains local. The preceding published baseline is commit `2309041`, with 305 tests across 33 suites and a clean app build. Initial programme-template use and History/private-note creation were manually confirmed; broader local workflow/restoration checks remain pending and are required before remote rollout.

The user selected Supabase, optional accounts and explicit cloud opt-in. Local use must continue without signing in. Linking/uploading existing data requires an explicit review action; signing in alone grants no upload consent. This document distinguishes implemented contracts from planned login, backup and teacher sharing.

## Provider evaluation

| Option | Verified capabilities | Fit for this roadmap — engineering assessment |
| --- | --- | --- |
| Supabase | PostgreSQL, Swift client, authentication and database row-level policies; server Edge Functions | Recommended for relational ownership, relationships, immutable content versions and later server-mediated AI. Pianovo still needs an explicit offline queue and reconciliation protocol. |
| Apple CloudKit | Native record sharing among iCloud users, with participant permissions | Suitable for an iCloud-centred Apple workflow. Account/relationship and later API/AI requirements still need a deliberate service design; enabling automatic store sync alone does not implement them. |
| Firebase / Firestore | Authentication-linked Security Rules and offline persistence on Apple platforms | Viable alternative with document modelling and SDK integration. Pianovo's immutable revisions, invitations and conflict rules still require application-specific contracts. |

Sources: [Supabase Swift](https://supabase.com/docs/reference/swift/introduction), [Supabase access policies](https://supabase.com/docs/guides/database/postgres/row-level-security), [Apple sign-in](https://supabase.com/docs/guides/auth/social-login/auth-apple), [Edge Functions](https://supabase.com/docs/guides/functions), [CloudKit sharing](https://developer.apple.com/documentation/cloudkit/sharing-cloudkit-data-with-other-icloud-users), [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started), [Firestore offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

No pricing, hosting region, vendor commitment or production operating budget is assumed. Select these with the project owner before provisioning. Native Apple sign-in is a candidate first login method, subject to Apple developer configuration and provider setup; it is not configured in Pianovo.

## Repository findings and compatibility requirements

- Library V5 contains exercises, exercise templates, programme templates, learner plans, completion records, selection receipts and private notes. The original progress/history V1 store is separate. Neither store can be treated as a public content database or uploaded wholesale.
- `LibraryOwnerID` is an installation-local content identity, not a signed-in account ID or an access credential. Notes do not yet have an authenticated author field. Do not change local IDs to vendor IDs or infer remote ownership from them.
- Repository protocols are local asynchronous boundaries. Durable local success currently means saved on this device, not acknowledged by a server. Remote status must be separate.
- Immutable exercise/template/learner revisions and pinned references already exist. Mutable heads, selected programme, position, archives and completion need expected-version reconciliation. Local timestamps must not decide a remote conflict by themselves.
- Operation receipts support exact local learner retries. 6F.12A adds a durable outgoing queue, account-scoped cursors, scoped local-owner links and session fences. There is no remote cache, network worker or automatic queueing of content writes yet.
- Private notes capture original session/day context. Public content publication must not include that context, note text, learner completion, or embedded session records.
- Legacy deletion APIs affect only their original store. Before enabling cloud retention/deletion, specify a combined policy for both stores, notes, sync queues and acknowledged remote deletions.

## Recommended stages

### 6F.12A — contracts, ownership and account isolation (implemented foundation)

Foundation-only account/session identity, scoped owner links, envelopes, queue status, cursors and local transition receipts are implemented. Library V6 adds one queue-state entity through an explicit V5-to-V6 lightweight migration; prior model definitions and the separate progress/history V1 store remain unchanged. The repository is not wired into app dependencies or any UI. No guest data is implicitly linked, converted or queued.

Queue eligibility requires the active account, matching local-owner link and consent for the resource scope. Signing out, switching accounts, refreshing a session generation or revoking consent parks in-flight operations. Stale acknowledgements cannot finish another session's work; conflicts do not retry automatically. Exact transition receipts return current durable state without regressing later account changes, including after an ambiguous save. Compare-and-set cursors remain account-scoped. Disk tests verify migration, preserved stable identities and queue reopening; failure tests exercise rollback and durable read verification.

The Supabase migration grants authenticated owners only read/insert of private immutable revisions. Anonymous, other-account and teacher-label access is denied; updates/deletes are not granted. Local PostgreSQL tests use synthetic authentication claims and enforce the actual SQL policies. They do **not** verify live Supabase JWT authentication, gateway settings or hosted deployment. See [Backend checks](../backend/README.md).

These are foundations, not a complete sync protocol: typed payload/domain validation, server operation receipts, expected-head reconciliation, transactional local-write/outbox coupling, downloads, isolated remote caches and retention/deletion policies still gate 6F.12B. A JSON object and a client session UUID are not validated content or proof of authentication. Publication/access grants are deferred until the relationship/publication stages; none are granted by this step.

### 6F.12B — optional account and private same-account sync

After provider/project configuration, implement a real optional login/logout flow and explicit review/link action for existing device data. Start with same-account private content/learner data; no teacher access is granted. Show local-only, queued, sending, acknowledged, failed and conflict states accurately. Confirm restoration on a second device using the same account.

Acceptance: local practice works offline; interrupted uploads/downloads retry without duplicates or phantom success; account changes cancel/fence in-flight work; guest data is not silently adopted or uploaded. Provider credentials are configured appropriately; privileged server keys never enter the app or repository.

### 6F.12C — accepted teacher/student relationships

Add invitations with pending, accepted and revoked states. A user may learn independently and may teach without treating a display role as permission. Both parties explicitly accept the relationship and its grants. Revoke online access server-side, and define handling of previously cached data separately.

Acceptance: pending/revoked relationships have no student access, unrelated accounts cannot enumerate learner records, and guessing/changing resource IDs or client role labels cannot bypass permissions. A teacher can access only explicitly granted learner plans and evidence. Private learner notes remain private by default.

### 6F.12D — reviewed programme delivery and authorised review

Let teachers explicitly publish content/plan proposals to authorised students. The student reviews and accepts a proposal before it becomes a new learner plan or an update to one. Revisions remain immutable; replacement work receives new occurrence IDs and prior progress/history remains interpretable. Delivery and acceptance have separate acknowledgements.

Acceptance: retries deliver one proposal, offline reception never implies acceptance, a proposal cannot overwrite a student's current Today position, and teacher review distinguishes recorded sessions from self-reported completion. Teacher/shared notes require their own explicit audiences; marketplace, payments, chat and AI generation are not bundled into this stage.

## Access matrix baseline

| Data | Owner | Teacher with accepted relationship | Other account / public |
| --- | --- | --- | --- |
| Unpublished authored content/templates | Own read/write | No access unless specifically shared | No access |
| Explicitly shared immutable teaching revisions | As granted | As granted | Only explicit recipient/publication permissions |
| Individual learner plan and recorded evidence | Learner read/write | Only the accepted, scoped grant | No access |
| Private learner notes | Learner only | No access by relationship alone | No access |
| Private teacher lesson notes | Teacher only, future workflow | Only the author | No access |
| Student-visible feedback/shared lesson notes | Explicit audience, future workflow | Explicit audience | No access |

Server identity comes from verified authentication. The server determines ownership and applicable grants; client-supplied names, owner IDs, role flags, URLs or account IDs are not authority. Storage/media access requires the same enforcement as database rows. Acquiring a future programme template does not create a teaching relationship.

## Offline and sync contract

Each durable outgoing operation needs an immutable operation ID, account partition, resource/revision identity, expected head/version, schema version and payload. Creation/meaningful record timestamps retain their captured local-day context. Queue the operation with its local change transactionally; acknowledgement is stored only after confirmed server acceptance. Account tokens belong in appropriate secure credential storage, not in sync payloads or logs.

A server receipt identifies the operation and accepted result. Exact retry returns the acknowledged result; a conflicting payload with the same operation ID fails. Downloads use a durable account-scoped cursor, validate complete references and apply transactions before advancing it. A missing dependency cannot leave a partially active learner plan or a fabricated empty Today.

Mutable-head conflicts are visible and do not silently overwrite. Immutable referenced revisions remain resolvable. Keep programme selection device-local for the first release unless cross-device selection behaviour is explicitly agreed; content and per-plan position/progress can sync under defined expected-version rules. Completion, position and mastery stay separate.

Sign-out fences in-flight requests and parks the account's outbox. It never resends that work as another account. Cached account data and guest data need an explicit retention/removal policy and isolated storage. A user cannot acquire a remote resource merely by claiming the same installation-local UUID.

Revocation blocks future authorised server access. Offline copies cannot be remotely erased while a device is disconnected; the product must define which cached resources remain usable, how revocation is applied on reconnection, and what is removed without deleting the learner's own records. Do not promise immediate remote deletion of disconnected copies.

## Setup needed before live integration

Supabase and optional accounts with explicit cloud opt-in are confirmed. Before 6F.12B, arrange a user-owned development project, hosting region, operating budget and intended first test audience. Confirm Apple sign-in/developer configuration or another chosen login method. Use a development environment and synthetic accounts/data first. Do not request privileged secrets in chat, commit them, create paid services, or upload existing personal data as part of 6F.12A.

The queue stores local transition metadata and caller-supplied JSON only; it contains no credentials and is not a secure token store. A future authenticated broker must drive session changes, keep tokens in secure credential storage, fence/cancel requests, and expose only authorised account views. The internal repository snapshot includes parked queue partitions for reconciliation and must not be presented as an account-filtered UI/cache API. Receipt compaction and bounded queue storage need policy before sustained live sync. The separate original history store requires a tested journal/snapshot bridge before claiming atomic cross-store sync.

## Automated verification

6F.12A verification uses the complete Pianovo test action and a clean Debug build on the iPad Pro 11-inch (M5), iOS Simulator 27.0. All 314 tests across 35 suites passed. The 15 synthetic PostgreSQL access checks also passed. No new compiler warnings were introduced; existing test actor-isolation/redundant `#require` warnings and Xcode's skipped AppIntents metadata warning remain. There is no new UI or physical/cloud workflow to manually validate in this foundation step.

Private learner records, explicit consent, account switching and revocation are release gates, not features to retrofit after teacher sharing is enabled. Future AI requests must go through a server-held provider credential and authorised data selection; no AI provider or chargeable generation is added to 6F.12.
