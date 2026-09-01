drop policy if exists "conversation members can receive broadcasts" on realtime.messages;
drop policy if exists "conversation members can send broadcasts" on realtime.messages;

create table public.typing_status (
    conversation_id uuid not null references public.conversations(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    is_typing boolean not null default false,
    updated_at timestamptz not null default now(),
    primary key (conversation_id, user_id)
);

alter table public.typing_status enable row level security;

create policy "members can read typing status"
on public.typing_status for select to authenticated
using (private.is_conversation_member(conversation_id));

create policy "members can insert own typing status"
on public.typing_status for insert to authenticated
with check (
    user_id = (select auth.uid())
    and private.is_conversation_member(conversation_id)
);

create policy "members can update own typing status"
on public.typing_status for update to authenticated
using (user_id = (select auth.uid()))
with check (
    user_id = (select auth.uid())
    and private.is_conversation_member(conversation_id)
);

grant select, insert, update on public.typing_status to authenticated;

do $$
begin
    alter publication supabase_realtime add table public.typing_status;
exception when duplicate_object then null;
end
$$;
