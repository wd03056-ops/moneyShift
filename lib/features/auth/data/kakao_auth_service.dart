import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/kakao_config.dart';
import '../../../mock/mock_user.dart';
import 'auth_flow_exception.dart';

/// 카카오 로그인 성공 결과 (토큰 + 사용자 기본 정보)
class KakaoAuthResult {
  const KakaoAuthResult({
    required this.accessToken,
    required this.userId,
    required this.nickname,
    this.email,
    this.profileImageUrl,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final String userId;
  final String nickname;
  final String? email;
  final String? profileImageUrl;

  /// 목업 세션용 유저로 변환 — uid = 카카오 회원번호 문자열
  MockUser toMockUser() {
    return MockUser(
      uid: userId,
      displayName: nickname,
      email: email ?? 'kakao_$userId@kakao.local',
      personaLabel: '카카오',
    );
  }
}

/// 카카오 로그인·사용자 정보 조회 유틸리티
class KakaoAuthService {
  KakaoAuthService._();

  static final KakaoAuthService instance = KakaoAuthService._();

  /// 디버그 키 해시(Android) 또는 플랫폼 origin 출력 — 콘솔 등록용
  static Future<void> printDebugKeyHash() async {
    if (!kDebugMode) return;
    try {
      final origin = KakaoSdk.platformInfo.origin;
      final package = KakaoSdk.platformInfo.packageName;
      debugPrint('========== Kakao Debug Key Hash ==========');
      debugPrint('origin (Key Hash): $origin');
      if (package != null) {
        debugPrint('packageName: $package');
      }
      debugPrint('iosBundleId: ${KakaoConfig.iosBundleId}');
      debugPrint('redirectUri: ${KakaoConfig.redirectUri}');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('[Kakao] key hash 출력 실패: $e');
    }
  }

  /// 카카오톡 설치 여부에 따라 Talk / Account 로그인 후 사용자 정보 조회
  Future<KakaoAuthResult> signIn() async {
    if (!KakaoConfig.isConfigured) {
      throw const AuthFlowException(
        '카카오 네이티브 앱 키가 설정되지 않았습니다.',
        code: 'kakao_not_configured',
      );
    }

    try {
      final token = await _login();
      final user = await UserApi.instance.me();
      final account = user.kakaoAccount;
      final profile = account?.profile;

      final nickname = profile?.nickname?.trim();
      final resolvedName = (nickname != null && nickname.isNotEmpty)
          ? nickname
          : '카카오 사용자';

      return KakaoAuthResult(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        userId: '${user.id}',
        nickname: resolvedName,
        email: account?.email,
        profileImageUrl: profile?.profileImageUrl,
      );
    } on AuthFlowException {
      rethrow;
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) {
        throw const AuthFlowException(
          '카카오 로그인이 취소되었습니다.',
          code: 'kakao_cancelled',
          userCancelled: true,
        );
      }
      throw AuthFlowException(
        e.errorDescription ?? '카카오 인증에 실패했습니다.',
        code: 'kakao_auth_${e.error}',
      );
    } on KakaoClientException catch (e) {
      if (e.reason == ClientErrorCause.cancelled) {
        throw const AuthFlowException(
          '카카오 로그인이 취소되었습니다.',
          code: 'kakao_cancelled',
          userCancelled: true,
        );
      }
      final lower = e.msg.toLowerCase();
      final isNetwork = lower.contains('network') ||
          lower.contains('socket') ||
          lower.contains('timeout') ||
          lower.contains('연결');
      throw AuthFlowException(
        e.msg.isNotEmpty ? e.msg : '카카오 로그인에 실패했습니다.',
        code: isNetwork ? 'kakao_network' : 'kakao_client_${e.reason.name}',
        network: isNetwork,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'cancelled') {
        throw const AuthFlowException(
          '카카오 로그인이 취소되었습니다.',
          code: 'kakao_cancelled',
          userCancelled: true,
        );
      }
      throw AuthFlowException(
        e.message ?? '카카오 로그인에 실패했습니다.',
        code: 'kakao_platform_${e.code}',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('CANCELED') || msg.contains('cancelled')) {
        throw const AuthFlowException(
          '카카오 로그인이 취소되었습니다.',
          code: 'kakao_cancelled',
          userCancelled: true,
        );
      }
      throw AuthFlowException(
        '카카오 로그인 중 오류가 발생했습니다.',
        code: 'kakao_unknown',
      );
    }
  }

  Future<OAuthToken> _login() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (error) {
        // 사용자가 카카오톡 동의/권한 화면에서 취소한 경우 → 계정 로그인으로 이어가지 않음
        if (_isUserCanceled(error)) rethrow;
        // 톡 미지원·실패 시 계정(웹) 로그인
        return await UserApi.instance.loginWithKakaoAccount();
      }
    }
    return await UserApi.instance.loginWithKakaoAccount();
  }

  /// 로그아웃 토큰이 있으면 사용자 정보만 조회
  Future<KakaoAuthResult?> restoreSession() async {
    if (!KakaoConfig.isConfigured) return null;
    try {
      if (!await AuthApi.instance.hasToken()) return null;
      await UserApi.instance.accessTokenInfo();
      final user = await UserApi.instance.me();
      final token = await TokenManagerProvider.instance.manager.getToken();
      if (token == null) return null;

      final account = user.kakaoAccount;
      final profile = account?.profile;
      final nickname = profile?.nickname?.trim();

      return KakaoAuthResult(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        userId: '${user.id}',
        nickname: (nickname != null && nickname.isNotEmpty)
            ? nickname
            : '카카오 사용자',
        email: account?.email,
        profileImageUrl: profile?.profileImageUrl,
      );
    } catch (_) {
      await TokenManagerProvider.instance.manager.clear();
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {
      await TokenManagerProvider.instance.manager.clear();
    }
  }

  Future<void> unlink() async {
    try {
      await UserApi.instance.unlink();
    } catch (_) {
      await TokenManagerProvider.instance.manager.clear();
    }
  }

  static bool _isUserCanceled(Object error) {
    if (error is PlatformException && error.code == 'CANCELED') {
      return true;
    }
    if (error is KakaoAuthException) {
      return error.error == AuthErrorCause.accessDenied;
    }
    if (error is KakaoClientException) {
      return error.reason == ClientErrorCause.cancelled;
    }
    if (error is AuthFlowException) {
      return error.userCancelled;
    }
    return false;
  }
}
