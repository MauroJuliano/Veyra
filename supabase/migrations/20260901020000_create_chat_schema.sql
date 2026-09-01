create extension if not exists pgcrypto;
create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 80),
  username text unique check (username is null or username ~ '^[a-z0-9_]{3,30}$'),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.profiles (id, display_name)
select
  id,
  case
    when char_length(btrim(coalesce(raw_user_meta_data ->> 'display_name', ''))) >= 2
      then btrim(raw_user_meta_data ->> 'display_name')
    when char_length(split_part(coalesce(email, ''), '@', 1)) >= 2
      then split_part(email, '@', 1)
    else 'Veyra user'
  end
from auth.users
on conflict (id) do nothing;

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

create index conversation_members_user_id_idx
  on public.conversation_members(user_id, conversation_id);
create index conversations_last_message_at_idx
  on public.conversations(last_message_at desc);
create index messages_conversation_created_at_idx
  on public.messages(conversation_id, created_at desc);
create index messages_sender_id_idx
  on public.messages(sender_id);

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

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_name text;
  email_name text;
begin
  requested_name := nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '');
  email_name := split_part(coalesce(new.email, ''), '@', 1);

  insert into public.profiles (id, display_name)
  values (
    new.id,
    case
      when char_length(coalesce(requested_name, '')) >= 2 then requested_name
      when char_length(email_name) >= 2 then email_name
      else 'Veyra user'
    end
  );

  return new;
end;
$$;

create trigger create_profile_after_signup
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

revoke execute on function public.create_profile_for_new_user() from public, anon, authenticated;

create or replace function private.is_conversation_member(
  target_conversation_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversation_members
    where conversation_id = target_conversation_id
      and user_id = target_user_id
  );
$$;

create or replace function private.is_conversation_creator(
  target_conversation_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversations
    where id = target_conversation_id
      and created_by = target_user_id
  );
$$;

grant usage on schema private to authenticated;
revoke execute on function private.is_conversation_member(uuid, uuid) from public, anon;
grant execute on function private.is_conversation_member(uuid, uuid) to authenticated;
revoke execute on function private.is_conversation_creator(uuid, uuid) from public, anon;
grant execute on function private.is_conversation_creator(uuid, uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "Authenticated users can discover profiles"
on public.profiles for select
to authenticated
using (true);

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Members can read conversations"
on public.conversations for select
to authenticated
using (private.is_conversation_member(id));

create policy "Users can create conversations"
on public.conversations for insert
to authenticated
with check (created_by = auth.uid());

create policy "Members can update conversations"
on public.conversations for update
to authenticated
using (private.is_conversation_member(id))
with check (private.is_conversation_member(id));

create policy "Members can read memberships"
on public.conversation_members for select
to authenticated
using (private.is_conversation_member(conversation_id));

create policy "Conversation creators can add members"
on public.conversation_members for insert
to authenticated
with check (private.is_conversation_creator(conversation_id));

create policy "Users can leave conversations"
on public.conversation_members for delete
to authenticated
using (user_id = auth.uid());

create policy "Members can update their read position"
on public.conversation_members for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Members can read messages"
on public.messages for select
to authenticated
using (private.is_conversation_member(conversation_id));

create policy "Members can send their own messages"
on public.messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and private.is_conversation_member(conversation_id)
);

create policy "Senders can edit their own messages"
on public.messages for update
to authenticated
using (sender_id = auth.uid())
with check (sender_id = auth.uid() and private.is_conversation_member(conversation_id));

create policy "Senders can delete their own messages"
on public.messages for delete
to authenticated
using (sender_id = auth.uid() and private.is_conversation_member(conversation_id));

alter publication supabase_realtime add table public.messages;
