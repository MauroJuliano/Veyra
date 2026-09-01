create table public.user_presence (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    last_seen_at timestamptz not null default now()
);

alter table public.user_presence enable row level security;

create policy "users can read contact presence"
on public.user_presence for select to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1 from public.contacts
        where owner_id = (select auth.uid())
          and contact_id = user_presence.user_id
    )
);

create policy "users can insert own presence"
on public.user_presence for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "users can update own presence"
on public.user_presence for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

grant select, insert, update on public.user_presence to authenticated;

drop function if exists public.list_my_conversations();
create function public.list_my_conversations()
returns table (
    conversation_id uuid,
    participant_id uuid,
    participant_name text,
    last_message text,
    updated_at timestamptz,
    unread_count bigint,
    is_online boolean,
    last_seen_at timestamptz
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
        count(unread_message.id),
        coalesce(presence.last_seen_at > now() - interval '60 seconds', false),
        presence.last_seen_at
    from public.conversations c
    join public.conversation_members mine
      on mine.conversation_id = c.id and mine.user_id = auth.uid()
    left join public.conversation_members other_member
      on other_member.conversation_id = c.id and other_member.user_id <> auth.uid()
    left join public.profiles other_profile on other_profile.id = other_member.user_id
    left join public.user_presence presence on presence.user_id = other_profile.id
    left join lateral (
        select body from public.messages
        where conversation_id = c.id
        order by created_at desc limit 1
    ) last_message on true
    left join public.messages unread_message
      on unread_message.conversation_id = c.id
     and unread_message.sender_id <> auth.uid()
     and unread_message.created_at > coalesce(mine.last_read_at, mine.joined_at)
    group by c.id, other_profile.id, other_profile.display_name,
             last_message.body, c.last_message_at, presence.last_seen_at
    order by c.last_message_at desc;
$$;

revoke execute on function public.list_my_conversations() from public, anon;
grant execute on function public.list_my_conversations() to authenticated;

do $$
begin
    alter publication supabase_realtime add table public.user_presence;
exception when duplicate_object then null;
end
$$;
