create or replace function public.start_direct_conversation_with_user(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    current_user_id uuid := auth.uid();
    existing_conversation_id uuid;
    new_conversation_id uuid;
begin
    if current_user_id is null then
        raise exception 'Authentication required';
    end if;

    if target_user_id = current_user_id then
        raise exception 'You cannot start a conversation with yourself';
    end if;

    if not exists (select 1 from public.profiles where id = target_user_id) then
        raise exception 'User not found';
    end if;

    if not exists (
        select 1
        from public.contacts
        where owner_id = current_user_id
          and contact_id = target_user_id
    ) then
        raise exception 'Contact not found';
    end if;

    select cm.conversation_id
    into existing_conversation_id
    from public.conversation_members cm
    join public.conversation_members other
      on other.conversation_id = cm.conversation_id
     and other.user_id = target_user_id
    where cm.user_id = current_user_id
      and (
          select count(*)
          from public.conversation_members members
          where members.conversation_id = cm.conversation_id
      ) = 2
    limit 1;

    if existing_conversation_id is not null then
        return existing_conversation_id;
    end if;

    insert into public.conversations default values
    returning id into new_conversation_id;

    insert into public.conversation_members (conversation_id, user_id)
    values
        (new_conversation_id, current_user_id),
        (new_conversation_id, target_user_id);

    insert into public.contacts (owner_id, contact_id)
    values
        (current_user_id, target_user_id),
        (target_user_id, current_user_id)
    on conflict do nothing;

    return new_conversation_id;
end;
$$;

revoke execute on function public.start_direct_conversation_with_user(uuid) from public, anon;
grant execute on function public.start_direct_conversation_with_user(uuid) to authenticated;
