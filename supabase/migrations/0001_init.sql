-- Forever World: Migration 0001
-- Tabellen, Zugriffsschutz (RLS), Storage-Bucket und Realtime.
-- Kann mehrfach ausgeführt werden, ohne Daten zu löschen.

-- 1) Zugangsliste ------------------------------------------------------------
-- Nur E-Mail-Adressen aus dieser Tabelle dürfen Daten lesen oder schreiben.
-- Die Tabelle ist für die App unsichtbar und wird nur im SQL-Editor gepflegt.
create table if not exists public.allowed_emails (
  email      text primary key check (email = lower(email)),
  created_at timestamptz not null default now()
);

alter table public.allowed_emails enable row level security;
revoke all on public.allowed_emails from anon, authenticated;

create or replace function public.is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.allowed_emails e
    where e.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke execute on function public.is_member() from public, anon;
grant  execute on function public.is_member() to authenticated;

-- 2) Hilfsfunktion: updated_at automatisch setzen ----------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 3) Tabellen ----------------------------------------------------------------
create table if not exists public.projects (
  id         text primary key default gen_random_uuid()::text,
  name       text not null default '',
  notes      text not null default '',
  coords     text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.palettes (
  id         text primary key default gen_random_uuid()::text,
  project_id text not null references public.projects(id) on delete cascade,
  name       text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ein Block pro Zeile: zwei Nutzer können gleichzeitig Blöcke hinzufügen,
-- ohne dass einer die Änderung des anderen überschreibt.
create table if not exists public.palette_blocks (
  id         text primary key default gen_random_uuid()::text,
  palette_id text not null references public.palettes(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 80),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (palette_id, name)
);

create table if not exists public.todo_lists (
  id         text primary key default gen_random_uuid()::text,
  project_id text not null references public.projects(id) on delete cascade,
  name       text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.todo_items (
  id         text primary key default gen_random_uuid()::text,
  list_id    text not null references public.todo_lists(id) on delete cascade,
  text       text not null check (char_length(text) between 1 and 500),
  done       boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.images (
  id           text primary key default gen_random_uuid()::text,
  project_id   text not null references public.projects(id) on delete cascade,
  storage_path text not null unique,
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now()
);

create index if not exists palettes_project_idx       on public.palettes(project_id);
create index if not exists palette_blocks_palette_idx on public.palette_blocks(palette_id);
create index if not exists todo_lists_project_idx     on public.todo_lists(project_id);
create index if not exists todo_items_list_idx        on public.todo_items(list_id);
create index if not exists images_project_idx         on public.images(project_id);

-- updated_at-Trigger
drop trigger if exists projects_updated   on public.projects;
drop trigger if exists palettes_updated   on public.palettes;
drop trigger if exists todo_lists_updated on public.todo_lists;
drop trigger if exists todo_items_updated on public.todo_items;
create trigger projects_updated   before update on public.projects   for each row execute function public.set_updated_at();
create trigger palettes_updated   before update on public.palettes   for each row execute function public.set_updated_at();
create trigger todo_lists_updated before update on public.todo_lists for each row execute function public.set_updated_at();
create trigger todo_items_updated before update on public.todo_items for each row execute function public.set_updated_at();

-- 4) Zugriffsschutz (RLS) und Realtime ----------------------------------------
-- anon (nicht angemeldet) bekommt gar nichts.
-- authenticated darf nur, wenn die E-Mail in allowed_emails steht.
do $$
declare
  t text;
begin
  foreach t in array array['projects','palettes','palette_blocks','todo_lists','todo_items','images']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists "members_all" on public.%I', t);
    execute format(
      'create policy "members_all" on public.%I for all to authenticated '
      'using ((select public.is_member())) with check ((select public.is_member()))', t);
    execute format('alter table public.%I replica identity full', t);
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$$;

-- 5) Storage: privater Bucket für Inspirationsbilder --------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('inspiration', 'inspiration', false, 8388608,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "inspiration_select" on storage.objects;
drop policy if exists "inspiration_insert" on storage.objects;
drop policy if exists "inspiration_update" on storage.objects;
drop policy if exists "inspiration_delete" on storage.objects;

create policy "inspiration_select" on storage.objects for select to authenticated
  using (bucket_id = 'inspiration' and (select public.is_member()));
create policy "inspiration_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'inspiration' and (select public.is_member()));
create policy "inspiration_update" on storage.objects for update to authenticated
  using (bucket_id = 'inspiration' and (select public.is_member()))
  with check (bucket_id = 'inspiration' and (select public.is_member()));
create policy "inspiration_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'inspiration' and (select public.is_member()));
