# Supabase contract and local access checks

6F.12A provides an **undeployed foundation**. It does not provision Supabase, implement accounts, upload local data or configure app credentials. Local use remains independent of accounts; later linking requires explicit consent. No teacher/public access is granted.

`supabase/migrations/202610130001_private_revisions.sql` defines private immutable revisions with account-qualified identities and PostgreSQL row-level security. Only an authenticated owner may select/insert; anonymous users and other accounts cannot access the rows. Update/delete are denied. A claimed local owner ID or teacher label in the JSON cannot grant access.

The JSON-object constraint is not business validation. Typed payload allowlists, safe private/public separation, expected-head reconciliation, idempotent server receipts, retention/deletion and authenticated transport must be implemented/tested before real sync. Do not deploy this migration alone and describe it as a finished sync backend.

## Run local policy checks

Use Node.js and the pinned test-only [PGlite](https://pglite.dev/docs/) PostgreSQL runtime. Install outside the repository (the directory below is relative and disposable):

```sh
npm install --prefix ../pianovo-db-check --no-package-lock --no-save @electric-sql/pglite@0.5.9
node backend/supabase/tests/private-access.mjs ../pianovo-db-check
```

The runner applies the actual migration to an ephemeral PostgreSQL database and exercises grants/RLS with synthetic account IDs. Its `auth.uid()` fixture models the verified identity provided by Supabase. It does not verify JWT signatures, actual Supabase Auth, hosted gateway configuration, storage policies or service-role behaviour. PGlite avoids provisioning a cloud project for fast repeatable policy tests; hosted integration tests are still required. No test dependency is added to the Xcode app or Swift packages.

Before live integration, configure a user-owned development project, region/budget and authentication method, then test with synthetic accounts. Privileged/service-role credentials must remain server-side and out of the app, logs, chat and repository. No keys are needed to run these local tests. Teacher relationships, publication, paid content and AI are separate stages.
