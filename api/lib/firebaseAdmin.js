/**
 * Firebase Admin 초기화
 *
 * 필수 환경변수 (Vercel):
 * - FIREBASE_SERVICE_ACCOUNT_JSON : 서비스 계정 JSON 문자열
 *
 * 선택:
 * - FIREBASE_PROJECT_ID : 프로젝트 ID (JSON에 project_id 없을 때)
 * - GOOGLE_APPLICATION_CREDENTIALS : 로컬 파일 경로 (개발용)
 */
let _app = null;
let _db = null;
let _initError = null;
let _initLogged = false;

function _parseServiceAccount(raw) {
  const trimmed = String(raw || '').trim();
  if (!trimmed) return null;

  let parsed;
  try {
    parsed = JSON.parse(trimmed);
  } catch (e) {
    // Vercel UI에서 따옴표 없이 붙여넣은 경우 대비 — 한 번 더 시도
    try {
      parsed = JSON.parse(trimmed.replace(/\r\n/g, '\\n'));
    } catch {
      throw new Error(`FIREBASE_SERVICE_ACCOUNT_JSON parse failed: ${e.message}`);
    }
  }

  if (parsed && typeof parsed.private_key === 'string') {
    // 환경변수에 \\n 으로 들어온 PEM 줄바꿈 복원
    parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
  }
  return parsed;
}

function getAdmin() {
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

  try {
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
      const serviceAccount = _parseServiceAccount(raw);
      if (!serviceAccount || !serviceAccount.client_email || !serviceAccount.private_key) {
        throw new Error(
          'FIREBASE_SERVICE_ACCOUNT_JSON must include client_email and private_key',
        );
      }
      credential = admin.credential.cert(serviceAccount);
      if (!projectId && serviceAccount.project_id) {
        projectId = serviceAccount.project_id;
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

module.exports = { getAdmin, isConfigured };
