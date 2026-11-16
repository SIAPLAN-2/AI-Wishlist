-- 관리자를 화면에서 추가·삭제하기 위한 함수 (Supabase SQL Editor 에서 한 번 실행)
-- 중요: Authentication > Sign In / Providers > Email 에서 "Confirm email"(이메일 인증)이 반드시 켜져 있어야 합니다.
--       꺼져 있으면 남의 메일로 가입해 관리자가 될 수 있습니다.
create table if not exists public.admin_invites (
  email text primary key,
  invited_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.admin_invites enable row level security;

-- 초대받은 메일로 인증을 마친 사람이 로그인하면 관리자로 등록
create or replace function public.claim_admin() returns boolean
language plpgsql security definer set search_path = public, auth as $$
declare e text;
begin
  select lower(email) into e from auth.users
   where id = auth.uid() and email_confirmed_at is not null and not coalesce(is_anonymous, false);
  if e is null then return false; end if;
  if exists (select 1 from public.admin_invites where lower(email) = e) then
    insert into public.admins (user_id) values (auth.uid()) on conflict do nothing;
    delete from public.admin_invites where lower(email) = e;
  end if;
  return public.is_admin();
end $$;

create or replace function public.list_admins()
returns table (user_id uuid, email text, me boolean, pending boolean)
language sql stable security definer set search_path = public, auth as $$
  select a.user_id, u.email::text, (a.user_id = auth.uid()), false
    from public.admins a join auth.users u on u.id = a.user_id where public.is_admin()
  union all
  select null::uuid, i.email, false, true from public.admin_invites i where public.is_admin()
  order by 4, 2
$$;

create or replace function public.invite_admin(p_email text) returns void
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid; e text := lower(trim(p_email));
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select id into uid from auth.users
   where lower(email) = e and email_confirmed_at is not null and not coalesce(is_anonymous, false) limit 1;
  if uid is not null then
    insert into public.admins (user_id) values (uid) on conflict do nothing;
  else
    insert into public.admin_invites (email) values (e) on conflict do nothing;
  end if;
end $$;

create or replace function public.remove_admin(p_user_id uuid, p_email text) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if p_user_id is not null then
    if (select count(*) from public.admins) <= 1 then raise exception 'last admin'; end if;
    delete from public.admins where user_id = p_user_id;
  else
    delete from public.admin_invites where lower(email) = lower(p_email);
  end if;
end $$;

revoke all on function public.claim_admin(), public.list_admins(), public.invite_admin(text), public.remove_admin(uuid, text) from public, anon;
grant execute on function public.claim_admin(), public.list_admins(), public.invite_admin(text), public.remove_admin(uuid, text) to authenticated;
