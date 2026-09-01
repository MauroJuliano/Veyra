drop function if exists public.list_my_conversations();

create function public.list_my_conversations()
returns table (
  conversation_id uuid,
  participant_id uuid,
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
    other_profile.id,
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
  group by c.id, other_profile.id, other_profile.display_name, last_message.body, c.last_message_at
  order by c.last_message_at desc;
$$;

revoke execute on function public.list_my_conversations() from public, anon;
grant execute on function public.list_my_conversations() to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_members'
  ) then
    alter publication supabase_realtime add table public.conversation_members;
  end if;
end;
$$;
