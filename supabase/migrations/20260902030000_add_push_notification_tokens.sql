create table public.push_notification_tokens (
    token text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    platform text not null default 'ios' check (platform = 'ios'),
    updated_at timestamptz not null default now()
);

alter table public.push_notification_tokens enable row level security;

create policy "users can view their push tokens"
on public.push_notification_tokens for select to authenticated
using (user_id = auth.uid());

create policy "users can delete their push tokens"
on public.push_notification_tokens for delete to authenticated
using (user_id = auth.uid());

create or replace function public.register_push_token(device_token text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
    if auth.uid() is null then raise exception 'Authentication required'; end if;
    insert into public.push_notification_tokens(token, user_id, updated_at)
    values (device_token, auth.uid(), now())
    on conflict (token) do update
      set user_id = excluded.user_id, updated_at = excluded.updated_at;
end;
$$;

create or replace function public.unregister_push_token(device_token text)
returns void language sql security invoker set search_path = ''
as $$
    delete from public.push_notification_tokens
    where token = device_token and user_id = auth.uid();
$$;

revoke execute on function public.register_push_token(text) from public, anon;
revoke execute on function public.unregister_push_token(text) from public, anon;
grant execute on function public.register_push_token(text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
