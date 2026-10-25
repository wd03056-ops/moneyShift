/**
 * Firebase Admin 초기화
 *
 * 필수 환경변수 (Vercel):
 * - FIREBASE_SERVICE_ACCOUNT_JSON : 서비스 계정 JSON 문자열
 *
 * 선택:
 * - FIREBASE_PROJECT_ID : 프로젝트 ID (JSON에 project_id 없을 때)
 * - GOOGLE_APPLICATION_CREDENTIALS : 로컬 파일 경로 (개발용)
 *
 * JSON.parse / 초기화 실패 시 throw 하지 않고 { error } 로 반환한다.
 */
let _app = null;
let _db = null;
let _initError = null;
let _initLogged = false;

/**
 * @returns {{ ok: true, serviceAccount: object } | { ok: false, error: string }}
 */
function parseServiceAccount(raw) {
  try {
    const trimmed = String(raw || '').trim();
    if (!trimmed) {
      return { ok: false, error: 'FIREBASE_SERVICE_ACCOUNT_JSON empty' };
    }

    let parsed = null;

    // 1) 일반 JSON
    try {
      parsed = JSON.parse(trimmed);
    } catch (_) {
      // 2) 줄바꿈이 실제 \n 으로 깨진 경우
      try {
        parsed = JSON.parse(trimmed.replace(/\r\n/g, '\\n'));
      } catch (_) {
        // 3) Base64 인코딩된 JSON
        try {
          const decoded = Buffer.from(trimmed, 'base64').toString('utf8');
          parsed = JSON.parse(decoded);
        } catch (e3) {
          return {
            ok: false,
            error: `FIREBASE_SERVICE_ACCOUNT_JSON parse failed: ${e3.message}`,
          };
        }
      }
    }

    if (!parsed || typeof parsed !== 'object') {
      return { ok: false, error: 'service account JSON is not an object' };
    }

    if (typeof parsed.private_key === 'string') {
      parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
    }

    if (!parsed.client_email || !parsed.private_key) {
      return {
        ok: false,
        error: 'FIREBASE_SERVICE_ACCOUNT_JSON must include client_email and private_key',
      };
    }

    return { ok: true, serviceAccount: parsed };
  } catch (e) {
    return {
      ok: false,
      error: e.message || 'parseServiceAccount unexpected error',
    };
  }
}

function getAdmin() {
  try {
    if (_app) {
      try {
        // eslint-disable-next-line global-require
        return { admin: require('firebase-admin'), app: _app, db: _db, error: null };
      } catch (e) {
        return {
          admin: null,
          app: null,
          db: null,
          error: e.message || 'firebase_admin_require_failed',
        };
      }
    }
    if (_initError) {
      return { admin: null, app: null, db: null, error: _initError };
    }

    // eslint-disable-next-line global-require
    const admin = require('firebase-admin');
    if (admin.apps.length) {
      _app = admin.app();
      _db = admin.firestore();
      return { admin, app: _app, db: _db, error: null };
    }

    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    let credential;
    let projectId = process.env.FIREBASE_PROJECT_ID || undefined;

    if (raw && String(raw).trim()) {
      const parsed = parseServiceAccount(raw);
      if (!parsed.ok) {
        _initError = parsed.error;
        if (!_initLogged) {
          console.error('[firebaseAdmin]', _initError);
          _initLogged = true;
        }
        return { admin: null, app: null, db: null, error: _initError };
      }
      credential = admin.credential.cert(parsed.serviceAccount);
      if (!projectId && parsed.serviceAccount.project_id) {
        projectId = parsed.serviceAccount.project_id;
      }
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      credential = admin.credential.applicationDefault();
    } else {
      _initError = 'firebase_admin_not_configured';
      if (!_initLogged) {
        console.error(
          '[firebaseAdmin] FIREBASE_SERVICE_ACCOUNT_JSON (or GOOGLE_APPLICATION_CREDENTIALS) required',
        );
        _initLogged = true;
      }
      return { admin: null, app: null, db: null, error: _initError };
    }

    _app = admin.initializeApp({
      credential,
      ...(projectId ? { projectId } : {}),
    });
    _db = admin.firestore();
    if (!_initLogged) {
      console.log(
        `[firebaseAdmin] initialized projectId=${projectId || '(default)'}`,
      );
      _initLogged = true;
    }
    return { admin, app: _app, db: _db, error: null };
  } catch (e) {
    _initError = e.message || 'firebase_admin_init_failed';
    if (!_initLogged) {
      console.error('[firebaseAdmin] init FAIL:', _initError);
      _initLogged = true;
    }
    return { admin: null, app: null, db: null, error: _initError };
  }
}

function isConfigured() {
  try {
    const { db, error } = getAdmin();
    return Boolean(db) && !error;
  } catch (e) {
    console.error('[firebaseAdmin] isConfigured FAIL:', e);
    return false;
  }
}

module.exports = { getAdmin, isConfigured, parseServiceAccount };
