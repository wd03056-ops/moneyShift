/// 방(매장) 내 직책 / users 전역 역할
enum MemberRole {
  owner,
  manager,
  staff,
  parttime,
  /// 신규 스키마 알바생 (users.role / store_members)
  worker;

  String get firestoreValue => name;

  /// UI 표시용 한글 라벨
  String get labelKo {
    switch (this) {
      case MemberRole.owner:
        return '사장';
      case MemberRole.manager:
        return '매니저';
      case MemberRole.staff:
        return '직원';
      case MemberRole.parttime:
        return '알바';
      case MemberRole.worker:
        return '알바생';
    }
  }

  /// 초대 시 선택 가능한 직책 (사장은 방 생성 시 자동 지정)
  static List<MemberRole> get invitableRoles => [
        MemberRole.manager,
        MemberRole.staff,
        MemberRole.parttime,
      ];

  static MemberRole fromFirestore(String value) {
    return MemberRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemberRole.worker,
    );
  }

  /// 근무표 배정·승인 등 — 당분간 사장만 (매니저는 직원 UX)
  bool get canManageSchedules => this == MemberRole.owner;

  /// 초대 — 당분간 사장만
  bool get canInviteMembers => this == MemberRole.owner;

  bool get canCreateRooms => this == MemberRole.owner;

  bool get isWorkerRole =>
      this == MemberRole.worker ||
      this == MemberRole.staff ||
      this == MemberRole.parttime ||
      this == MemberRole.manager;

  /// 사장 전용 관리자 대시보드 (매니저는 당분간 직원 화면)
  bool get isAdminDashboard => this == MemberRole.owner;

  /// 직원/알바/매니저 대시보드 분기
  bool get isStaffDashboard => !isAdminDashboard;

  /// 방 목록 배지: 사장 vs 알바/직원(초대)
  String get roomListBadgeLabel {
    switch (this) {
      case MemberRole.owner:
        return '사장';
      case MemberRole.manager:
        return '매니저';
      case MemberRole.staff:
      case MemberRole.parttime:
      case MemberRole.worker:
        return '알바/직원';
    }
  }
}
