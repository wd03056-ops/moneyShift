import '../../../models/enums/member_role.dart';

/// 앱 전역 역할 (카카오 users 문서) — 사장 / 알바생
enum AppUserRole {
  owner,
  worker;

  String get firestoreValue => name;

  String get labelKo => this == AppUserRole.owner ? '사장' : '알바생';

  MemberRole toMemberRole() {
    switch (this) {
      case AppUserRole.owner:
        return MemberRole.owner;
      case AppUserRole.worker:
        return MemberRole.worker;
    }
  }

  static AppUserRole fromMemberRole(MemberRole role) {
    if (role == MemberRole.owner || role == MemberRole.manager) {
      return AppUserRole.owner;
    }
    return AppUserRole.worker;
  }

  static AppUserRole fromFirestore(String? value) {
    if (value == 'owner' || value == 'manager') return AppUserRole.owner;
    return AppUserRole.worker;
  }
}
