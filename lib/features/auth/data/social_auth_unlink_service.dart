import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import 'kakao_auth_service.dart';

/// 소셜 로그인 연동 해제 (Unlink) + Firebase 세션 종료
class SocialAuthUnlinkService {
  SocialAuthUnlinkService({
    KakaoAuthService? kakao,
    fb_auth.FirebaseAuth? firebaseAuth,
  })  : _kakao = kakao ?? KakaoAuthService.instance,
        _auth = firebaseAuth ?? fb_auth.FirebaseAuth.instance;

  static final SocialAuthUnlinkService instance = SocialAuthUnlinkService();

  final KakaoAuthService _kakao;
  final fb_auth.FirebaseAuth _auth;

  /// 제공자에 맞는 Unlink 후 Firebase signOut
  ///
  /// 실패해도 로컬 토큰은 호출측에서 clear 한다.
  Future<void> unlinkAll({required String authProvider}) async {
    final provider = authProvider.trim().toLowerCase();
    if (provider == 'kakao' || provider.isEmpty) {
      await _unlinkKakao();
    } else if (provider == 'google') {
      await _unlinkGoogle();
    } else if (provider == 'mock' || provider == 'anonymous') {
      // 목업 — 원격 unlink 없음
      debugPrint('[SocialUnlink] skip remote unlink provider=$provider');
    } else {
      debugPrint('[SocialUnlink] unknown provider=$provider — kakao fallback');
      await _unlinkKakao();
    }
    await _signOutFirebase();
  }

  Future<void> _unlinkKakao() async {
    try {
      await _kakao.unlink();
      debugPrint('[SocialUnlink] Kakao unlink OK');
    } catch (e, st) {
      debugPrint('[SocialUnlink] Kakao unlink FAIL: $e');
      debugPrint('$st');
      try {
        await _kakao.signOut();
      } catch (_) {}
    }
  }

  /// Google Sign-In 패키지가 없어도 Firebase 연결 해제·로그아웃은 수행
  Future<void> _unlinkGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final providers = user.providerData.map((p) => p.providerId).toList();
        if (providers.contains('google.com')) {
          await user.unlink('google.com');
          debugPrint('[SocialUnlink] Firebase google.com unlink OK');
        }
      }
    } catch (e, st) {
      debugPrint('[SocialUnlink] Google unlink FAIL: $e');
      debugPrint('$st');
    }
  }

  Future<void> _signOutFirebase() async {
    try {
      final user = _auth.currentUser;
      // 익명 계정은 탈퇴 시 서버측 정리와 맞춰 delete 시도
      if (user != null && user.isAnonymous) {
        try {
          await user.delete();
          debugPrint('[SocialUnlink] Firebase anonymous delete OK');
          return;
        } catch (e) {
          debugPrint('[SocialUnlink] Firebase delete skip: $e');
        }
      }
      await _auth.signOut();
      debugPrint('[SocialUnlink] Firebase signOut OK');
    } catch (e, st) {
      debugPrint('[SocialUnlink] Firebase signOut FAIL: $e');
      debugPrint('$st');
    }
  }

  /// 일반 로그아웃 — unlink 없이 세션만 종료
  Future<void> signOutOnly({required String authProvider}) async {
    final provider = authProvider.trim().toLowerCase();
    if (provider == 'kakao') {
      try {
        await _kakao.signOut();
      } catch (_) {}
    }
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
