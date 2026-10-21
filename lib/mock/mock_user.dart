/// 테스트용 목업 유저
class MockUser {
  const MockUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.personaLabel,
    this.realName,
  });

  final String uid;
  final String displayName;
  final String email;

  /// 로그인 화면 등에 쓰는 역할 설명 (사장 / 직원)
  final String personaLabel;

  /// Firestore `users.realName` — 없으면 온보딩 필요
  final String? realName;

  bool get hasRealName {
    final name = realName?.trim() ?? '';
    return name.length >= 2;
  }

  String get preferredDisplayName {
    if (hasRealName) return realName!.trim();
    return displayName;
  }

  /// 사장 — 매장 생성·직원 관리
  static const owner = MockUser(
    uid: 'mock_owner_1',
    displayName: '김사장',
    email: 'owner@mock.local',
    personaLabel: '사장',
    realName: '김사장',
  );

  /// 초대받은 직원 — 출퇴근·근태 (로그인 테스트 계정)
  static const staff = MockUser(
    uid: 'mock_staff_1',
    displayName: '박직원',
    email: 'staff@mock.local',
    personaLabel: '직원',
    realName: '박직원',
  );

  /// 데모 매장 직원 목록 (5명, [staff] 포함)
  static const List<MockUser> demoStaffRoster = [
    staff,
    MockUser(
      uid: 'mock_staff_2',
      displayName: '이알바',
      email: 'staff2@mock.local',
      personaLabel: '직원',
      realName: '이알바',
    ),
    MockUser(
      uid: 'mock_staff_3',
      displayName: '최매니저',
      email: 'staff3@mock.local',
      personaLabel: '직원',
      realName: '최매니저',
    ),
    MockUser(
      uid: 'mock_staff_4',
      displayName: '정직원',
      email: 'staff4@mock.local',
      personaLabel: '직원',
      realName: '정직원',
    ),
    MockUser(
      uid: 'mock_staff_5',
      displayName: '한아르바',
      email: 'staff5@mock.local',
      personaLabel: '직원',
      realName: '한아르바',
    ),
  ];

  /// 초대 화면 데모용 (로그인하지 않는 다른 매장 사장)
  static const otherOwner = MockUser(
    uid: 'mock_other_owner',
    displayName: '다른사장님',
    email: 'other@mock.local',
    personaLabel: '사장',
    realName: '다른사장님',
  );

  /// 하위 호환 — [owner]와 동일
  static const me = owner;

  /// 로그인·내정보에서 전환 가능한 목업 계정 (사장 + 데모 직원)
  static List<MockUser> get switchableAccounts => [
        owner,
        ...demoStaffRoster,
      ];

  bool get isOwnerPersona => uid == owner.uid;
  bool get isStaffPersona => demoStaffRoster.any((u) => u.uid == uid);

  MockUser copyWith({
    String? displayName,
    String? email,
    String? personaLabel,
    String? realName,
  }) {
    return MockUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      personaLabel: personaLabel ?? this.personaLabel,
      realName: realName ?? this.realName,
    );
  }
}
