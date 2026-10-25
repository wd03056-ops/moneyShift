/**
 * 카카오 access token → Firebase Custom Token
 *
 * 익명 로그인(Anonymous)이 콘솔에서 꺼져 있어도
 * Auth UID = 카카오 회원번호 로 세션을 만들 수 있다.
 */
const { getAdmin, isConfigured } = require('./firebaseAdmin');
const { verifyKakaoAccessToken } = require('./accountDeletion');

/**
 * @param {{ kakaoAccessToken: string, kakaoUserId?: string }} input
 * @returns {Promise<{ ok: true, customToken: string, uid: string } | { ok: false, status: number, error: string, message: string }>}
 */
async function exchangeKakaoForFirebaseToken(input) {
  const accessToken = String(input.kakaoAccessToken || '').trim();
  if (!accessToken) {
    return {
      ok: false,
      status: 400,
      error: 'kakao_token_required',
      message: 'kakaoAccessToken 이 필요합니다.',
    };
  }

  if (!isConfigured()) {
    return {
      ok: false,
      status: 503,
      error: 'firebase_admin_not_configured',
      message: '서버 Firebase Admin 이 설정되지 않았습니다.',
    };
  }

  const kakaoId = await verifyKakaoAccessToken(accessToken);
  if (!kakaoId) {
    return {
      ok: false,
      status: 401,
      error: 'kakao_token_invalid',
      message: '카카오 토큰이 유효하지 않습니다.',
    };
  }

  const claimed = String(input.kakaoUserId || '').trim();
  if (claimed && claimed !== kakaoId) {
    return {
      ok: false,
      status: 403,
      error: 'kakao_uid_mismatch',
      message: '카카오 회원번호가 토큰과 일치하지 않습니다.',
    };
  }

  const { admin, error } = getAdmin();
  if (!admin || error) {
    return {
      ok: false,
      status: 503,
      error: 'firebase_admin_unavailable',
      message: error || 'Firebase Admin 초기화 실패',
    };
  }

  try {
    const customToken = await admin.auth().createCustomToken(kakaoId, {
      provider: 'kakao',
      kakaoId,
    });
    return {
      ok: true,
      customToken,
      uid: kakaoId,
    };
  } catch (e) {
    console.error('[kakaoFirebaseAuth] createCustomToken FAIL:', e);
    return {
      ok: false,
      status: 500,
      error: 'custom_token_failed',
      message: e.message || 'Firebase 커스텀 토큰 발급 실패',
    };
  }
}

module.exports = { exchangeKakaoForFirebaseToken };
