-- Enable Supabase Realtime for the synced tables so an already-open
-- device is notified the instant another device changes data. Without
-- this, cross-device updates only arrive on the next fallback poll.

alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.areas;
alter publication supabase_realtime add table public.checklist_items;
alter publication supabase_realtime add table public.tags;
