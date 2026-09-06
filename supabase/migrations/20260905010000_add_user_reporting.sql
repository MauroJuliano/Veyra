create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('spam', 'harassment', 'impersonation', 'inappropriate_content', 'other')),
  details text,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'resolved')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id),
  check (details is null or char_length(details) <= 500)
);

create unique index if not exists one_pending_report_per_user_pair
on public.user_reports (reporter_id, reported_id)
where status = 'pending';

alter table public.user_reports enable row level security;

drop policy if exists "Users can view their reports" on public.user_reports;
create policy "Users can view their reports"
on public.user_reports for select to authenticated
using (reporter_id = auth.uid());

create or replace function public.report_user(
  target_user_id uuid,
  report_reason text,
  report_details text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_details text := nullif(btrim(report_details), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if target_user_id = auth.uid() then
    raise exception 'You cannot report yourself';
  end if;
  if report_reason not in ('spam', 'harassment', 'impersonation', 'inappropriate_content', 'other') then
    raise exception 'Invalid report reason';
  end if;
  if char_length(coalesce(normalized_details, '')) > 500 then
    raise exception 'Report details must contain at most 500 characters';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'User not found';
  end if;
  if exists (
    select 1 from public.user_reports
    where reporter_id = auth.uid()
      and reported_id = target_user_id
      and status = 'pending'
  ) then
    raise exception 'A report for this user is already pending';
  end if;

  insert into public.user_reports (reporter_id, reported_id, reason, details)
  values (auth.uid(), target_user_id, report_reason, normalized_details);
end;
$$;

revoke execute on function public.report_user(uuid, text, text) from public, anon;
grant execute on function public.report_user(uuid, text, text) to authenticated;
