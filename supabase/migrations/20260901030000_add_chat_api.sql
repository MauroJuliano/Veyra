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
  values
    (new_conversation_id, current_user_id),
    (new_conversation_id, target_user_id);

  return new_conversation_id;
end;
$$;

revoke execute on function public.start_direct_conversation(text) from public, anon;
grant execute on function public.start_direct_conversation(text) to authenticated;

create or replace function public.list_my_conversations()
returns table (
  conversation_id uuid,
  participant_name text,
  last_message text,
  updated_at timestamptz,
  unread_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    c.id,
    coalesce(other_profile.display_name, 'Veyra user'),
    coalesce(last_message.body, ''),
    c.last_message_at,
    count(unread_message.id)
  from public.conversations c
  join public.conversation_members mine
    on mine.conversation_id = c.id and mine.user_id = auth.uid()
  left join public.conversation_members other_member
    on other_member.conversation_id = c.id and other_member.user_id <> auth.uid()
  left join public.profiles other_profile on other_profile.id = other_member.user_id
  left join lateral (
    select body from public.messages
    where conversation_id = c.id
    order by created_at desc limit 1
  ) last_message on true
  left join public.messages unread_message
    on unread_message.conversation_id = c.id
   and unread_message.sender_id <> auth.uid()
   and unread_message.created_at > coalesce(mine.last_read_at, mine.joined_at)
  group by c.id, other_profile.display_name, last_message.body, c.last_message_at
  order by c.last_message_at desc;
$$;

revoke execute on function public.list_my_conversations() from public, anon;
grant execute on function public.list_my_conversations() to authenticated;

create or replace function public.touch_conversation_after_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

create trigger touch_conversation_after_message
after insert on public.messages
for each row execute function public.touch_conversation_after_message();

revoke execute on function public.touch_conversation_after_message() from public, anon, authenticated;
