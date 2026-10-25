import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../../../core/config/dev_auth_config.dart';
import '../../../core/config/kakao_config.dart';
import '../../../core/storage/secure_session_storage.dart';
import '../../../data/services/api_service.dart';
import '../../../mock/mock_user.dart';
import '../../../models/enums/member_role.dart';
import '../../../models/user_model.dart';
import '../../../services/fcm_service.dart';
import '../../../services/user_firestore_service.dart';
import 'auth_flow_exception.dart';
import 'kakao_auth_service.dart';
import 'mock_auth_service.dart';
import 'mock_firestore_seed_service.dart';

/// 인증 통합 진입점
///
/// - [DevAuthConfig.isMockAuthEnabled] == true → Mock UID (카카오 SDK 미호출)
/// - false → 실제 [KakaoAuthService] → Custom Token → Firestore users upsert
class AuthIntegrationService {
  AuthIntegrationService({
    KakaoAuthService? kakaoAuth,
    MockAuthService? mockAuth,
    UserFirestoreService? userFirestore,
    MockFirestoreSeedService? seedService,
    fb_auth.FirebaseAuth? firebaseAuth,
    ApiService? api,
  })  : _kakao = kakaoAuth ?? KakaoAuthService.instance,
        _mock = mockAuth ?? MockAuthService.instance,
        _users = userFirestore ?? UserFirestoreService(),
        _seed = seedService ?? MockFirestoreSeedService.instance,
        _auth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
        _api = api ?? ApiService.instance;

  static final AuthIntegrationService instance = AuthIntegrationService();

  final KakaoAuthService _kakao;
  final MockAuthService _mock;
  final UserFirestoreService _users;
  final MockFirestoreSeedService _seed;
  final fb_auth.FirebaseAuth _auth;
  final ApiService _api;

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
  Future<AuthSessionResult> signInWithMock({
    MockAuthPersona persona = MockAuthPersona.owner,
  }) async {
    debugPrint('[AuthIntegration] Mock sign-in start persona=$persona');

    final profile = _mock.profileFor(persona);
    final kakao = _mock.toKakaoResult(profile);
    final mockUser = _mock.toMockUser(profile);
    var userModel = _mock.toUserModel(profile);
    var firebaseUid = profile.uid;

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

  /// 카카오 → Custom Token → Firebase Auth → Firestore users 생성/병합
  Future<AuthSessionResult> signInWithKakao({
    MemberRole defaultRole = MemberRole.parttime,
  }) async {
    debugPrint('[AuthIntegration] Kakao sign-in start');

    if (!KakaoConfig.isConfigured) {
      throw const AuthFlowException(
        '카카오 네이티브 앱 키가 설정되지 않았습니다.',
        code: 'kakao_not_configured',
      );
    }

    final kakao = await _kakao.signIn();
    debugPrint(
      '[AuthIntegration] Kakao OK id=${kakao.userId} '
      'nickname=${kakao.nickname} email=${kakao.email}',
    );

    final firebaseUid = await _signInFirebaseWithCustomToken(kakao);
    final kakaoUid = kakao.userId;

    final draft = UserModel(
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

    late final UserModel saved;
    try {
      saved = await _users.upsertKakaoProfile(draft);
      debugPrint(
        '[AuthIntegration] Firestore users upsert OK path=${saved.docPath} '
        'kakaoUid=$kakaoUid hasRealName=${saved.hasRealName}',
      );
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[AuthIntegration] Firestore upsert FAIL code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      throw AuthFlowException(
        _firestoreUserMessage(e),
        code: 'firestore_${e.code}',
      );
    } catch (e, st) {
      debugPrint('[AuthIntegration] upsert FAIL: $e');
      debugPrint('$st');
      throw const AuthFlowException(
        '사용자 정보를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        code: 'firestore_upsert_failed',
      );
    }

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
  }

  /// 프로필 저장 전 등 — Auth UID 가 [uid] 인지 확인하고 아니면 카카오 토큰으로 재로그인
  Future<void> ensureFirebaseAuthUid(String uid) async {
    final current = _auth.currentUser;
    if (current != null && current.uid == uid) {
      debugPrint('[AuthIntegration] ensureAuth OK uid=$uid');
      return;
    }

    final accessToken =
        await SecureSessionStorage.instance.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFlowException(
        '로그인 세션이 만료되었습니다. 다시 로그인해 주세요.',
        code: 'session_expired',
      );
    }

    debugPrint(
      '[AuthIntegration] ensureAuth re-login '
      'current=${current?.uid} target=$uid',
    );
    await _signInFirebaseWithCustomToken(
      KakaoAuthResult(
        accessToken: accessToken,
        userId: uid,
        nickname: current?.displayName ?? '카카오 사용자',
      ),
    );
  }

  /// Vercel Custom Token 교환 + FirebaseAuth.signInWithCustomToken
  Future<String> _signInFirebaseWithCustomToken(KakaoAuthResult kakao) async {
    final current = _auth.currentUser;
    if (current != null && current.uid == kakao.userId) {
      debugPrint('[AuthIntegration] FirebaseAuth reuse uid=${current.uid}');
      return current.uid;
    }

    // 다른 UID(익명 등) 세션이 있으면 제거 후 커스텀 토큰 로그인
    if (current != null && current.uid != kakao.userId) {
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint('[AuthIntegration] prior signOut soft-fail: $e');
      }
    }

    final exchanged = await _api.exchangeKakaoForFirebaseToken(
      kakaoAccessToken: kakao.accessToken,
      kakaoUserId: kakao.userId,
    );

    if (!exchanged.ok ||
        exchanged.customToken == null ||
        exchanged.customToken!.isEmpty) {
      debugPrint(
        '[AuthIntegration] customToken API FAIL '
        'status=${exchanged.statusCode} code=${exchanged.errorCode} '
        'msg=${exchanged.message}',
      );
      throw AuthFlowException(
        exchanged.message.isNotEmpty
            ? exchanged.message
            : '로그인 서버와 토큰 교환에 실패했습니다.',
        code: exchanged.errorCode ?? 'custom_token_exchange_failed',
        network: exchanged.network,
      );
    }

    try {
      final cred =
          await _auth.signInWithCustomToken(exchanged.customToken!);
      final user = cred.user;
      if (user == null) {
        throw const AuthFlowException(
          'Firebase 인증에 실패했습니다. (세션 없음)',
          code: 'firebase_user_null',
        );
      }
      if (user.uid != kakao.userId) {
        debugPrint(
          '[AuthIntegration] WARN uid mismatch '
          'firebase=${user.uid} kakao=${kakao.userId}',
        );
      }
      debugPrint(
        '[AuthIntegration] FirebaseAuth customToken OK uid=${user.uid}',
      );
      return user.uid;
    } on fb_auth.FirebaseAuthException catch (e, st) {
      debugPrint(
        '[AuthIntegration] signInWithCustomToken FAIL '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      throw AuthFlowException(
        _firebaseAuthUserMessage(e),
        code: 'firebase_${e.code}',
      );
    }
  }

  static String _firebaseAuthUserMessage(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
        return '인증 토큰이 올바르지 않습니다. 다시 로그인해 주세요.';
      case 'network-request-failed':
        return '네트워크 오류로 Firebase 인증에 실패했습니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Firebase 인증에 실패했습니다. (${e.code})';
    }
  }

  static String _firestoreUserMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return '사용자 정보 저장 권한이 없습니다. 로그인 후 다시 시도해 주세요.';
      case 'unavailable':
      case 'deadline-exceeded':
        return '서버에 일시적으로 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : '사용자 정보 저장에 실패했습니다. (${e.code})';
    }
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
