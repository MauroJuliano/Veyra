create extension if not exists pg_trgm with schema extensions;

create or replace function public.search_people(
  search_query text,
  result_limit integer default 20
)
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_path text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with normalized as (
    select lower(btrim(search_query)) as query
  )
  select profile.id, profile.display_name, profile.username, profile.avatar_url
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
