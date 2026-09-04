create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

drop policy if exists "Users can view their blocks" on public.user_blocks;
create policy "Users can view their blocks"
on public.user_blocks for select to authenticated
using (blocker_id = auth.uid());

drop policy if exists "Users can create their blocks" on public.user_blocks;
create policy "Users can create their blocks"
on public.user_blocks for insert to authenticated
with check (blocker_id = auth.uid());

drop policy if exists "Users can remove their blocks" on public.user_blocks;
create policy "Users can remove their blocks"
on public.user_blocks for delete to authenticated
using (blocker_id = auth.uid());

create or replace function private.can_send_to_conversation(
  target_conversation_id uuid,
  current_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_conversation_member(target_conversation_id, current_user_id)
    and not exists (
      select 1
      from public.conversation_members other
      join public.user_blocks block
        on (
          block.blocker_id = current_user_id
          and block.blocked_id = other.user_id
        ) or (
          block.blocked_id = current_user_id
          and block.blocker_id = other.user_id
        )
      where other.conversation_id = target_conversation_id
        and other.user_id <> current_user_id
    );
$$;

revoke execute on function private.can_send_to_conversation(uuid, uuid) from public, anon;
grant execute on function private.can_send_to_conversation(uuid, uuid) to authenticated;

drop policy if exists "Members can send their own messages" on public.messages;
drop policy if exists "Unblocked members can send their own messages" on public.messages;
create policy "Unblocked members can send their own messages"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and private.can_send_to_conversation(conversation_id, auth.uid())
);

create or replace function public.get_block_relationship(target_user_id uuid)
returns table (is_blocked_by_me boolean, is_blocked_by_them boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (
      select 1 from public.user_blocks
      where blocker_id = auth.uid() and blocked_id = target_user_id
    ),
    exists (
      select 1 from public.user_blocks
      where blocker_id = target_user_id and blocked_id = auth.uid()
    );
$$;

create or replace function public.set_user_block(target_user_id uuid, should_block boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if target_user_id = auth.uid() then
    raise exception 'You cannot block yourself';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'User not found';
  end if;

  if should_block then
    insert into public.user_blocks (blocker_id, blocked_id)
    values (auth.uid(), target_user_id)
    on conflict do nothing;
  else
    delete from public.user_blocks
    where blocker_id = auth.uid() and blocked_id = target_user_id;
  end if;
end;
$$;

create or replace function public.list_blocked_users()
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_path text,
  bio text
)
language sql
stable
security definer
set search_path = ''
as $$
  select profile.id, profile.display_name, profile.username, profile.avatar_url, profile.bio
  from public.user_blocks block
  join public.profiles profile on profile.id = block.blocked_id
  where block.blocker_id = auth.uid()
  order by lower(profile.display_name);
$$;

create or replace function public.can_send_to_conversation(target_conversation_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.can_send_to_conversation(target_conversation_id, auth.uid());
$$;

revoke execute on function public.get_block_relationship(uuid) from public, anon;
revoke execute on function public.set_user_block(uuid, boolean) from public, anon;
revoke execute on function public.list_blocked_users() from public, anon;
revoke execute on function public.can_send_to_conversation(uuid) from public, anon;
grant execute on function public.get_block_relationship(uuid) to authenticated;
grant execute on function public.set_user_block(uuid, boolean) to authenticated;
grant execute on function public.list_blocked_users() to authenticated;
grant execute on function public.can_send_to_conversation(uuid) to authenticated;
