import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/dev_auth_config.dart';
import '../../../core/config/kakao_config.dart';
import '../../../data/services/api_service.dart';
import '../../../mock/mock_user.dart';
import '../../../models/enums/member_role.dart';
import '../../../models/user_model.dart';
import '../../../services/fcm_service.dart';
import '../../../services/user_firestore_service.dart';
import 'kakao_auth_service.dart';
import 'mock_auth_service.dart';
import 'mock_firestore_seed_service.dart';

/// 인증 통합 진입점
///
/// - [DevAuthConfig.isMockAuthEnabled] == true → Mock UID (카카오 SDK 미호출)
/// - false → 실제 [KakaoAuthService] / `loginWithKakaoTalk`
class AuthIntegrationService {
  AuthIntegrationService({
    KakaoAuthService? kakaoAuth,
    MockAuthService? mockAuth,
    UserFirestoreService? userFirestore,
    MockFirestoreSeedService? seedService,
    fb_auth.FirebaseAuth? firebaseAuth,
  })  : _kakao = kakaoAuth ?? KakaoAuthService.instance,
        _mock = mockAuth ?? MockAuthService.instance,
        _users = userFirestore ?? UserFirestoreService(),
        _seed = seedService ?? MockFirestoreSeedService.instance,
        _auth = firebaseAuth ?? fb_auth.FirebaseAuth.instance;

  static final AuthIntegrationService instance = AuthIntegrationService();

  final KakaoAuthService _kakao;
  final MockAuthService _mock;
  final UserFirestoreService _users;
  final MockFirestoreSeedService _seed;
  final fb_auth.FirebaseAuth _auth;

  /// 플래그에 따라 Mock 또는 카카오 로그인
  Future<AuthSessionResult> signIn({
    MockAuthPersona persona = MockAuthPersona.owner,
    MemberRole defaultRole = MemberRole.parttime,
  }) {
    if (DevAuthConfig.isMockAuthEnabled) {
      return signInWithMock(persona: persona);
    }
    return signInWithKakao(defaultRole: defaultRole);
  }

  /// 개발용 Mock UID 로그인.
  ///
  /// Anonymous Auth 가 콘솔에서 꺼져 있어도(CONFIGURATION_NOT_FOUND)
  /// 로컬 세션은 반드시 성공한다. Firestore/FCM 은 best-effort.
  Future<AuthSessionResult> signInWithMock({
    MockAuthPersona persona = MockAuthPersona.owner,
  }) async {
    debugPrint('[AuthIntegration] Mock sign-in start persona=$persona');

    final profile = _mock.profileFor(persona);
    final kakao = _mock.toKakaoResult(profile);
    final mockUser = _mock.toMockUser(profile);
    var userModel = _mock.toUserModel(profile);
    var firebaseUid = profile.uid;

    // 1) Firebase Anonymous (선택) — 미설정이어도 Mock 로그인 계속
    try {
      final credentialUser = await _ensureFirebaseAuthUser();
      firebaseUid = credentialUser.uid;
      debugPrint(
        '[AuthIntegration] FirebaseAuth OK uid=$firebaseUid '
        '(mockUid=${profile.uid})',
      );
    } on fb_auth.FirebaseAuthException catch (e, st) {
      debugPrint(
        '[AuthIntegration] FirebaseAuth skip code=${e.code} '
        'message=${e.message} — Mock local session only',
      );
      debugPrint('$st');
    } catch (e, st) {
      debugPrint('[AuthIntegration] FirebaseAuth skip: $e');
      debugPrint('$st');
    }

    // 2) Firestore users upsert + 시드 (실패해도 로그인 유지)
    try {
      userModel = await _users.upsert(userModel, mergeKakao: true);
      debugPrint(
        '[AuthIntegration] Mock Firestore upsert OK path=${userModel.docPath}',
      );
      await _seed.ensureDemoData(ownerUid: MockAuthService.ownerUid);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[AuthIntegration] Mock Firestore soft-fail code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
    } catch (e, st) {
      debugPrint('[AuthIntegration] Mock Firestore soft-fail: $e');
      debugPrint('$st');
    }

    // 3) FCM 토큰 바인딩 (선택)
    try {
      await FcmService.instance.bindUser(profile.uid);
    } catch (e, st) {
      debugPrint('[AuthIntegration] FCM bind skip: $e');
      debugPrint('$st');
    }

    debugPrint(
      '[AuthIntegration] Mock sign-in OK mockUid=${profile.uid} '
      'firebaseUid=$firebaseUid',
    );
    return AuthSessionResult(
      kakao: kakao,
      user: userModel,
      firebaseUid: firebaseUid,
      mockUser: mockUser,
      usedMockAuth: true,
    );
  }

  /// 실제 카카오 로그인 → Firebase 익명 세션 → Firestore `users` upsert
  Future<AuthSessionResult> signInWithKakao({
    MemberRole defaultRole = MemberRole.parttime,
  }) async {
    debugPrint('[AuthIntegration] Kakao sign-in start');

    if (!KakaoConfig.isConfigured) {
      final err = StateError(
        '카카오 네이티브 앱 키가 설정되지 않았습니다. '
        'KakaoConfig / kakao.properties / Kakao-Keys.xcconfig 를 확인하세요.',
      );
      debugPrint('[AuthIntegration] FAIL: $err');
      throw err;
    }

    late final KakaoAuthResult kakao;
    try {
      kakao = await _kakao.signIn();
      debugPrint(
        '[AuthIntegration] Kakao OK id=${kakao.userId} '
        'nickname=${kakao.nickname} email=${kakao.email}',
      );
    } on KakaoAuthException catch (e, st) {
      debugPrint(
        '[AuthIntegration] KakaoAuthException error=${e.error} '
        'desc=${e.errorDescription}',
      );
      debugPrint('$st');
      rethrow;
    } on KakaoClientException catch (e, st) {
      debugPrint(
        '[AuthIntegration] KakaoClientException reason=${e.reason} '
        'msg=${e.msg}',
      );
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('[AuthIntegration] Kakao FAIL: $e');
      debugPrint('$st');
      rethrow;
    }

    // Firebase Auth: 커스텀 토큰(권장) → 익명(폴백) → 로컬만(최후)
    final firebaseUid = await _ensureFirebaseAuthForKakao(kakao);
    final kakaoUid = kakao.userId;

    var draft = UserModel(
      uid: kakaoUid,
      email: kakao.email ?? '',
      displayName: kakao.nickname,
      realName: null,
      kakaoId: kakaoUid,
      profileImageUrl: kakao.profileImageUrl,
      role: defaultRole,
      authProvider: 'kakao',
      fcmToken: null,
      fcmTokens: const [],
      ownedRoomCount: 0,
    );

    try {
      final existing = await _users.getById(kakaoUid);
      draft = UserModel(
        uid: kakaoUid,
        email: kakao.email ?? existing?.email ?? '',
        displayName: kakao.nickname,
        realName: existing?.realName,
        kakaoId: kakaoUid,
        profileImageUrl: kakao.profileImageUrl,
        role: existing?.role ?? defaultRole,
        authProvider: 'kakao',
        fcmToken: existing?.fcmToken,
        fcmTokens: existing?.fcmTokens ?? const [],
        ownedRoomCount: existing?.ownedRoomCount ?? 0,
      );

      final saved = await _users.upsert(draft, mergeKakao: true);
      debugPrint(
        '[AuthIntegration] Firestore users upsert OK path=${saved.docPath} '
        'kakaoUid=$kakaoUid hasRealName=${saved.hasRealName}',
      );
      try {
        await FcmService.instance.bindUser(saved.uid);
      } catch (e, st) {
        debugPrint('[AuthIntegration] FCM bind skip: $e');
        debugPrint('$st');
      }

      return AuthSessionResult(
        kakao: kakao,
        user: saved,
        firebaseUid: firebaseUid,
        mockUser: MockUser(
          uid: saved.uid,
          displayName: saved.preferredDisplayName,
          email: saved.email.isNotEmpty
              ? saved.email
              : 'kakao_$kakaoUid@kakao.local',
          personaLabel: '카카오',
          realName: saved.realName,
        ),
        usedMockAuth: false,
      );
    } on FirebaseException catch (e, st) {
      // 규칙/권한 문제여도 카카오 로컬 세션은 유지 (앱 진입 가능)
      debugPrint(
        '[AuthIntegration] Firestore upsert soft-fail code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      return AuthSessionResult(
        kakao: kakao,
        user: draft,
        firebaseUid: firebaseUid,
        mockUser: MockUser(
          uid: draft.uid,
          displayName: draft.preferredDisplayName,
          email: draft.email.isNotEmpty
              ? draft.email
              : 'kakao_$kakaoUid@kakao.local',
          personaLabel: '카카오',
          realName: draft.realName,
        ),
        usedMockAuth: false,
      );
    } catch (e, st) {
      debugPrint('[AuthIntegration] upsert soft-fail: $e');
      debugPrint('$st');
      return AuthSessionResult(
        kakao: kakao,
        user: draft,
        firebaseUid: firebaseUid,
        mockUser: MockUser(
          uid: draft.uid,
          displayName: draft.preferredDisplayName,
          email: draft.email.isNotEmpty
              ? draft.email
              : 'kakao_$kakaoUid@kakao.local',
          personaLabel: '카카오',
          realName: draft.realName,
        ),
        usedMockAuth: false,
      );
    }
  }

  /// 1) API 커스텀 토큰  2) 익명(가능 시)  3) 카카오 UID 로컬 폴백
  Future<String> _ensureFirebaseAuthForKakao(KakaoAuthResult kakao) async {
    // 이미 동일 UID 로 로그인돼 있으면 재사용
    final current = _auth.currentUser;
    if (current != null && current.uid == kakao.userId) {
      debugPrint(
        '[AuthIntegration] FirebaseAuth reuse uid=${current.uid}',
      );
      return current.uid;
    }

    // 1) 서버 커스텀 토큰 (Anonymous 비활성 환경 대응)
    try {
      final exchanged = await ApiService.instance.exchangeKakaoForFirebaseToken(
        kakaoAccessToken: kakao.accessToken,
        kakaoUserId: kakao.userId,
      );
      if (exchanged.ok &&
          exchanged.customToken != null &&
          exchanged.customToken!.isNotEmpty) {
        final cred = await _auth.signInWithCustomToken(exchanged.customToken!);
        final user = cred.user;
        if (user != null) {
          debugPrint(
            '[AuthIntegration] FirebaseAuth customToken OK '
            'uid=${user.uid}',
          );
          return user.uid;
        }
      } else {
        debugPrint(
          '[AuthIntegration] customToken API skip: ${exchanged.message}',
        );
      }
    } catch (e, st) {
      debugPrint('[AuthIntegration] customToken path FAIL: $e');
      debugPrint('$st');
    }

    // 2) 익명 (콘솔에서 켠 경우만)
    try {
      final anon = await _ensureFirebaseAuthUser();
      debugPrint(
        '[AuthIntegration] FirebaseAuth anonymous OK uid=${anon.uid}',
      );
      return anon.uid;
    } on fb_auth.FirebaseAuthException catch (e, st) {
      debugPrint(
        '[AuthIntegration] anonymous skip code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
    } catch (e, st) {
      debugPrint('[AuthIntegration] anonymous skip: $e');
      debugPrint('$st');
    }

    // 3) 로컬 폴백 — Firestore 규칙이 auth 필수가 아니면 앱 진입 가능
    debugPrint(
      '[AuthIntegration] FirebaseAuth local fallback uid=${kakao.userId}',
    );
    return kakao.userId;
  }

  Future<fb_auth.User> _ensureFirebaseAuthUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;

    debugPrint('[AuthIntegration] signing in anonymously for Firestore rules');
    final cred = await _auth.signInAnonymously();
    final user = cred.user;
    if (user == null) {
      throw StateError('Firebase 익명 로그인에 실패했습니다.');
    }
    return user;
  }
}

class AuthSessionResult {
  const AuthSessionResult({
    required this.kakao,
    required this.user,
    required this.firebaseUid,
    required this.mockUser,
    this.usedMockAuth = false,
  });

  final KakaoAuthResult kakao;
  final UserModel user;
  final String firebaseUid;
  final MockUser mockUser;
  final bool usedMockAuth;

  /// 실명 미등록 → ProfileSetupScreen 분기
  bool get needsProfileSetup => !user.hasRealName;
}
