/**
 * 로컬 개발용 — `npm run dev` 로 Express를 직접 띄웁니다.
 * (Vercel 배포 시에는 사용되지 않음)
 */
const { app } = require('./index');

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => {
  console.log(`[money-shift-api] http://localhost:${port}/api/health`);
});
