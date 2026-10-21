/**
 * Money Shift — Vercel Serverless Express entry
 *
 * Vercel은 이 파일을 서버리스 함수로 배포합니다.
 * 라우트는 vercel.json 에서 /api/* → 이 핸들러로 매핑됩니다.
 */
const express = require('express');
const cors = require('cors');

const app = express();

app.use(
  cors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);
app.use(express.json({ limit: '1mb' }));

/** 헬스체크 — Flutter / 배포 확인용 */
app.get(['/api/health', '/health'], (_req, res) => {
  res.status(200).json({
    ok: true,
    service: 'money-shift-api',
    ts: new Date().toISOString(),
  });
});

/** 루트 — Vercel 404 방지 + 배포 확인 */
app.get(['/api', '/', '/api/'], (_req, res) => {
  res.status(200).json({
    ok: true,
    message: 'Money Shift API',
    endpoints: {
      health: 'GET /api/health',
      authPing: 'GET /api/auth/ping',
      schedulesPing: 'GET /api/schedules/ping',
    },
  });
});

/** 로그인 관련 임시 ping */
app.get(['/api/auth/ping', '/auth/ping'], (_req, res) => {
  res.status(200).json({
    ok: true,
    area: 'auth',
    message: 'auth router ready',
  });
});

/** 근무표 관련 임시 ping */
app.get(['/api/schedules/ping', '/schedules/ping'], (_req, res) => {
  res.status(200).json({
    ok: true,
    area: 'schedules',
    message: 'schedules router ready',
  });
});

/** 매칭되지 않은 API 경로 */
app.use((req, res) => {
  res.status(404).json({
    ok: false,
    error: 'not_found',
    path: req.path,
  });
});

module.exports = app;
