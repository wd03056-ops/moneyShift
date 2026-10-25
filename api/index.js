/**
 * Money Shift — Vercel Serverless Express entry
 *
 * Vercel은 이 파일을 서버리스 함수로 배포합니다.
 * 라우트는 vercel.json 에서 /api/* → 이 핸들러로 매핑됩니다.
 *
 * 주의: firebase-admin 은 탈퇴 등 필요 시에만 lazy-load 한다.
 * 헬스체크 경로에서 무거운 모듈을 올리면 FUNCTION_INVOCATION_FAILED 가 날 수 있다.
 */
const express = require('express');
const cors = require('cors');
const {
  createRateLimiter,
  consumeOrReject,
} = require('./lib/rateLimit');

const app = express();

const corsOptions = {
  origin: true, // 요청 Origin 반영 (앱·웹 모두)
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-User-Id',
    'X-Auth-Provider',
    'Accept',
  ],
  exposedHeaders: ['Retry-After'],
  credentials: true,
  maxAge: 86400,
};
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({ limit: '1mb' }));

/** 전역 Rate Limit — 1분 60회 (헬스체크 제외) */
app.use(
  createRateLimiter({
    windowMs: 60_000,
    max: 60,
    skip: (req) => {
      const p = String(req.path || req.url || '').split('?')[0];
      return (
        p === '/api/health' ||
        p === '/health' ||
        p.endsWith('/health') ||
        req.method === 'OPTIONS'
      );
    },
  }),
);

/** env 만 확인 — firebase-admin 로드/초기화 없음 */
function firebaseEnvPresent() {
  try {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (raw && String(raw).trim()) return true;
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) return true;
    return false;
  } catch {
    return false;
  }
}

/** 헬스체크 — Flutter / 배포 확인용 (절대 throw 하지 않음) */
app.get(['/api/health', '/health'], (_req, res) => {
  try {
    return res.status(200).json({
      ok: true,
      service: 'money-shift-api',
      ts: new Date().toISOString(),
      firebaseAdminEnv: firebaseEnvPresent(),
    });
  } catch (e) {
    console.error('[health]', e);
    return res.status(200).json({
      ok: true,
      service: 'money-shift-api',
      degraded: true,
      message: String(e && e.message ? e.message : e),
    });
  }
});

/** 루트 — Vercel 404 방지 + 배포 확인 */
app.get(['/api', '/', '/api/'], (_req, res) => {
  try {
    return res.status(200).json({
      ok: true,
      message: 'Money Shift API',
      endpoints: {
        health: 'GET /api/health',
        authPing: 'GET /api/auth/ping',
        authKakao: 'POST /api/auth/kakao',
        schedulesPing: 'GET /api/schedules/ping',
        laborCostMonthly: 'GET /api/labor-cost/monthly?roomId&year&month',
        accountDelete: 'DELETE /api/account',
      },
      rateLimit: {
        global: '60 req / 60s per IP (and userId if present)',
        accountDelete: '5 req / 60s',
      },
    });
  } catch (e) {
    console.error('[root]', e);
    return res.status(200).json({ ok: true, message: 'Money Shift API' });
  }
});

/** 로그인 관련 임시 ping */
app.get(['/api/auth/ping', '/auth/ping'], (_req, res) => {
  res.status(200).json({
    ok: true,
    area: 'auth',
    message: 'auth router ready',
  });
});

/**
 * 카카오 → Firebase Custom Token
 * POST /api/auth/kakao
 * body: { kakaoAccessToken, kakaoUserId? }
 */
app.post(['/api/auth/kakao', '/auth/kakao'], (req, res) => {
  Promise.resolve(
    (async () => {
      try {
        if (consumeOrReject(req, res, { windowMs: 60_000, max: 20 })) {
          return;
        }

        // eslint-disable-next-line global-require
        const { exchangeKakaoForFirebaseToken } = require('./lib/kakaoFirebaseAuth');
        const body = req.body || {};
        const bearer = (() => {
          const h = req.headers.authorization;
          if (typeof h !== 'string') return '';
          const m = /^Bearer\s+(.+)$/i.exec(h.trim());
          return m ? m[1].trim() : '';
        })();

        const result = await exchangeKakaoForFirebaseToken({
          kakaoAccessToken:
            (typeof body.kakaoAccessToken === 'string' && body.kakaoAccessToken) ||
            bearer,
          kakaoUserId:
            typeof body.kakaoUserId === 'string' ? body.kakaoUserId : undefined,
        });

        if (!result.ok) {
          return res.status(result.status || 400).json({
            ok: false,
            error: result.error,
            message: result.message,
          });
        }

        return res.status(200).json({
          ok: true,
          customToken: result.customToken,
          uid: result.uid,
          profile: result.profile || null,
        });
      } catch (e) {
        console.error('[auth/kakao]', e);
        if (!res.headersSent) {
          return res.status(500).json({
            ok: false,
            error: 'internal',
            message: e.message || 'internal error',
          });
        }
        return undefined;
      }
    })(),
  ).catch((e) => {
    console.error('[auth/kakao] unhandled', e);
    if (!res.headersSent) {
      res.status(500).json({
        ok: false,
        error: 'internal',
        message: '토큰 교환 중 오류가 발생했습니다.',
      });
    }
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
 * 월간 인건비 집계
 * GET /api/labor-cost/monthly?roomId=&year=&month=
 * 선택: includeWeeklyHoliday=true|false
 *       includeEmployerSocialInsurance=true|false
 */
app.get(
  ['/api/labor-cost/monthly', '/labor-cost/monthly'],
  (req, res, next) => {
    Promise.resolve(
      (async () => {
        try {
          // eslint-disable-next-line global-require
          const { computeMonthlyLaborCost } = require('./lib/laborCostMonthly');
          const q = req.query || {};
          const roomId = String(q.roomId || '').trim();
          const year = Number.parseInt(String(q.year || ''), 10);
          const month = Number.parseInt(String(q.month || ''), 10);
          const includeWeeklyHoliday =
            String(q.includeWeeklyHoliday || '').toLowerCase() === 'true';
          const includeEmployerSocialInsurance =
            String(q.includeEmployerSocialInsurance || '').toLowerCase() ===
            'true';

          if (!roomId) {
            return res.status(400).json({
              ok: false,
              error: 'room_id_required',
              message: 'roomId가 필요합니다.',
            });
          }
          if (!Number.isFinite(year) || !Number.isFinite(month)) {
            return res.status(400).json({
              ok: false,
              error: 'invalid_period',
              message: 'year, month가 필요합니다. (예: year=2026&month=10)',
            });
          }

          const result = await computeMonthlyLaborCost({
            roomId,
            year,
            month,
            includeWeeklyHoliday,
            includeEmployerSocialInsurance,
          });
          return res.status(200).json(result);
        } catch (e) {
          const code = (e && e.code) || 'labor_cost_failed';
          const status =
            code === 'firebase_admin_not_configured'
              ? 503
              : code === 'room_id_required' ||
                  code === 'invalid_year' ||
                  code === 'invalid_month' ||
                  code === 'invalid_period'
                ? 400
                : 500;
          console.error('[labor-cost/monthly]', e);
          if (res.headersSent) return undefined;
          return res.status(status).json({
            ok: false,
            error: code,
            message: (e && e.message) || '인건비 집계에 실패했습니다.',
          });
        }
      })(),
    ).catch(next);
  },
);

function _bearerToken(req) {
  const h = req.headers.authorization;
  if (!h || typeof h !== 'string') return null;
  const m = /^Bearer\s+(.+)$/i.exec(h.trim());
  return m ? m[1].trim() : null;
}

function _loadAccountDeletion() {
  // lazy — firebase-admin 포함 모듈을 콜드 패스에서 제외
  // eslint-disable-next-line global-require
  return require('./lib/accountDeletion');
}

/**
 * 회원 탈퇴
 *
 * Body:
 * {
 *   userId: string,
 *   authProvider?: 'kakao' | 'google' | 'mock' | ...,
 *   kakaoAccessToken?: string,
 *   confirm?: true
 * }
 */
async function handleAccountDelete(req, res) {
  try {
    const {
      DELETED_DISPLAY_NAME,
      verifyKakaoAccessToken,
      deleteAccountInFirestore,
      isConfigured: isFirebaseConfigured,
    } = _loadAccountDeletion();

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

    // 검증 통과 후에만 카운트 — 잘못된 요청으로 429 소진 방지
    if (consumeOrReject(req, res, { windowMs: 60_000, max: 5 })) {
      return undefined;
    }

    const bearer = _bearerToken(req);
    const kakaoToken =
      (typeof body.kakaoAccessToken === 'string' && body.kakaoAccessToken) ||
      (authProvider === 'kakao' ? bearer : null);

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
    } else if (
      authProvider === 'kakao' &&
      process.env.REQUIRE_KAKAO_TOKEN === 'true'
    ) {
      return res.status(401).json({
        ok: false,
        error: 'kakao_token_required',
        message: 'kakaoAccessToken 이 필요합니다.',
      });
    }

    let configured = false;
    try {
      configured = Boolean(isFirebaseConfigured());
    } catch (e) {
      console.error('[account/delete] isConfigured', e);
      configured = false;
    }

    if (!configured) {
      return res.status(503).json({
        ok: false,
        error: 'firebase_admin_not_configured',
        message:
          'FIREBASE_SERVICE_ACCOUNT_JSON 이 설정되지 않았거나 초기화에 실패했습니다. '
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
    const code = e && e.code ? e.code : 'account_delete_failed';
    const status =
      code === 'firebase_admin_not_configured'
        ? 503
        : code === 'user_id_required'
          ? 400
          : 500;
    console.error('[account/delete]', e);
    if (res.headersSent) return undefined;
    return res.status(status).json({
      ok: false,
      error: code,
      message: (e && e.message) || '계정 삭제에 실패했습니다.',
    });
  }
}

app.delete(['/api/account', '/account'], (req, res, next) => {
  Promise.resolve(handleAccountDelete(req, res)).catch(next);
});
app.post(['/api/account/delete', '/account/delete'], (req, res, next) => {
  Promise.resolve(handleAccountDelete(req, res)).catch(next);
});

/** 매칭되지 않은 API 경로 */
app.use((req, res) => {
  res.status(404).json({
    ok: false,
    error: 'not_found',
    path: req.path,
  });
});

/** Express 4 error middleware — JSON 파싱·미처리 예외 (프로세스 크래시 방지) */
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, _next) => {
  console.error('[api] unhandled', err);
  if (res.headersSent) return;
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    res.status(400).json({
      ok: false,
      error: 'invalid_json',
      message: 'JSON 형식이 올바르지 않습니다.',
    });
    return;
  }
  res.status(500).json({
    ok: false,
    error: 'internal_error',
    message: (err && err.message) || 'Internal Server Error',
  });
});

/**
 * Vercel @vercel/node 핸들러 래퍼
 * Express app 직접 export 도 동작하지만, 동기 예외를 한 번 더 감싼다.
 */
function handler(req, res) {
  try {
    return app(req, res);
  } catch (e) {
    console.error('[api] sync fatal', e);
    if (!res.headersSent) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.end(
        JSON.stringify({
          ok: false,
          error: 'fatal',
          message: (e && e.message) || 'Internal Server Error',
        }),
      );
    }
    return undefined;
  }
}

module.exports = handler;
module.exports.app = app;
