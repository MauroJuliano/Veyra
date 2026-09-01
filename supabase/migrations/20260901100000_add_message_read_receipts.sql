create or replace function public.list_conversation_messages(target_conversation_id uuid)
returns table (
    id uuid,
    conversation_id uuid,
    sender_id uuid,
    body text,
    created_at timestamptz,
    is_read boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        message.id,
        message.conversation_id,
        message.sender_id,
        message.body,
        message.created_at,
        case
            when message.sender_id <> auth.uid() then true
            else coalesce(recipient.last_read_at >= message.created_at, false)
        end as is_read
    from public.messages message
    left join public.conversation_members recipient
      on recipient.conversation_id = message.conversation_id
     and recipient.user_id <> message.sender_id
    where message.conversation_id = target_conversation_id
      and private.is_conversation_member(message.conversation_id)
    order by message.created_at asc;
$$;

revoke execute on function public.list_conversation_messages(uuid) from public, anon;
grant execute on function public.list_conversation_messages(uuid) to authenticated;
