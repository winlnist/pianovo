-- 6F.12A contract only. No project is provisioned or user data uploaded.
-- Authentication is supplied by Supabase, never by a client owner/role label.
create table public.pianovo_private_revisions (
    owner_account_id uuid not null default auth.uid() references auth.users(id),
    resource_kind text not null check (resource_kind in (
        'exerciseRevision', 'exerciseTemplateRevision', 'programmeTemplateRevision',
        'learnerRevision', 'completion', 'legacySession', 'privateNote'
    )),
    resource_id uuid not null,
    revision_id uuid not null,
    payload_schema_version integer not null check (payload_schema_version = 1),
    body jsonb not null check (jsonb_typeof(body) = 'object'),
    created_at timestamptz not null default now(),
    primary key (owner_account_id, resource_kind, resource_id, revision_id)
);

alter table public.pianovo_private_revisions enable row level security;
alter table public.pianovo_private_revisions force row level security;
revoke all on public.pianovo_private_revisions from public, anon, authenticated;
grant select, insert on public.pianovo_private_revisions to authenticated;

create policy private_revision_owner_read on public.pianovo_private_revisions
    for select to authenticated
    using ((select auth.uid()) = owner_account_id);
create policy private_revision_owner_insert on public.pianovo_private_revisions
    for insert to authenticated
    with check ((select auth.uid()) = owner_account_id);

-- No public/teacher grants, mutable heads, update/delete policy or server receipts.
-- JSON shape validation is not a substitute for later typed domain validation.
