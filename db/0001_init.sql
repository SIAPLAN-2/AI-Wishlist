-- Supabase > SQL Editor 에 통째로 붙여넣고 Run 하세요.
create table public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admins enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.admins where user_id = auth.uid()) $$;

create table public.requests (
  id uuid primary key default gen_random_uuid(),
  author uuid not null default auth.uid(),
  title text not null check (char_length(title) between 4 and 80),
  description text not null check (char_length(description) between 5 and 1000),
  category text not null check (category in ('디자인','법규분석','도면 작성','도면 검토','서류 작성','모델링','이미지 생성','현장·공정 관리','기타 업무')),
  status text not null default 'pending' check (status in ('pending','received','reviewing','progress','done','hold')),
  files jsonb not null default '[]',
  created_at timestamptz not null default now()
);
create table public.votes (
  request_id uuid references public.requests(id) on delete cascade,
  voter uuid not null default auth.uid(),
  primary key (request_id, voter)
);
alter table public.requests enable row level security;
alter table public.votes enable row level security;

-- 요청: 본인과 관리자만 원본(작성자 ID 포함)을 읽을 수 있음. 공개 화면은 아래 board 뷰를 사용.
create policy req_select on public.requests for select to authenticated using (author = auth.uid() or public.is_admin());
create policy req_insert on public.requests for insert to authenticated with check (author = auth.uid() and status = 'pending');
create policy req_update on public.requests for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy req_delete on public.requests for delete to authenticated using (author = auth.uid() or public.is_admin());
-- 공감: 공개된 요청에만, 1인 1표
create policy vote_select on public.votes for select to authenticated using (voter = auth.uid() or public.is_admin());
create policy vote_insert on public.votes for insert to authenticated with check (
  voter = auth.uid() and exists (select 1 from public.requests r where r.id = request_id and r.status <> 'pending'));
create policy vote_delete on public.votes for delete to authenticated using (voter = auth.uid());

-- 공개 게시판 뷰: 작성자 ID는 관리자에게만 일부(alias) 노출
create view public.board as
select r.id, r.title, r.description, r.category, r.status, r.files, r.created_at,
  (select count(*)::int from public.votes v where v.request_id = r.id) as votes,
  exists (select 1 from public.votes v where v.request_id = r.id and v.voter = auth.uid()) as voted,
  (r.author = auth.uid()) as mine,
  case when public.is_admin() then right(r.author::text, 6) end as alias
from public.requests r
where r.status <> 'pending' or r.author = auth.uid() or public.is_admin();
grant select on public.board to anon, authenticated;

-- 첨부 파일 저장소 (5MB, 허용 형식 제한)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attachments','attachments',true,5242880,
  array['image/png','image/jpeg','image/gif','image/webp','application/pdf','text/csv','text/markdown','application/json','text/plain'])
on conflict (id) do nothing;
create policy att_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);
create policy att_delete on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- 관리자 등록 (Authentication > Users 에서 관리자 계정을 먼저 만든 뒤 실행):
-- insert into public.admins (user_id) select id from auth.users where email = 'admin@example.com';
