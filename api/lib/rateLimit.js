/**
 * 인메모리 Rate Limiter (Vercel 서버리스 — 인스턴스 단위)
 *
 * - IP + (선택) userId 버킷
 * - 기본: 60초당 60회
 * - 민감 경로(탈퇴 등): 별도 더 낮은 한도
 *
 * 서버리스는 인스턴스가 여러 개일 수 있어 전역 보장은 아니지만
 * 단일 인스턴스 폭주·봇 연타를 막는 1차 방어선으로 충분하다.
 */

const DEFAULT_WINDOW_MS = 60_000;
const DEFAULT_MAX = 60;

/** @type {Map<string, { count: number, resetAt: number }>} */
const buckets = new Map();

let lastPrune = 0;

function prune(now) {
  if (now - lastPrune < 30_000) return;
  lastPrune = now;
  if (buckets.size < 200) return;
  for (const [key, v] of buckets) {
    if (v.resetAt <= now) buckets.delete(key);
  }
  // 폭주 시 상한
  if (buckets.size > 5000) {
    buckets.clear();
  }
}

function clientIp(req) {
  const xf = req.headers['x-forwarded-for'];
  if (typeof xf === 'string' && xf.trim()) {
    return xf.split(',')[0].trim();
  }
  if (typeof req.headers['x-real-ip'] === 'string') {
    return req.headers['x-real-ip'].trim();
  }
  return req.socket?.remoteAddress || 'unknown';
}

function userKey(req) {
  const bodyUid =
    req.body && typeof req.body === 'object' ? req.body.userId : null;
  const headerUid = req.headers['x-user-id'];
  const uid = String(bodyUid || headerUid || '').trim();
  return uid || null;
}

/**
 * @param {{ windowMs?: number, max?: number, skip?: (req) => boolean }} opts
 */
function createRateLimiter(opts = {}) {
  const windowMs = opts.windowMs ?? DEFAULT_WINDOW_MS;
  const max = opts.max ?? DEFAULT_MAX;
  const skip = opts.skip;

  return function rateLimitMiddleware(req, res, next) {
    try {
      if (typeof skip === 'function' && skip(req)) {
        return next();
      }

      const now = Date.now();
      prune(now);

      const ip = clientIp(req);
      const uid = userKey(req);
      // IP 버킷 + (있으면) 유저 버킷 둘 다 검사 — 둘 중 하나라도 초과 시 차단
      const keys = [`ip:${ip}`];
      if (uid) keys.push(`uid:${uid}`);

      for (const key of keys) {
        let entry = buckets.get(key);
        if (!entry || entry.resetAt <= now) {
          entry = { count: 0, resetAt: now + windowMs };
          buckets.set(key, entry);
        }
        entry.count += 1;
        if (entry.count > max) {
          const retryAfterSec = Math.max(
            1,
            Math.ceil((entry.resetAt - now) / 1000),
          );
          res.setHeader('Retry-After', String(retryAfterSec));
          res.setHeader('X-RateLimit-Limit', String(max));
          res.setHeader('X-RateLimit-Remaining', '0');
          return res.status(429).json({
            ok: false,
            error: 'rate_limited',
            message: '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
            retryAfterSec,
          });
        }
        res.setHeader('X-RateLimit-Limit', String(max));
        res.setHeader(
          'X-RateLimit-Remaining',
          String(Math.max(0, max - entry.count)),
        );
      }

      return next();
    } catch (e) {
      console.error('[rateLimit]', e);
      // 제한기 오류 시 API 전체를 막지 않음
      return next();
    }
  };
}

/** 탈퇴 등 고비용 엔드포인트용 (1분 5회) */
function createStrictRateLimiter() {
  return createRateLimiter({ windowMs: 60_000, max: 5 });
}

module.exports = {
  createRateLimiter,
  createStrictRateLimiter,
  clientIp,
};
