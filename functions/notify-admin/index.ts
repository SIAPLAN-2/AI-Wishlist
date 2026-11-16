// 선택: 새 요청이 들어오면 관리자 메일로 알림 (사이트를 닫아 두어도 받을 수 있음)
// 배포: supabase functions deploy notify-admin --no-verify-jwt
// 비밀값: supabase secrets set RESEND_API_KEY=... ADMIN_EMAILS=a@x.com,b@x.com FROM_EMAIL="AI Wishlist <noti@your-domain.com>"
// 연결: Database > Webhooks 에서 requests 테이블 INSERT 시 이 함수 호출
Deno.serve(async (req) => {
  const { record } = await req.json();
  const to = (Deno.env.get("ADMIN_EMAILS") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: Deno.env.get("FROM_EMAIL"), to,
      subject: `[AI Wishlist] 새 요청: ${record.title}`,
      text: `분야: ${record.category}\n\n${record.description}\n\n관리자 화면에서 승인해 주세요.`,
    }),
  });
  return new Response(res.ok ? "ok" : "fail", { status: res.ok ? 200 : 500 });
});
