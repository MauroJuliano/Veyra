drop policy if exists "conversation members can receive broadcasts" on realtime.messages;
create policy "conversation members can receive broadcasts"
on realtime.messages
for select
to authenticated
using (
    realtime.messages.extension = 'broadcast'
    and split_part((select realtime.topic()), ':', 1) = 'conversation'
    and private.is_conversation_member(
        (select auth.uid()),
        split_part((select realtime.topic()), ':', 2)::uuid
    )
);

drop policy if exists "conversation members can send broadcasts" on realtime.messages;
create policy "conversation members can send broadcasts"
on realtime.messages
for insert
to authenticated
with check (
    realtime.messages.extension = 'broadcast'
    and split_part((select realtime.topic()), ':', 1) = 'conversation'
    and private.is_conversation_member(
        (select auth.uid()),
        split_part((select realtime.topic()), ':', 2)::uuid
    )
);
