import '../core/config/dev_auth_config.dart';
import '../mock/mock_store.dart';
import '../models/models.dart';
import 'room_repository.dart';

/// 초대 코드 · 커스텀 직책 — Mock / Firestore 단일 진입점
///
/// - [DevAuthConfig.isMockAuthEnabled] → [MockStore]
/// - 그 외 → [RoomRepository] (Firestore)
class RoomInviteService {
  RoomInviteService({
    RoomRepository? repository,
    MockStore? mock,
  })  : _repo = repository ?? RoomRepository(),
        _mock = mock ?? MockStore.instance;

  final RoomRepository _repo;
  final MockStore _mock;

  /// 방별 기본 초대 일괄 확보 — 동시 호출 시 동일 Future 공유 (중복 생성 방지)
  final Map<String, Future<Map<MemberRole, RoomInviteModel>>>
      _defaultInvitesInFlight = {};

  /// 방·직책별 ensure — 연타·병렬 탭 시 동일 Future 공유
  final Map<String, Future<RoomInviteModel>> _roleInviteInFlight = {};

  /// 방·직책명별 커스텀 생성 — 연타 시 중복 직책 방지
  final Map<String, Future<RoomCustomRoleModel>> _createCustomInFlight = {};

  bool get _useMock => DevAuthConfig.isMockAuthEnabled;

  Future<RoomInviteModel> ensureInviteForRole({
    required String roomId,
    required MemberRole role,
    Duration validFor = const Duration(days: 365),
  }) {
    final key = '$roomId:${role.name}';
    final existing = _roleInviteInFlight[key];
    if (existing != null) return existing;

    final future = () async {
      try {
        if (_useMock) {
          return _mock.ensureInviteForRole(
            roomId: roomId,
            role: role,
            validFor: validFor,
          );
        }
        return await _repo.ensureInviteForRole(
          roomId: roomId,
          role: role,
          validFor: validFor,
        );
      } finally {
        _roleInviteInFlight.remove(key);
      }
    }();
    _roleInviteInFlight[key] = future;
    return future;
  }

  Future<Map<MemberRole, RoomInviteModel>> ensureDefaultRoleInvites({
    required String roomId,
    Duration validFor = const Duration(days: 365),
  }) {
    final existing = _defaultInvitesInFlight[roomId];
    if (existing != null) return existing;

    final future = () async {
      try {
        if (_useMock) {
          return _mock.ensureDefaultRoleInvites(
            roomId: roomId,
            validFor: validFor,
          );
        }
        return await _repo.ensureDefaultRoleInvites(
          roomId: roomId,
          validFor: validFor,
        );
      } finally {
        _defaultInvitesInFlight.remove(roomId);
      }
    }();
    _defaultInvitesInFlight[roomId] = future;
    return future;
  }

  Future<RoomCustomRoleModel> createCustomRoleWithInvite({
    required String roomId,
    required String roleName,
    MemberRole baseRole = MemberRole.staff,
    Duration validFor = const Duration(days: 365),
  }) {
    final nameKey = roleName.trim().toLowerCase();
    final key = '$roomId:$nameKey';
    final existing = _createCustomInFlight[key];
    if (existing != null) return existing;

    final future = () async {
      try {
        if (_useMock) {
          return _mock.createCustomRoleWithInvite(
            roomId: roomId,
            roleName: roleName,
            baseRole: baseRole,
            validFor: validFor,
          );
        }
        return await _repo.createCustomRoleWithInvite(
          roomId: roomId,
          roleName: roleName,
          baseRole: baseRole,
          validFor: validFor,
        );
      } finally {
        _createCustomInFlight.remove(key);
      }
    }();
    _createCustomInFlight[key] = future;
    return future;
  }

  Future<List<RoomCustomRoleModel>> listCustomRoles(String roomId) async {
    if (_useMock) {
      return _mock.customRolesForRoom(roomId);
    }
    return _repo.listCustomRoles(roomId);
  }

  /// 커스텀 직책 삭제 + 초대 코드 무효화 + 기존 멤버 표시명 정리
  Future<void> deleteCustomRole({
    required String roomId,
    required String roleId,
  }) async {
    if (_useMock) {
      _mock.deleteCustomRole(roomId: roomId, roleId: roleId);
      return;
    }
    await _repo.deleteCustomRole(roomId: roomId, roleId: roleId);
  }

  /// [deleteCustomRole] 별칭
  Future<void> deactivateCustomRole({
    required String roomId,
    required String roleId,
  }) =>
      deleteCustomRole(roomId: roomId, roleId: roleId);

  Future<RoomInviteModel?> getInvite(String inviteId) async {
    if (_useMock) {
      return _mock.invites[inviteId];
    }
    return _repo.getInvite(inviteId);
  }

  /// 초대 코드 1칸 가입 — 코드에 묶인 기본/커스텀 직책 자동 적용
  Future<RoomMemberModel> joinWithInviteCode(String rawCode) async {
    if (_useMock) {
      return _mock.joinWithInviteCode(rawCode);
    }
    return _repo.joinRoomWithInviteCode(rawCode);
  }
}
