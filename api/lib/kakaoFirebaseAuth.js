/**
 * 카카오 access token → Firebase Custom Token
 *
 * - /v2/user/me 로 ID·프로필·이메일 검증
 * - Firebase Auth UID = 카카오 회원번호(숫자 문자열) — Firestore users/{uid} 와 동일
 * - 커스텀 클레임에 provider=kakao 포함
 */
const { getAdmin, isConfigured } = require('./firebaseAdmin');

/**
 * Firebase Auth UID 규칙: 1~128자, printable ASCII(공백 제외).
 * 기존 users/{kakaoId} 문서와 맞추기 위해 숫자 ID만 사용 (kakao: 접두사 미사용).
 * @param {string} kakaoId
 * @returns {string}
 */
function toFirebaseUid(kakaoId) {
  const id = String(kakaoId || '').trim();
  if (!id) {
    const err = new Error('카카오 회원번호가 비어 있습니다.');
    err.code = 'invalid_uid';
    throw err;
  }
  if (id.length > 128) {
    const err = new Error('카카오 회원번호가 너무 깁니다.');
    err.code = 'invalid_uid';
    throw err;
  }
  // 카카오 id 는 숫자. 비정상 문자 차단
  if (!/^[0-9]+$/.test(id)) {
    const err = new Error('카카오 회원번호 형식이 올바르지 않습니다.');
    err.code = 'invalid_uid';
    throw err;
  }
  return id;
}

/**
 * 카카오 사용자 정보 조회 (/v2/user/me)
 * @returns {Promise<{ id: string, nickname: string|null, email: string|null, profileImageUrl: string|null }|null>}
 */
async function fetchKakaoUserProfile(accessToken) {
  try {
    const res = await fetch('https://kapi.kakao.com/v2/user/me', {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
      },
    });
    if (!res.ok) {
      console.error(
        '[kakaoFirebaseAuth] /v2/user/me status=',
        res.status,
      );
      return null;
    }
    const body = await res.json();
    if (body == null || body.id == null) return null;

    const account = body.kakao_account || {};
    const profile = account.profile || {};
    return {
      id: String(body.id),
      nickname:
        typeof profile.nickname === 'string' && profile.nickname.trim()
          ? profile.nickname.trim()
          : null,
      email:
        typeof account.email === 'string' && account.email.trim()
          ? account.email.trim()
          : null,
      profileImageUrl:
        typeof profile.profile_image_url === 'string'
          ? profile.profile_image_url
          : typeof profile.thumbnail_image_url === 'string'
            ? profile.thumbnail_image_url
            : null,
    };
  } catch (e) {
    console.error('[kakaoFirebaseAuth] fetchKakaoUserProfile FAIL:', e);
    return null;
  }
}

/**
 * @param {{ kakaoAccessToken: string, kakaoUserId?: string }} input
 */
async function exchangeKakaoForFirebaseToken(input) {
  try {
    const accessToken = String(input.kakaoAccessToken || '').trim();
    if (!accessToken) {
      return {
        ok: false,
        status: 400,
        error: 'kakao_token_required',
        message: 'kakaoAccessToken 이 필요합니다.',
      };
    }

    let adminReady = false;
    try {
      adminReady = isConfigured();
    } catch (e) {
      console.error('[kakaoFirebaseAuth] isConfigured threw:', e);
      adminReady = false;
    }
    if (!adminReady) {
      return {
        ok: false,
        status: 503,
        error: 'firebase_admin_not_configured',
        message:
          '서버 Firebase Admin 이 설정되지 않았습니다. '
          + 'FIREBASE_SERVICE_ACCOUNT_JSON 을 확인하세요.',
      };
    }

    const profile = await fetchKakaoUserProfile(accessToken);
    if (!profile) {
      return {
        ok: false,
        status: 401,
        error: 'kakao_token_invalid',
        message:
          '카카오 사용자 정보를 조회하지 못했습니다. 토큰이 만료됐거나 권한이 없습니다.',
      };
    }

    let uid;
    try {
      uid = toFirebaseUid(profile.id);
    } catch (e) {
      return {
        ok: false,
        status: 400,
        error: e.code || 'invalid_uid',
        message: e.message || 'Firebase UID 형식이 올바르지 않습니다.',
      };
    }

    const claimed = String(input.kakaoUserId || '').trim();
    if (claimed) {
      let claimedUid;
      try {
        claimedUid = toFirebaseUid(claimed.replace(/^kakao:/i, ''));
      } catch {
        return {
          ok: false,
          status: 400,
          error: 'kakao_uid_invalid',
          message: '요청한 kakaoUserId 형식이 올바르지 않습니다.',
        };
      }
      if (claimedUid !== uid) {
        return {
          ok: false,
          status: 403,
          error: 'kakao_uid_mismatch',
          message: '카카오 회원번호가 토큰과 일치하지 않습니다.',
        };
      }
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
      const customToken = await admin.auth().createCustomToken(uid, {
        provider: 'kakao',
        kakaoId: uid,
      });
      if (!customToken || typeof customToken !== 'string') {
        return {
          ok: false,
          status: 500,
          error: 'custom_token_empty',
          message: 'Custom Token 이 비어 있습니다.',
        };
      }
      return {
        ok: true,
        customToken,
        uid,
        profile: {
          nickname: profile.nickname,
          email: profile.email,
          profileImageUrl: profile.profileImageUrl,
        },
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
  } catch (e) {
    // 절대 프로세스 다운 금지
    console.error('[kakaoFirebaseAuth] unexpected:', e);
    return {
      ok: false,
      status: 500,
      error: 'internal',
      message: e.message || '토큰 교환 중 오류가 발생했습니다.',
    };
  }
}

module.exports = {
  exchangeKakaoForFirebaseToken,
  fetchKakaoUserProfile,
  toFirebaseUid,
};
