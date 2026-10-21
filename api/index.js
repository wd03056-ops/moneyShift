/**
 * Money Shift — Vercel Serverless Express entry
 *
 * Vercel은 이 파일을 서버리스 함수로 배포합니다.
 * 라우트는 vercel.json 에서 /api/* → 이 핸들러로 매핑됩니다.
 */
const express = require('express');
const cors = require('cors');
const {
  DELETED_DISPLAY_NAME,
  verifyKakaoAccessToken,
  deleteAccountInFirestore,
  isConfigured: isFirebaseConfigured,
} = require('./lib/accountDeletion');

const app = express();

app.use(
  cors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-User-Id', 'X-Auth-Provider'],
  }),
);
app.use(express.json({ limit: '1mb' }));

/** 헬스체크 — Flutter / 배포 확인용 */
app.get(['/api/health', '/health'], (_req, res) => {
  res.status(200).json({
    ok: true,
    service: 'money-shift-api',
    ts: new Date().toISOString(),
    firebaseAdmin: isFirebaseConfigured(),
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
      accountDelete: 'DELETE /api/account',
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

/**
 * 회원 탈퇴
 *
 * Body:
 * {
 *   userId: string,
 *   authProvider?: 'kakao' | 'google' | 'mock' | ...,
 *   kakaoAccessToken?: string,  // kakao 일 때 권장 (토큰 소유자 검증)
 *   confirm?: true              // 실수 방지
 * }
 *
 * Header (선택): Authorization: Bearer <kakao_or_firebase_token>
 */
async function handleAccountDelete(req, res) {
  try {
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const userId = String(
      body.userId || req.headers['x-user-id'] || '',
    ).trim();
    const authProvider = String(
      body.authProvider || req.headers['x-auth-provider'] || 'kakao',
    )
      .trim()
      .toLowerCase();
    const confirm = body.confirm === true;

    if (!userId) {
      return res.status(400).json({
        ok: false,
        error: 'user_id_required',
        message: 'userId가 필요합니다.',
      });
    }
    if (!confirm) {
      return res.status(400).json({
        ok: false,
        error: 'confirm_required',
        message: 'confirm: true 가 필요합니다.',
      });
    }

    const bearer = _bearerToken(req);
    const kakaoToken =
      (typeof body.kakaoAccessToken === 'string' && body.kakaoAccessToken) ||
      (authProvider === 'kakao' ? bearer : null);

    // 카카오 토큰이 있으면 소유자 검증
    if (kakaoToken) {
      const kakaoId = await verifyKakaoAccessToken(kakaoToken);
      if (!kakaoId) {
        return res.status(401).json({
          ok: false,
          error: 'kakao_token_invalid',
          message: '카카오 토큰이 유효하지 않습니다.',
        });
      }
      if (kakaoId !== userId) {
        return res.status(403).json({
          ok: false,
          error: 'user_mismatch',
          message: '토큰 소유자와 userId가 일치하지 않습니다.',
        });
      }
    } else if (authProvider === 'kakao' && process.env.REQUIRE_KAKAO_TOKEN === 'true') {
      return res.status(401).json({
        ok: false,
        error: 'kakao_token_required',
        message: 'kakaoAccessToken 이 필요합니다.',
      });
    }

    if (!isFirebaseConfigured()) {
      return res.status(503).json({
        ok: false,
        error: 'firebase_admin_not_configured',
        message:
          'FIREBASE_SERVICE_ACCOUNT_JSON 이 설정되지 않았습니다. '
          + 'Vercel 환경변수를 확인한 뒤 재배포하세요.',
      });
    }

    const result = await deleteAccountInFirestore({ userId, authProvider });
    return res.status(200).json({
      ok: true,
      mode: 'firestore',
      displayName: result.displayName || DELETED_DISPLAY_NAME,
      written: result.written,
      summary: result.summary,
    });
  } catch (e) {
    const code = e.code || 'account_delete_failed';
    const status =
      code === 'firebase_admin_not_configured' ||
      code === 'user_id_required'
        ? code === 'user_id_required'
          ? 400
          : 503
        : 500;
    console.error('[account/delete]', e);
    return res.status(status).json({
      ok: false,
      error: code,
      message: e.message || '계정 삭제에 실패했습니다.',
    });
  }
}

app.delete(['/api/account', '/account'], handleAccountDelete);
/** 일부 클라이언트/프록시가 DELETE body 를 막으면 POST 로도 허용 */
app.post(['/api/account/delete', '/account/delete'], handleAccountDelete);

function _bearerToken(req) {
  const h = req.headers.authorization;
  if (!h || typeof h !== 'string') return null;
  const m = /^Bearer\s+(.+)$/i.exec(h.trim());
  return m ? m[1].trim() : null;
}

/** 매칭되지 않은 API 경로 */
app.use((req, res) => {
  res.status(404).json({
    ok: false,
    error: 'not_found',
    path: req.path,
  });
});

module.exports = app;
