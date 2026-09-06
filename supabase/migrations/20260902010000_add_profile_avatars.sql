insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do update set public = false;

create policy "users can view contact avatars"
on storage.objects for select to authenticated
using (
  bucket_id = 'avatars' and (
    ((storage.foldername(name))[1])::uuid = auth.uid()
    or exists (
      select 1 from public.contacts
      where owner_id = auth.uid()
        and contact_id = ((storage.foldername(name))[1])::uuid
    )
  )
);

create policy "users can upload own avatar"
on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users can update own avatar"
on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop function if exists public.list_my_conversations();
create function public.list_my_conversations()
returns table (
  conversation_id uuid, participant_id uuid, participant_name text,
  last_message text, updated_at timestamptz, unread_count bigint,
  is_online boolean, last_seen_at timestamptz,
  last_message_is_mine boolean, last_message_is_read boolean, avatar_path text
)
language sql stable security invoker set search_path = ''
as $$
  select c.id, other_profile.id, coalesce(other_profile.display_name, 'Veyra user'),
    coalesce(last_message.body, ''), c.last_message_at, count(unread_message.id),
    coalesce(presence.last_seen_at > now() - interval '60 seconds', false),
    presence.last_seen_at, coalesce(last_message.sender_id = auth.uid(), false),
    coalesce(last_message.sender_id = auth.uid() and other_member.last_read_at >= last_message.created_at, false),
    other_profile.avatar_url
  from public.conversations c
  join public.conversation_members mine on mine.conversation_id = c.id and mine.user_id = auth.uid()
  left join public.conversation_members other_member on other_member.conversation_id = c.id and other_member.user_id <> auth.uid()
  left join public.profiles other_profile on other_profile.id = other_member.user_id
  left join public.user_presence presence on presence.user_id = other_profile.id
  left join lateral (select body, sender_id, created_at from public.messages where conversation_id = c.id order by created_at desc limit 1) last_message on true
  left join public.messages unread_message on unread_message.conversation_id = c.id
    and unread_message.sender_id <> auth.uid()
    and unread_message.created_at > coalesce(mine.last_read_at, mine.joined_at)
  group by c.id, other_profile.id, other_profile.display_name, other_profile.avatar_url,
    last_message.body, last_message.sender_id, last_message.created_at,
    c.last_message_at, presence.last_seen_at, other_member.last_read_at
  order by c.last_message_at desc;
$$;
revoke execute on function public.list_my_conversations() from public, anon;
grant execute on function public.list_my_conversations() to authenticated;

drop function if exists public.list_my_contacts();
create function public.list_my_contacts()
returns table (contact_id uuid, display_name text, conversation_id uuid, avatar_path text)
language sql stable security invoker set search_path = ''
as $$
  select profile.id, profile.display_name, direct_conversation.id, profile.avatar_url
  from public.contacts contact
  join public.profiles profile on profile.id = contact.contact_id
  left join lateral (
    select conversation.id from public.conversations conversation
    join public.conversation_members mine on mine.conversation_id = conversation.id and mine.user_id = auth.uid()
    join public.conversation_members theirs on theirs.conversation_id = conversation.id and theirs.user_id = contact.contact_id
    where (select count(*) from public.conversation_members member where member.conversation_id = conversation.id) = 2
    limit 1
  ) direct_conversation on true
  where contact.owner_id = auth.uid()
  order by profile.display_name;
$$;
revoke execute on function public.list_my_contacts() from public, anon;
grant execute on function public.list_my_contacts() to authenticated;
