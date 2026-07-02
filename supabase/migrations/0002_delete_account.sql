-- Self-service account deletion (required by App Store for apps with
-- account creation). The security-definer function deletes the calling
-- user's auth row; all app data cascades via the user_id foreign keys.

create or replace function public.delete_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

-- Only authenticated users may call it (and only affect themselves).
revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
