import '../../../mock/mock_user.dart';
import '../../../models/enums/member_role.dart';
import '../../../models/user_model.dart';
import 'kakao_auth_service.dart';

/// Mock 인증 페르소나 (사장 / 알바)
enum MockAuthPersona {
  owner,
  staff,
}

/// 개발용 Mock UID · 프로필 제공 (카카오 SDK 미호출)
class MockAuthService {
  MockAuthService._();

  static final MockAuthService instance = MockAuthService._();

  static const String ownerUid = 'test_kakao_user_001';
  static const String staffUid = 'test_kakao_user_002';
  static const String demoStoreId = 'test_store_001';
  static const String demoScheduleId = 'test_schedule_001';
  static const String demoAttendanceId = 'test_attendance_001';

  /// 테스트용 프로필 (로컬 세션 + Firestore upsert 공통)
  MockAuthProfile profileFor(MockAuthPersona persona) {
    switch (persona) {
      case MockAuthPersona.owner:
        return const MockAuthProfile(
          uid: ownerUid,
          kakaoId: 'mock_kakao_001',
          displayName: '테스트 사용자',
          email: 'test.owner@mock.local',
          role: MemberRole.owner,
          personaLabel: '사장',
        );
      case MockAuthPersona.staff:
        return const MockAuthProfile(
          uid: staffUid,
          kakaoId: 'mock_kakao_002',
          displayName: '테스트 알바',
          email: 'test.staff@mock.local',
          role: MemberRole.parttime,
          personaLabel: '알바',
        );
    }
  }

  KakaoAuthResult toKakaoResult(MockAuthProfile profile) {
    return KakaoAuthResult(
      accessToken: 'mock_access_token_${profile.uid}',
      refreshToken: 'mock_refresh_token_${profile.uid}',
      userId: profile.kakaoId,
      nickname: profile.displayName,
      email: profile.email,
      profileImageUrl: null,
    );
  }

  UserModel toUserModel(MockAuthProfile profile) {
    return UserModel(
      uid: profile.uid,
      email: profile.email,
      displayName: profile.displayName,
      // Mock 은 온보딩 스킵 — 실명 = 표시명
      realName: profile.displayName,
      kakaoId: profile.kakaoId,
      role: profile.role,
      authProvider: 'mock',
    );
  }

  MockUser toMockUser(MockAuthProfile profile) {
    return MockUser(
      uid: profile.uid,
      displayName: profile.displayName,
      email: profile.email,
      personaLabel: profile.personaLabel,
      realName: profile.displayName,
    );
  }
}

class MockAuthProfile {
  const MockAuthProfile({
    required this.uid,
    required this.kakaoId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.personaLabel,
  });

  final String uid;
  final String kakaoId;
  final String displayName;
  final String email;
  final MemberRole role;
  final String personaLabel;
}
