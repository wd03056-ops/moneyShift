import 'package:flutter/foundation.dart';

import '../../../models/user_model.dart';
import '../../../services/fcm_service.dart';
import '../domain/app_user_role.dart';
import 'auth_integration_service.dart';
import 'kakao_auth_service.dart';
import 'mock_auth_service.dart';

/// 인증 파사드 (Clean Architecture — features/auth)
///
/// 카카오 `user.id` 를 Firestore `users/{uid}` Document ID 로 사용한다.
class AuthService {
  AuthService({
    AuthIntegrationService? integration,
    FcmService? fcm,
  })  : _integration = integration ?? AuthIntegrationService.instance,
        _fcm = fcm ?? FcmService.instance;

  static final AuthService instance = AuthService();

  final AuthIntegrationService _integration;
  final FcmService _fcm;

  /// Mock / 카카오 분기 로그인
  Future<AuthSessionResult> signIn({
    AppUserRole role = AppUserRole.worker,
    MockAuthPersona mockPersona = MockAuthPersona.owner,
  }) {
    return _integration.signIn(
      persona: mockPersona,
      defaultRole: role.toMemberRole(),
    );
  }

  /// 실제 카카오 로그인 → users/{kakaoUserId} upsert → FCM 토큰 갱신
  Future<AuthSessionResult> signInWithKakao({
    AppUserRole role = AppUserRole.worker,
  }) {
    return _integration.signInWithKakao(defaultRole: role.toMemberRole());
  }

  Future<AuthSessionResult> signInWithMock({
    MockAuthPersona persona = MockAuthPersona.owner,
  }) {
    return _integration.signInWithMock(persona: persona);
  }

  /// 로그인 직후 FCM 토큰을 users/{uid}.fcmToken 에 반영
  Future<void> refreshFcmToken(String uid) async {
    await _fcm.bindUser(uid);
    debugPrint('[AuthService] FCM refresh requested uid=$uid');
  }

  /// 카카오 프로필 → UserModel (Document ID = kakao id)
  static UserModel userFromKakao(
    KakaoAuthResult kakao, {
    AppUserRole role = AppUserRole.worker,
    UserModel? existing,
  }) {
    return UserModel(
      uid: kakao.userId,
      email: kakao.email ?? existing?.email ?? '',
      displayName: kakao.nickname,
      realName: existing?.realName,
      kakaoId: kakao.userId,
      profileImageUrl: kakao.profileImageUrl,
      role: existing?.role ?? role.toMemberRole(),
      authProvider: 'kakao',
      fcmToken: existing?.fcmToken,
      fcmTokens: existing?.fcmTokens ?? const [],
      ownedRoomCount: existing?.ownedRoomCount ?? 0,
    );
  }
}
