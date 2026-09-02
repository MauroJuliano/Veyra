alter table public.messages add column image_path text;

insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', false)
on conflict (id) do update set public = false;

create policy "members can view chat media"
on storage.objects for select to authenticated
using (
    bucket_id = 'chat-media'
    and private.is_conversation_member(((storage.foldername(name))[2])::uuid)
);

create policy "members can upload own chat media"
on storage.objects for insert to authenticated
with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.is_conversation_member(((storage.foldername(name))[2])::uuid)
);

drop function if exists public.list_conversation_messages(uuid);
create function public.list_conversation_messages(target_conversation_id uuid)
returns table (id uuid, conversation_id uuid, sender_id uuid, body text,
               created_at timestamptz, is_read boolean, image_path text)
language sql stable security invoker set search_path = ''
as $$
    select message.id, message.conversation_id, message.sender_id, message.body,
           message.created_at,
           case when message.sender_id <> auth.uid() then true
                else coalesce(recipient.last_read_at >= message.created_at, false) end,
           message.image_path
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
