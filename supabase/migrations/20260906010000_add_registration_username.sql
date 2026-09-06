create or replace function public.check_username_availability(requested_username text)
returns table(available boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.profiles
    where username = lower(btrim(requested_username))
  );
$$;

revoke all on function public.check_username_availability(text) from public;
grant execute on function public.check_username_availability(text) to anon, authenticated;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_name text;
  requested_username text;
  email_name text;
begin
  requested_name := nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '');
  requested_username := lower(nullif(btrim(new.raw_user_meta_data ->> 'username'), ''));
  email_name := split_part(coalesce(new.email, ''), '@', 1);

  if requested_username is null or requested_username !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'Invalid username';
  end if;

  insert into public.profiles (id, display_name, username)
  values (
    new.id,
    case
      when char_length(coalesce(requested_name, '')) >= 2 then requested_name
      when char_length(email_name) >= 2 then email_name
      else 'Veyra user'
    end,
    requested_username
  );

  return new;
exception
  when unique_violation then
    raise exception 'Username already in use';
end;
$$;

revoke execute on function public.create_profile_for_new_user() from public, anon, authenticated;
