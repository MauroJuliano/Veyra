drop function if exists public.list_my_contacts();

create function public.list_my_contacts()
returns table (
  contact_id uuid,
  display_name text,
  conversation_id uuid,
  avatar_path text,
  bio text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    profile.id,
    profile.display_name,
    direct_conversation.id,
    profile.avatar_url,
    profile.bio
  from public.contacts contact
  join public.profiles profile on profile.id = contact.contact_id
  left join lateral (
    select conversation.id
    from public.conversations conversation
    join public.conversation_members mine
      on mine.conversation_id = conversation.id
      and mine.user_id = auth.uid()
    join public.conversation_members theirs
      on theirs.conversation_id = conversation.id
      and theirs.user_id = contact.contact_id
    where (
      select count(*)
      from public.conversation_members member
      where member.conversation_id = conversation.id
    ) = 2
    limit 1
  ) direct_conversation on true
  where contact.owner_id = auth.uid()
  order by profile.display_name;
$$;

revoke execute on function public.list_my_contacts() from public, anon;
grant execute on function public.list_my_contacts() to authenticated;

drop function if exists public.search_people(text, integer);

create function public.search_people(
  search_query text,
  result_limit integer default 20
)
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_path text,
  bio text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with normalized as (
    select lower(btrim(search_query)) as query
  )
  select
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    profile.bio
  from public.profiles profile
  cross join normalized
  where auth.uid() is not null
    and profile.id <> auth.uid()
    and char_length(normalized.query) >= 2
    and (
      position(normalized.query in lower(profile.display_name)) > 0
      or position(normalized.query in lower(coalesce(profile.username, ''))) > 0
      or extensions.similarity(lower(profile.display_name), normalized.query) >= 0.3
      or extensions.similarity(lower(coalesce(profile.username, '')), normalized.query) >= 0.3
    )
  order by
    case
      when lower(profile.display_name) like normalized.query || '%' then 0
      when lower(coalesce(profile.username, '')) like normalized.query || '%' then 1
      when position(normalized.query in lower(profile.display_name)) > 0 then 2
      when position(normalized.query in lower(coalesce(profile.username, ''))) > 0 then 3
      else 4
    end,
    greatest(
      extensions.similarity(lower(profile.display_name), normalized.query),
      extensions.similarity(lower(coalesce(profile.username, '')), normalized.query)
    ) desc,
    profile.display_name
  limit least(greatest(result_limit, 1), 50);
$$;

revoke execute on function public.search_people(text, integer) from public, anon;
grant execute on function public.search_people(text, integer) to authenticated;
