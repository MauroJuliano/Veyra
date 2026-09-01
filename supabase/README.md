# Veyra Supabase backend

The migrations in this directory define the backend contract used by the iOS app.

## Apply the schema

For the current hosted project, open **Supabase Dashboard → SQL Editor**, paste the
contents of `migrations/20260901020000_create_chat_schema.sql`, and run it once.

The migration creates:

- a profile for every newly registered Auth user;
- conversations, memberships, and text messages;
- indexes used by the inbox and message timeline;
- Row Level Security policies that restrict chats to their members;
- Realtime publication for new messages.

Do not run application queries with a secret or `service_role` key. The iOS app
must use only its publishable key and rely on the authenticated user's JWT plus RLS.
