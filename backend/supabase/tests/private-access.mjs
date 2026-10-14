// Run against pinned PGlite 0.5.9, installed outside the repository.
// This verifies PostgreSQL grants/RLS, not Supabase JWT verification or live Auth.
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

if (!process.argv[2]) throw new Error('Pass the directory containing the test-only node_modules.');
const { PGlite } = await import(pathToFileURL(resolve(process.argv[2], 'node_modules/@electric-sql/pglite/dist/index.js')));
const db = new PGlite();
let checks = 0;
const check = (condition) => { assert.ok(condition); checks++; };
const denied = async (sql, params = []) => {
    await assert.rejects(db.query(sql, params), /permission denied|row-level security|check constraint/);
    checks++;
};
const a = '10000000-0000-0000-0000-000000000001';
const b = '10000000-0000-0000-0000-000000000002';
const resource = '20000000-0000-0000-0000-000000000001';
const revision = '30000000-0000-0000-0000-000000000001';
const insert = `insert into public.pianovo_private_revisions
    (owner_account_id, resource_kind, resource_id, revision_id, payload_schema_version, body)
    values ($1, $2, $3, $4, 1, $5)`;
const params = (owner, kind = 'exerciseRevision', body = {}) => [owner, kind, resource, revision, JSON.stringify(body)];
const assume = async (role, account = '') => {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [account]);
    await db.exec(`set role ${role}`); // Only fixed test roles are passed here.
};
try {
    await db.exec(`
        create role anon;
        create role authenticated;
        create schema auth;
        create table auth.users (id uuid primary key);
        create function auth.uid() returns uuid language sql stable as
            $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
        grant usage on schema auth, public to anon, authenticated;
        grant execute on function auth.uid() to anon, authenticated;
    `);
    await db.query('insert into auth.users values ($1), ($2)', [a, b]);
    await db.exec(await readFile(new URL('../migrations/202610130001_private_revisions.sql', import.meta.url), 'utf8'));
    const flags = await db.query("select relrowsecurity, relforcerowsecurity from pg_class where oid = 'public.pianovo_private_revisions'::regclass");
    check(flags.rows[0].relrowsecurity && flags.rows[0].relforcerowsecurity);
    await assume('anon');
    await denied('select * from public.pianovo_private_revisions');
    await denied(insert, params(a));
    await assume('authenticated', a);
    await db.query(insert, params(a));
    check((await db.query('select * from public.pianovo_private_revisions')).rows.length === 1);
    await denied(insert, params(b));
    await denied('update public.pianovo_private_revisions set body = $1', ['{}']);
    await denied('delete from public.pianovo_private_revisions');
    await denied(insert, params(a, 'unknown'));
    await denied(insert, params(a, 'privateNote', []));
    await db.query(insert, params(a, 'privateNote', { text: 'Synthetic private note' }));
    await assume('authenticated', b);
    check((await db.query('select * from public.pianovo_private_revisions')).rows.length === 0);
    await denied(insert, params(a, 'privateNote', { localOwnerID: a, role: 'teacher' }));
    // Reusing guessed local UUIDs grants no access to account A's resources.
    await db.query(insert, params(b, 'exerciseRevision', { localOwnerID: a }));
    const own = (await db.query('select * from public.pianovo_private_revisions')).rows;
    check(own.length === 1 && own[0].owner_account_id === b);
    await assume('authenticated');
    check((await db.query('select * from public.pianovo_private_revisions')).rows.length === 0);
    await denied(insert, params(a));
    await assume('authenticated', a);
    check((await db.query('select * from public.pianovo_private_revisions')).rows.length === 2);
    console.log(`PASS: ${checks} PostgreSQL access checks (synthetic accounts, no network or hosted project).`);
} finally { await db.close(); }
