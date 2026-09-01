create table public.contacts (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, contact_id),
  check (owner_id <> contact_id)
);

insert into public.contacts (owner_id, contact_id)
select distinct mine.user_id, other_member.user_id
from public.conversation_members mine
join public.conversation_members other_member
  on other_member.conversation_id = mine.conversation_id
 and other_member.user_id <> mine.user_id
on conflict do nothing;

alter table public.contacts enable row level security;

create policy "Users can read their own contacts"
on public.contacts for select
to authenticated
using (owner_id = auth.uid());

create or replace function public.start_direct_conversation(target_email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_user_id uuid;
  existing_conversation_id uuid;
  new_conversation_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select id into target_user_id
  from auth.users
  where lower(email) = lower(btrim(target_email))
    and email_confirmed_at is not null;

  if target_user_id is null then
    raise exception 'No Veyra user found with this email';
  end if;
  if target_user_id = current_user_id then
    raise exception 'You cannot start a conversation with yourself';
  end if;

  insert into public.contacts (owner_id, contact_id)
  values (current_user_id, target_user_id), (target_user_id, current_user_id)
  on conflict do nothing;

  select cm.conversation_id into existing_conversation_id
  from public.conversation_members cm
  where cm.user_id in (current_user_id, target_user_id)
  group by cm.conversation_id
  having count(*) filter (where cm.user_id in (current_user_id, target_user_id)) = 2
     and (select count(*) from public.conversation_members all_members
          where all_members.conversation_id = cm.conversation_id) = 2
  limit 1;

  if existing_conversation_id is not null then
    return existing_conversation_id;
  end if;

  insert into public.conversations (created_by)
  values (current_user_id)
  returning id into new_conversation_id;

  insert into public.conversation_members (conversation_id, user_id)
  values (new_conversation_id, current_user_id), (new_conversation_id, target_user_id);

  return new_conversation_id;
end;
$$;

create or replace function public.list_my_contacts()
returns table (
  contact_id uuid,
  display_name text,
  conversation_id uuid
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    profile.id,
    profile.display_name,
    direct_conversation.id
  from public.contacts contact
  join public.profiles profile on profile.id = contact.contact_id
  left join lateral (
    select conversation.id
    from public.conversations conversation
    join public.conversation_members mine
      on mine.conversation_id = conversation.id and mine.user_id = auth.uid()
    join public.conversation_members theirs
      on theirs.conversation_id = conversation.id and theirs.user_id = contact.contact_id
    where (select count(*) from public.conversation_members member
           where member.conversation_id = conversation.id) = 2
    limit 1
  ) direct_conversation on true
  where contact.owner_id = auth.uid()
  order by profile.display_name;
$$;

revoke execute on function public.list_my_contacts() from public, anon;
grant execute on function public.list_my_contacts() to authenticated;

create or replace function public.delete_conversation(target_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not private.is_conversation_member(target_conversation_id, auth.uid()) then
    raise exception 'Conversation not found';
  end if;

  delete from public.conversations where id = target_conversation_id;
end;
$$;

revoke execute on function public.delete_conversation(uuid) from public, anon;
grant execute on function public.delete_conversation(uuid) to authenticated;

create or replace function public.sync_conversation_after_message_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations
  set last_message_at = coalesce(
    (select max(created_at) from public.messages where conversation_id = old.conversation_id),
    created_at
  )
  where id = old.conversation_id;
  return old;
end;
$$;

create trigger sync_conversation_after_message_delete
after delete on public.messages
for each row execute function public.sync_conversation_after_message_delete();

revoke execute on function public.sync_conversation_after_message_delete() from public, anon, authenticated;

alter table public.messages replica identity full;
alter table public.conversation_members replica identity full;
