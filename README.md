# AI Wishlist for SIAPLAN

우리 팀 업무에 도입하고 싶은 AI 기능을 익명으로 요청하고 진행 상황을 확인하는 게시판입니다.
**`index.html` 한 파일**(HTML+CSS+JS 통합)과 Supabase(무료 DB)로 동작합니다.

## 구성
| 경로 | 설명 |
|---|---|
| `index.html` | 사이트 전체 (설정 값은 파일 상단 `<script>` 의 `window.CFG`) |
| `db/0001_init.sql`, `0002_admin_management.sql`, `0003_fix_votes_realtime.sql` | DB 구조·권한 규칙 (**번호순으로 모두 실행**) |
| `functions/notify-admin/` | 새 요청 메일 알림 (선택) |
| `.github/workflows/deploy.yml` | main 에 push 하면 GitHub Pages 자동 배포 |

## 설치
1. **Supabase** 프로젝트 생성 → *Authentication > Sign In / Providers*: **Allow anonymous sign-ins** 켜기, Email 의 **Confirm email** 켜기.
2. SQL Editor 에서 `db/0001_init.sql` → `0002_admin_management.sql` → `0003_fix_votes_realtime.sql` 순서로 실행.
3. Authentication > Users 에서 첫 관리자(본인 회사 메일) 생성 후 실행:
   `insert into public.admins (user_id) select id from auth.users where email = '내이메일@회사.com';`
   (이후 관리자 추가·교체는 사이트의 "관리자 관리" 화면에서)
4. 이 폴더를 GitHub 저장소로 올리기:
   ```bash
   git remote add origin https://github.com/계정명/저장소명.git
   git push -u origin main --tags
   ```
5. 저장소 **Settings > Secrets and variables > Actions > Variables** 에 추가:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY` (Supabase > Project Settings > API 값. service_role 키는 금지)
6. **Settings > Pages > Source: GitHub Actions** 선택 → 배포 완료 후 주소 확인.
   - 요청자: `https://계정명.github.io/저장소명/` · 관리자: 주소 끝에 `#admin`

> 비공개(private) 저장소의 Pages 는 유료 플랜이 필요합니다. 코드를 비공개로 하려면 Netlify / Cloudflare Pages 에 이 저장소를 연결하세요.
> 로컬에서 바로 열어 보려면 `index.html` 상단 `window.CFG` 에 값을 직접 입력하세요.

## 수정·버전 관리
```bash
git switch -c feature/수정내용
# index.html 수정 후
git add -A && git commit -m "feat: 설명"
git push -u origin feature/수정내용   # GitHub 에서 Pull Request → Merge → 자동 배포
git tag -a v1.2.0 -m "v1.2.0" && git push --tags   # 릴리스 표시
```
- `main` = 운영 버전. 잘못 배포했다면 해당 커밋을 GitHub 에서 **Revert**.
- 변경할 때마다 `CHANGELOG.md` 에 한 줄 추가.
- DB 변경은 `db/0004_xxx.sql` 처럼 **새 파일**로 추가해 실행 (기존 파일 수정 금지). 실행 전 백업하고, 전후 게시물 수를 비교하세요 (운영 매뉴얼 6장).
- 코드(`index.html`) 업데이트는 데이터와 무관합니다. 데이터는 Supabase 에 있어 재배포해도 게시물은 그대로입니다.

## 보안
- 커밋 금지: `service_role` 키, Resend API 키, 관리자 비밀번호, `.env`
- 공개 가능: Supabase URL, anon 키 (실제 권한은 DB 규칙이 제어)
- 링크를 아는 누구나 접속할 수 있으므로 링크는 사내에만 공유하고, 요청에 개인정보·기밀을 쓰지 않게 안내하세요.
