-- 0003: 공감 정책 수정 + 관리자 실시간 알림 설정 (Supabase SQL Editor 에서 실행, 여러 번 실행해도 안전)
-- 기존 게시물·공감 데이터는 건드리지 않습니다.

-- 1) 남의 공개 요청에도 공감할 수 있게 함
--    (기존 규칙은 requests 표를 직접 읽어 확인했는데, 그 표는 본인 글만 보이도록 막혀 있어 항상 실패했습니다.)
--    작성자 ID를 공개하지 않으면서 "공개된 요청인지"만 확인하는 함수를 사용합니다.
create or replace function public.request_is_public(p_id uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.requests where id = p_id and status <> 'pending') $$;
revoke all on function public.request_is_public(uuid) from public;
grant execute on function public.request_is_public(uuid) to authenticated;

drop policy if exists vote_insert on public.votes;
create policy vote_insert on public.votes for insert to authenticated
  with check (voter = auth.uid() and public.request_is_public(request_id));

-- 2) 관리자 화면의 새 요청 실시간 알림에 필요한 설정 (이미 등록돼 있으면 건너뜀)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'requests') then
    alter publication supabase_realtime add table public.requests;
  end if;
end $$;
