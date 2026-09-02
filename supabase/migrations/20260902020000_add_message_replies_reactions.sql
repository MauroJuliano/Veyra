alter table public.messages
add column reply_to_message_id uuid references public.messages(id) on delete set null;

create table public.message_reactions (
    message_id uuid not null references public.messages(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    emoji text not null check (char_length(emoji) between 1 and 16),
    created_at timestamptz not null default now(),
    primary key (message_id, user_id, emoji)
);

alter table public.message_reactions enable row level security;

create policy "members can view message reactions"
on public.message_reactions for select to authenticated
using (
    exists (
        select 1 from public.messages message
        where message.id = message_id
          and private.is_conversation_member(message.conversation_id)
    )
);

create policy "members can add their reactions"
on public.message_reactions for insert to authenticated
with check (
    user_id = auth.uid()
    and exists (
        select 1 from public.messages message
        where message.id = message_id
          and private.is_conversation_member(message.conversation_id)
    )
);

create policy "users can remove their reactions"
on public.message_reactions for delete to authenticated
using (user_id = auth.uid());

create or replace function public.toggle_message_reaction(target_message_id uuid, target_emoji text)
returns void
language plpgsql security invoker set search_path = ''
as $$
begin
    if not exists (
        select 1 from public.messages message
        where message.id = target_message_id
          and private.is_conversation_member(message.conversation_id)
    ) then
        raise exception 'Message not found';
    end if;

    if exists (
        select 1 from public.message_reactions reaction
        where reaction.message_id = target_message_id
          and reaction.user_id = auth.uid()
          and reaction.emoji = target_emoji
    ) then
        delete from public.message_reactions
        where message_id = target_message_id
          and user_id = auth.uid()
          and emoji = target_emoji;
    else
        insert into public.message_reactions(message_id, user_id, emoji)
        values (target_message_id, auth.uid(), target_emoji);
    end if;
end;
$$;

revoke execute on function public.toggle_message_reaction(uuid, text) from public, anon;
grant execute on function public.toggle_message_reaction(uuid, text) to authenticated;

drop function if exists public.list_conversation_messages(uuid);
create function public.list_conversation_messages(target_conversation_id uuid)
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
    order by message.created_at asc;
$$;

revoke execute on function public.list_conversation_messages(uuid) from public, anon;
grant execute on function public.list_conversation_messages(uuid) to authenticated;

alter publication supabase_realtime add table public.message_reactions;
