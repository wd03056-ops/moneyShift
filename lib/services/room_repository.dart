import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import '../core/exceptions/room_exceptions.dart';
import '../core/firebase/firestore_query_limits.dart';
import '../models/models.dart';

/// 방(매장) · 직책 지정 초대 · 멤버 가입 Firestore CRUD
class RoomRepository {
  RoomRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection(FirestorePaths.rooms);

  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection(FirestorePaths.roomMembers);

  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _db.collection(FirestorePaths.inviteCodes);

  CollectionReference<Map<String, dynamic>> _customRoles(String roomId) =>
      _db.collection(FirestorePaths.roomCustomRoles(roomId));

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(FirestorePaths.roomInvites);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestorePaths.users);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedException();
    return user.uid;
  }

  String get _displayName {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedException();
    return user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? '사용자');
  }

  // ---------------------------------------------------------------------------
  // 방 생성 (무료 최대 2개)
  // ---------------------------------------------------------------------------

  /// 매장 이름 + GPS 위치로 방 생성.
  /// 한도 초과 시 [RoomLimitExceededException] — UI에서 유료 유도로 분기.
  Future<RoomModel> createRoom({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    double geofenceRadiusMeters =
        AppConstants.attendanceGeofenceRadiusMeters,
  }) async {
    final uid = _uid;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('매장 이름을 입력해주세요.');
    }

    final roomRef = _rooms.doc();
    final memberRef = _members.doc(
      FirestorePaths.roomMemberDocId(roomRef.id, uid),
    );
    final userRef = _users.doc(uid);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final ownedCount = userSnap.exists
          ? (userSnap.data()?['ownedRoomCount'] as int? ?? 0)
          : 0;

      if (ownedCount >= AppConstants.freeMaxOwnedRooms) {
        throw RoomLimitExceededException(
          currentCount: ownedCount,
          freeLimit: AppConstants.freeMaxOwnedRooms,
        );
      }

      final room = RoomModel(
        id: roomRef.id,
        name: trimmed,
        ownerId: uid,
        location: GeoLocation(
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
        geofenceRadiusMeters: geofenceRadiusMeters,
        memberCount: 1,
      );

      tx.set(roomRef, room.toFirestore(forCreate: true));

      final ownerMember = RoomMemberModel(
        roomId: roomRef.id,
        userId: uid,
        role: MemberRole.owner,
        displayName: _displayName,
      );
      tx.set(memberRef, ownerMember.toFirestore(forCreate: true));

      if (userSnap.exists) {
        tx.update(userRef, {
          'ownedRoomCount': ownedCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final authUser = _auth.currentUser!;
        tx.set(userRef, {
          'uid': uid,
          'email': authUser.email ?? '',
          'displayName': _displayName,
          'fcmTokens': <String>[],
          'ownedRoomCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    final created = await roomRef.get();
    return RoomModel.fromFirestore(created);
  }

  /// 유료 한도 해제 후 호출할 확장 포인트 (결제 연동 시 사용)
  Future<RoomModel> createRoomWithPremium({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    // TODO: 결제 검증 후 한도 우회 생성
    throw UnimplementedError('유료 플랜 방 생성은 결제 연동 후 구현됩니다.');
  }

  // ---------------------------------------------------------------------------
  // 직책 지정 초대 생성
  // ---------------------------------------------------------------------------

  /// 직책([role])을 먼저 선택한 뒤 초대 코드/링크를 생성합니다.
  ///
  /// - 기본 직책: 문서 ID = `{roomId}_default_{role}` (방·직책당 단건)
  /// - 커스텀: 랜덤 문서 ID
  /// - `invite_codes/{code}` 트랜잭션으로 전역 유일성 보장 + 충돌 시 재시도
  Future<RoomInviteModel> createInvite({
    required String roomId,
    required MemberRole role,
    int? maxUses,
    Duration? validFor,
    String? customRoleName,
    String? customRoleId,
  }) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    final isDefaultRoleInvite = customRoleId == null;
    final inviteRef = isDefaultRoleInvite
        ? _invites.doc(
            FirestorePaths.defaultRoleInviteDocId(
              roomId,
              role.firestoreValue,
            ),
          )
        : _invites.doc();

    for (var attempt = 0; attempt < 16; attempt++) {
      // 기본 초대가 이미 사용 가능하면 재생성하지 않음 (중복 코드·문서 방지)
      if (isDefaultRoleInvite) {
        final existingSnap = await inviteRef.get();
        if (existingSnap.exists) {
          final existing = RoomInviteModel.fromFirestore(existingSnap);
          if (existing.canBeUsed) return existing;
        }
      }

      final code = await _generateUniqueInviteCode();
      final invite = RoomInviteModel(
        id: inviteRef.id,
        roomId: roomId,
        code: code,
        role: role,
        createdBy: uid,
        customRoleName: customRoleName,
        customRoleId: customRoleId,
        maxUses: maxUses,
        expiresAt: validFor != null ? DateTime.now().add(validFor) : null,
      );

      try {
        RoomInviteModel? committed;
        await _db.runTransaction((tx) async {
          // 트랜잭션 내 재확인 — 동시 ensure 레이스 차단
          if (isDefaultRoleInvite) {
            final existingSnap = await tx.get(inviteRef);
            if (existingSnap.exists) {
              final existing = RoomInviteModel.fromFirestore(existingSnap);
              if (existing.canBeUsed) {
                committed = existing;
                return;
              }
            }
          }

          final codeRef = _inviteCodes.doc(code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            throw StateError('invite_code_collision');
          }
          final codePayload = <String, dynamic>{
            'code': code,
            'roomId': roomId,
            'inviteId': inviteRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          };
          if (customRoleId != null) {
            codePayload['customRoleId'] = customRoleId;
          }
          tx.set(codeRef, codePayload);
          tx.set(inviteRef, invite.toFirestore(forCreate: true));
          committed = invite;
        });
        final result = committed;
        if (result != null) return result;
      } on StateError catch (e) {
        if (e.message == 'invite_code_collision') continue;
        rethrow;
      }
    }

    throw StateError('초대 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }

  /// 커스텀 직책 등록 + 전역 유일 초대 코드 발급
  ///
  /// `invite_codes` · `room_invites` · `custom_roles`(+ 직책명 락) 를
  /// 한 트랜잭션에 기록해 부분 실패·코드/이름 중복을 막습니다.
  Future<RoomCustomRoleModel> createCustomRoleWithInvite({
    required String roomId,
    required String roleName,
    MemberRole baseRole = MemberRole.staff,
    Duration validFor = const Duration(days: 365),
  }) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    final name = roleName.trim();
    if (name.length < 2) {
      throw ArgumentError('직책명은 2자 이상이어야 합니다.');
    }
    if (name.length > 20) {
      throw ArgumentError('직책명은 20자 이하여야 합니다.');
    }
    if (!MemberRole.invitableRoles.contains(baseRole)) {
      throw ArgumentError('권한 기준 직책이 올바르지 않습니다.');
    }

    final nameLower = name.toLowerCase();
    final nameLockRef = _customRoles(roomId).doc(
      FirestorePaths.customRoleNameLockDocId(nameLower),
    );

    // 방 내 직책명 중복 (사전 검사 + 트랜잭션 락으로 이중 방어)
    final existingNames = await _customRoles(roomId)
        .where('isActive', isEqualTo: true)
        .limit(FirestoreQueryLimits.list)
        .get();
    for (final doc in existingNames.docs) {
      final n = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
      if (n == nameLower) {
        throw StateError('이미 같은 이름의 직책이 있습니다.');
      }
    }
    final lockPre = await nameLockRef.get();
    if (lockPre.exists) {
      throw StateError('이미 같은 이름의 직책이 있습니다.');
    }

    final roleRef = _customRoles(roomId).doc();
    final inviteRef = _invites.doc();

    // 전역 유일 코드 확보 후 트랜잭션으로 원자 기록
    for (var attempt = 0; attempt < 16; attempt++) {
      final code = await _generateUniqueInviteCode();
      final invite = RoomInviteModel(
        id: inviteRef.id,
        roomId: roomId,
        code: code,
        role: baseRole,
        createdBy: uid,
        customRoleName: name,
        customRoleId: roleRef.id,
        expiresAt: DateTime.now().add(validFor),
      );
      final custom = RoomCustomRoleModel(
        id: roleRef.id,
        roomId: roomId,
        name: name,
        baseRole: baseRole,
        inviteCode: code,
        inviteId: inviteRef.id,
        createdBy: uid,
      );

      try {
        await _db.runTransaction((tx) async {
          final lockSnap = await tx.get(nameLockRef);
          if (lockSnap.exists) {
            throw StateError('이미 같은 이름의 직책이 있습니다.');
          }

          final codeRef = _inviteCodes.doc(code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            throw StateError('invite_code_collision');
          }
          tx.set(codeRef, {
            'code': code,
            'roomId': roomId,
            'inviteId': inviteRef.id,
            'customRoleId': roleRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(inviteRef, invite.toFirestore(forCreate: true));
          tx.set(roleRef, custom.toFirestore(forCreate: true));
          // isActive 없음 → 활성 직책 목록 쿼리에서 제외
          tx.set(nameLockRef, {
            'roleId': roleRef.id,
            'name': name,
            'isNameLock': true,
          });
        });
        return custom.copyWith(createdAt: DateTime.now());
      } on StateError catch (e) {
        if (e.message == 'invite_code_collision') continue;
        rethrow;
      }
    }

    throw StateError('초대 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }

  Future<RoomInviteModel?> getInvite(String inviteId) async {
    final snap = await _invites.doc(inviteId).get();
    if (!snap.exists) return null;
    return RoomInviteModel.fromFirestore(snap);
  }

  Future<List<RoomCustomRoleModel>> listCustomRoles(String roomId) async {
    await _ensureCanInvite(roomId, _uid);
    final snap = await _customRoles(roomId)
        .where('isActive', isEqualTo: true)
        .limit(FirestoreQueryLimits.list)
        .get();
    final list = snap.docs
        .where((d) => d.data()['isNameLock'] != true)
        .map(RoomCustomRoleModel.fromFirestore)
        .toList();
    list.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return list;
  }

  /// 커스텀 직책 삭제
  ///
  /// - `custom_roles` 문서 삭제
  /// - 연결된 `room_invites` 즉시 무효화 (`isActive: false`)
  /// - 해당 직책 부여 멤버는 [role](권한) 유지 + `customRoleName`/`customRoleId` 제거
  Future<void> deleteCustomRole({
    required String roomId,
    required String roleId,
  }) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    final roleRef = _customRoles(roomId).doc(roleId);
    final snap = await roleRef.get();
    if (!snap.exists) return;
    final role = RoomCustomRoleModel.fromFirestore(snap);

    final membersSnap = await _members
        .where('roomId', isEqualTo: roomId)
        .where('isActive', isEqualTo: true)
        .limit(FirestoreQueryLimits.batchPage)
        .get();

    final roleName = role.name.trim();
    final affected = membersSnap.docs.where((doc) {
      final data = doc.data();
      final id = data['customRoleId'] as String?;
      if (id != null && id == roleId) return true;
      final name = (data['customRoleName'] as String?)?.trim();
      return name != null &&
          name.isNotEmpty &&
          name.toLowerCase() == roleName.toLowerCase();
    }).toList();

    // Firestore batch 한도(500) 여유 — 직책/초대 + 멤버
    const maxOps = 450;
    var batch = _db.batch();
    var opCount = 0;

    Future<void> commitIfNeeded({required bool force}) async {
      if (opCount == 0) return;
      if (!force && opCount < maxOps) return;
      await batch.commit();
      batch = _db.batch();
      opCount = 0;
    }

    batch.delete(roleRef);
    opCount++;

    final nameLockRef = _customRoles(roomId).doc(
      FirestorePaths.customRoleNameLockDocId(roleName.toLowerCase()),
    );
    batch.delete(nameLockRef);
    opCount++;

    final inviteRef = _invites.doc(role.inviteId);
    final inviteSnap = await inviteRef.get();
    if (inviteSnap.exists) {
      batch.update(inviteRef, {'isActive': false});
      opCount++;
    }

    for (final doc in affected) {
      await commitIfNeeded(force: false);
      // 권한(role)은 baseRole 그대로 — 표시용 커스텀 필드만 제거
      batch.update(doc.reference, {
        'customRoleName': FieldValue.delete(),
        'customRoleId': FieldValue.delete(),
      });
      opCount++;
    }
    await commitIfNeeded(force: true);
  }

  /// [deleteCustomRole] 별칭 (기존 호출 호환)
  Future<void> deactivateCustomRole({
    required String roomId,
    required String roleId,
  }) =>
      deleteCustomRole(roomId: roomId, roleId: roleId);

  Future<void> revokeInvite(String inviteId) async {
    final uid = _uid;
    final snap = await _invites.doc(inviteId).get();
    if (!snap.exists) {
      throw const InviteInvalidException('초대를 찾을 수 없습니다.');
    }
    final invite = RoomInviteModel.fromFirestore(snap);
    await _ensureCanInvite(invite.roomId, uid);
    await snap.reference.update({'isActive': false});
  }

  Future<List<RoomInviteModel>> listActiveInvites(String roomId) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    final snap = await _invites
        .where('roomId', isEqualTo: roomId)
        .where('isActive', isEqualTo: true)
        .limit(FirestoreQueryLimits.list)
        .get();

    return snap.docs.map(RoomInviteModel.fromFirestore).toList();
  }

  /// 기본 직책(커스텀 제외) 활성 초대 1건
  Future<RoomInviteModel?> activeInviteForRole({
    required String roomId,
    required MemberRole role,
  }) async {
    final list = await listActiveInvites(roomId);
    for (final invite in list) {
      if (invite.role == role &&
          invite.customRoleId == null &&
          invite.canBeUsed) {
        return invite;
      }
    }
    return null;
  }

  /// 기본 직책 초대가 없으면 생성 (전역 유일 코드 · 문서 ID 단건)
  Future<RoomInviteModel> ensureInviteForRole({
    required String roomId,
    required MemberRole role,
    Duration validFor = const Duration(days: 365),
  }) async {
    if (!MemberRole.invitableRoles.contains(role)) {
      throw ArgumentError('초대 불가 직책입니다.');
    }

    // 1) 결정적 문서 ID로 단건 조회 (중복 생성 방지의 1차 방어)
    final docId = FirestorePaths.defaultRoleInviteDocId(
      roomId,
      role.firestoreValue,
    );
    final byId = await _invites.doc(docId).get();
    if (byId.exists) {
      final invite = RoomInviteModel.fromFirestore(byId);
      if (invite.canBeUsed) return invite;
    }

    // 2) 레거시(랜덤 ID) 활성 초대가 있으면 재사용
    final legacy = await activeInviteForRole(roomId: roomId, role: role);
    if (legacy != null) return legacy;

    return createInvite(
      roomId: roomId,
      role: role,
      validFor: validFor,
    );
  }

  /// 매니저·직원·알바 기본 초대 코드 일괄 확보
  Future<Map<MemberRole, RoomInviteModel>> ensureDefaultRoleInvites({
    required String roomId,
    Duration validFor = const Duration(days: 365),
  }) async {
    final out = <MemberRole, RoomInviteModel>{};
    for (final role in MemberRole.invitableRoles) {
      out[role] = await ensureInviteForRole(
        roomId: roomId,
        role: role,
        validFor: validFor,
      );
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // 초대 코드로 방 참여 (직책 자동 적용)
  // ---------------------------------------------------------------------------

  /// 초대 코드 1개로 가입 — 코드에 묶인 직책(기본/커스텀)으로 멤버 등록
  ///
  /// 1) `invite_codes/{code}` 로 전역 조회 → 2) `room_invites` 의 role /
  /// customRoleName 적용 → 3) `room_members` 생성.
  /// Cloud Functions `onRoomMemberCreated` 가 사장에게 직원 등록 알림을 보냅니다.
  Future<RoomMemberModel> joinRoomWithInviteCode(String rawCode) async {
    final uid = _uid;
    final code = rawCode.trim();
    if (code.isEmpty) {
      throw const InviteInvalidException('초대 코드를 입력해주세요.');
    }
    if (!_isNumericInviteCode(code)) {
      throw const InviteInvalidException('초대 코드는 숫자만 입력할 수 있습니다.');
    }

    final inviteRef = await _resolveInviteRefByCode(code);
    final inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists) {
      throw const InviteInvalidException('존재하지 않거나 잘못된 초대 코드입니다.');
    }
    final invite = RoomInviteModel.fromFirestore(inviteSnap);
    // 재발급 후 남은 옛 invite_codes 인덱스 차단 (문서 코드와 불일치)
    if (invite.code != code) {
      throw const InviteInvalidException('존재하지 않거나 잘못된 초대 코드입니다.');
    }
    if (!invite.canBeUsed) {
      throw const InviteInvalidException('만료되었거나 사용이 끝난 초대입니다.');
    }

    final roomRef = _rooms.doc(invite.roomId);
    final memberRef = _members.doc(
      FirestorePaths.roomMemberDocId(invite.roomId, uid),
    );

    late RoomMemberModel joined;

    await _db.runTransaction((tx) async {
      final existingMember = await tx.get(memberRef);
      if (existingMember.exists &&
          (existingMember.data()?['isActive'] as bool? ?? false)) {
        throw const AlreadyRoomMemberException();
      }

      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw const RoomNotFoundException();
      }
      final ownerId = roomSnap.data()?['ownerId'] as String?;
      if (ownerId == uid) {
        throw const AlreadyRoomMemberException('내가 만든 방입니다.');
      }

      final liveInviteSnap = await tx.get(inviteRef);
      if (!liveInviteSnap.exists) {
        throw const InviteInvalidException('존재하지 않거나 잘못된 초대 코드입니다.');
      }
      final liveInvite = RoomInviteModel.fromFirestore(liveInviteSnap);
      if (liveInvite.code != code) {
        throw const InviteInvalidException('존재하지 않거나 잘못된 초대 코드입니다.');
      }
      if (!liveInvite.canBeUsed) {
        throw const InviteInvalidException('만료되었거나 사용이 끝난 초대입니다.');
      }

      joined = RoomMemberModel(
        roomId: invite.roomId,
        userId: uid,
        // 기본 직책(매니저/직원/알바) 또는 커스텀 직책의 baseRole + 표시명
        role: liveInvite.role,
        displayName: _displayName,
        customRoleName: liveInvite.customRoleName,
        customRoleId: liveInvite.customRoleId,
        isActive: true,
      );

      // 이 방 멤버 문서만 전체 교체 — 이전 계약/직책 잔존·타 방 데이터 유입 방지
      final payload = <String, dynamic>{
        ...joined.toFirestore(forCreate: true),
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
      };
      if (liveInvite.customRoleName == null) {
        payload['customRoleName'] = FieldValue.delete();
      }
      if (liveInvite.customRoleId == null) {
        payload['customRoleId'] = FieldValue.delete();
      }
      tx.set(memberRef, payload);

      final wasInactive = existingMember.exists &&
          !(existingMember.data()?['isActive'] as bool? ?? false);
      final shouldIncrementCount = !existingMember.exists || wasInactive;
      // increment 로 동시 가입 시 카운트 꼬임 완화 (트랜잭션 내)
      tx.update(roomRef, {
        if (shouldIncrementCount)
          'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final nextUsed = liveInvite.usedCount + 1;
      tx.update(inviteRef, {
        'usedCount': FieldValue.increment(1),
        if (liveInvite.maxUses != null && nextUsed >= liveInvite.maxUses!)
          'isActive': false,
      });
    });

    return joined;
  }

  /// `invite_codes` 우선, 없으면 `room_invites` 쿼리 (레거시 호환)
  Future<DocumentReference<Map<String, dynamic>>> _resolveInviteRefByCode(
    String code,
  ) async {
    final reserved = await _inviteCodes.doc(code).get();
    if (reserved.exists) {
      final inviteId = reserved.data()?['inviteId'] as String?;
      if (inviteId == null || inviteId.isEmpty) {
        throw const InviteInvalidException('존재하지 않거나 잘못된 초대 코드입니다.');
      }
      return _invites.doc(inviteId);
    }

    final inviteQuery = await _invites
        .where('code', isEqualTo: code)
        .limit(2)
        .get();
    if (inviteQuery.docs.isEmpty) {
      throw const InviteInvalidException('존재하지 않거나 잘못된 초대 코드입니다.');
    }
    if (inviteQuery.docs.length > 1) {
      throw const InviteInvalidException('초대 코드가 올바르지 않습니다.');
    }
    return inviteQuery.docs.first.reference;
  }

  // ---------------------------------------------------------------------------
  // 조회 / 멤버 CRUD
  // ---------------------------------------------------------------------------

  Future<RoomModel?> getRoom(String roomId) async {
    final snap = await _rooms.doc(roomId).get();
    if (!snap.exists) return null;
    return RoomModel.fromFirestore(snap);
  }

  Stream<List<RoomModel>> watchOwnedRooms(String ownerId) {
    return _rooms
        .where('ownerId', isEqualTo: ownerId)
        .limit(FirestoreQueryLimits.rooms)
        .snapshots()
        .map((s) => s.docs.map(RoomModel.fromFirestore).toList());
  }

  Stream<List<RoomModel>> watchMyRooms() {
    return watchMyRoomsWithMembership()
        .map((entries) => entries.map((e) => e.room).toList());
  }

  /// 내가 속한 방 + 역할(멤버십) — 목록 배지·상세 분기용
  Stream<List<RoomMembershipEntry>> watchMyRoomsWithMembership() {
    final uid = _uid;
    return _members
        .where('userId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .limit(FirestoreQueryLimits.rooms)
        .snapshots()
        .asyncMap((memberSnap) async {
      if (memberSnap.docs.isEmpty) return <RoomMembershipEntry>[];

      final entries = <RoomMembershipEntry>[];
      for (final doc in memberSnap.docs) {
        final membership = RoomMemberModel.fromFirestore(doc);
        final room = await getRoom(membership.roomId);
        if (room != null) {
          entries.add(
            RoomMembershipEntry(room: room, membership: membership),
          );
        }
      }

      // 내 매장(owner) 우선, 이름순
      entries.sort((a, b) {
        if (a.isOwnedByMe != b.isOwnedByMe) {
          return a.isOwnedByMe ? -1 : 1;
        }
        return a.room.name.compareTo(b.room.name);
      });
      return entries;
    });
  }

  Stream<RoomMembershipEntry?> watchRoomMembership(String roomId) {
    final uid = _uid;
    return _members
        .doc(FirestorePaths.roomMemberDocId(roomId, uid))
        .snapshots()
        .asyncMap((memberSnap) async {
      if (!memberSnap.exists) return null;
      final membership = RoomMemberModel.fromFirestore(memberSnap);
      if (!membership.isActive) return null;
      final room = await getRoom(roomId);
      if (room == null) return null;
      return RoomMembershipEntry(room: room, membership: membership);
    });
  }

  Future<List<RoomMemberModel>> listMembers(String roomId) async {
    final snap = await _members
        .where('roomId', isEqualTo: roomId)
        .where('isActive', isEqualTo: true)
        .limit(FirestoreQueryLimits.list)
        .get();
    return snap.docs.map(RoomMemberModel.fromFirestore).toList();
  }

  Future<RoomMemberModel?> getMembership(String roomId, String userId) async {
    final snap = await _members
        .doc(FirestorePaths.roomMemberDocId(roomId, userId))
        .get();
    if (!snap.exists) return null;
    return RoomMemberModel.fromFirestore(snap);
  }

  Future<void> updateMemberRole({
    required String roomId,
    required String userId,
    required MemberRole role,
  }) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    final ref = _members.doc(FirestorePaths.roomMemberDocId(roomId, userId));
    final snap = await ref.get();
    if (!snap.exists) {
      throw const RoomNotFoundException('멤버를 찾을 수 없습니다.');
    }
    await ref.update({'role': role.firestoreValue});
  }

  Future<void> removeMember({
    required String roomId,
    required String userId,
  }) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    if (userId == uid) {
      throw const RoomPermissionDeniedException('자기 자신은 이 방법으로 제거할 수 없습니다.');
    }

    final memberRef =
        _members.doc(FirestorePaths.roomMemberDocId(roomId, userId));
    final roomRef = _rooms.doc(roomId);

    await _db.runTransaction((tx) async {
      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) return;
      final wasActive = memberSnap.data()?['isActive'] as bool? ?? false;
      if (!wasActive) return;

      tx.update(memberRef, {'isActive': false});
      tx.update(roomRef, {
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<int> getOwnedRoomCount(String ownerId) async {
    final snap = await _users.doc(ownerId).get();
    if (!snap.exists) return 0;
    return snap.data()?['ownedRoomCount'] as int? ?? 0;
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  Future<void> _ensureCanInvite(String roomId, String uid) async {
    final membership = await getMembership(roomId, uid);
    if (membership == null || !membership.isActive) {
      throw const RoomPermissionDeniedException();
    }
    if (!membership.role.canInviteMembers) {
      throw const RoomPermissionDeniedException('초대 권한이 없습니다.');
    }
  }

  /// 전역 유일 숫자 코드 — `invite_codes` 문서 ID + `room_invites.code` 이중 검사
  ///
  /// 비활성·만료 초대에 쓰인 코드도 재사용하지 않음 (전역 예약 유지).
  Future<String> _generateUniqueInviteCode({int length = 8}) async {
    final random = Random.secure();

    for (var attempt = 0; attempt < 64; attempt++) {
      final code = List.generate(
        length,
        (_) => random.nextInt(10).toString(),
      ).join();

      // 1) 전역 인덱스 (문서 ID = code) — O(1)
      final reserved = await _inviteCodes.doc(code).get();
      if (reserved.exists) continue;

      // 2) 레거시/누락 인덱스 대비 room_invites 전체(활성·비활성) 조회
      final existing = await _invites
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      return code;
    }

    throw StateError('초대 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }

  static bool _isNumericInviteCode(String code) {
    if (code.isEmpty) return false;
    for (final c in code.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }
}
