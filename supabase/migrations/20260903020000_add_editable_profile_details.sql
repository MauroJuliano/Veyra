alter table public.profiles
add column if not exists bio text;

alter table public.profiles
drop constraint if exists profiles_bio_length;

alter table public.profiles
add constraint profiles_bio_length
check (bio is null or char_length(bio) <= 120);

create or replace function public.update_my_profile(
  new_display_name text,
  new_username text,
  new_bio text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_name text := btrim(new_display_name);
  normalized_username text := lower(btrim(new_username));
  normalized_bio text := nullif(btrim(new_bio), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if char_length(normalized_name) < 2 or char_length(normalized_name) > 80 then
    raise exception 'Display name must contain between 2 and 80 characters';
  end if;

  if normalized_username !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'Username must contain 3-30 letters, numbers or underscores';
  end if;

  if char_length(coalesce(normalized_bio, '')) > 120 then
    raise exception 'Bio must contain at most 120 characters';
  end if;

  update public.profiles
  set display_name = normalized_name,
      username = normalized_username,
      bio = normalized_bio
  where id = auth.uid();
end;
$$;

revoke execute on function public.update_my_profile(text, text, text) from public, anon;
grant execute on function public.update_my_profile(text, text, text) to authenticated;
