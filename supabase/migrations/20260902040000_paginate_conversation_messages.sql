drop function if exists public.list_conversation_messages(uuid);

create function public.list_conversation_messages(
    target_conversation_id uuid,
    before_message_date timestamptz default null,
    page_size integer default 50
)
returns table (
    id uuid, conversation_id uuid, sender_id uuid, body text,
    created_at timestamptz, is_read boolean, image_path text,
    reply_to_message_id uuid, reply_body text, reply_sender_id uuid,
    reactions jsonb
)
language sql stable security invoker set search_path = ''
as $$
    select message.id, message.conversation_id, message.sender_id, message.body,
           message.created_at,
           case when message.sender_id <> auth.uid() then true
                else coalesce(recipient.last_read_at >= message.created_at, false) end,
           message.image_path, message.reply_to_message_id,
           replied.body, replied.sender_id,
           coalesce((
               select jsonb_agg(jsonb_build_object(
                   'emoji', grouped.emoji,
                   'count', grouped.reaction_count,
                   'selected', grouped.selected
               ) order by grouped.emoji)
               from (
                   select reaction.emoji, count(*)::int reaction_count,
                          bool_or(reaction.user_id = auth.uid()) selected
                   from public.message_reactions reaction
                   where reaction.message_id = message.id
                   group by reaction.emoji
               ) grouped
           ), '[]'::jsonb)
    from public.messages message
    left join public.messages replied on replied.id = message.reply_to_message_id
    left join public.conversation_members recipient
      on recipient.conversation_id = message.conversation_id
     and recipient.user_id <> message.sender_id
    where message.conversation_id = target_conversation_id
      and private.is_conversation_member(message.conversation_id)
      and (before_message_date is null or message.created_at < before_message_date)
    order by message.created_at desc
    limit least(greatest(page_size, 1), 100);
$$;

revoke execute on function public.list_conversation_messages(uuid, timestamptz, integer) from public, anon;
grant execute on function public.list_conversation_messages(uuid, timestamptz, integer) to authenticated;
