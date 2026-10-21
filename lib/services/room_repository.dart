import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import '../core/exceptions/room_exceptions.dart';
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
  Future<RoomInviteModel> createInvite({
    required String roomId,
    required MemberRole role,
    int? maxUses,
    Duration? validFor,
  }) async {
    final uid = _uid;
    await _ensureCanInvite(roomId, uid);

    final code = await _generateUniqueInviteCode();
    final inviteRef = _invites.doc();
    final invite = RoomInviteModel(
      id: inviteRef.id,
      roomId: roomId,
      code: code,
      role: role,
      createdBy: uid,
      maxUses: maxUses,
      expiresAt: validFor != null ? DateTime.now().add(validFor) : null,
    );

    await inviteRef.set(invite.toFirestore(forCreate: true));
    return invite;
  }

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
        .get();

    return snap.docs.map(RoomInviteModel.fromFirestore).toList();
  }

  // ---------------------------------------------------------------------------
  // 초대 코드로 방 참여 (직책 자동 적용)
  // ---------------------------------------------------------------------------

  /// 초대 코드로 가입 — 사장이 지정한 [RoomInviteModel.role]로 멤버 등록
  ///
  /// Firestore `room_members` 생성 → Cloud Functions `onRoomMemberCreated`
  /// 가 사장에게 직원 등록 알림을 보냅니다.
  Future<RoomMemberModel> joinRoomWithInviteCode(String rawCode) async {
    final uid = _uid;
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const InviteInvalidException('초대 코드를 입력해주세요.');
    }

    final inviteQuery = await _invites
        .where('code', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (inviteQuery.docs.isEmpty) {
      throw const InviteInvalidException();
    }

    final inviteDoc = inviteQuery.docs.first;
    final invite = RoomInviteModel.fromFirestore(inviteDoc);

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

      final inviteSnap = await tx.get(inviteDoc.reference);
      if (!inviteSnap.exists) {
        throw const InviteInvalidException();
      }
      final liveInvite = RoomInviteModel.fromFirestore(inviteSnap);
      if (!liveInvite.canBeUsed) {
        throw const InviteInvalidException('만료되었거나 사용이 끝난 초대입니다.');
      }

      joined = RoomMemberModel(
        roomId: invite.roomId,
        userId: uid,
        // 핵심: 초대에 매핑된 직책 그대로 등록 (알바생 선택 없음)
        role: liveInvite.role,
        displayName: _displayName,
      );

      if (existingMember.exists) {
        tx.update(memberRef, {
          ...joined.toFirestore(),
          'joinedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(memberRef, joined.toFirestore(forCreate: true));
      }

      final memberCount = roomSnap.data()?['memberCount'] as int? ?? 0;
      final wasInactive = existingMember.exists &&
          !(existingMember.data()?['isActive'] as bool? ?? false);
      final shouldIncrementCount = !existingMember.exists || wasInactive;
      tx.update(roomRef, {
        'memberCount':
            memberCount + (shouldIncrementCount ? 1 : 0),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final nextUsed = liveInvite.usedCount + 1;
      tx.update(inviteDoc.reference, {
        'usedCount': nextUsed,
        if (liveInvite.maxUses != null && nextUsed >= liveInvite.maxUses!)
          'isActive': false,
      });
    });

    return joined;
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

      final roomSnap = await tx.get(roomRef);
      tx.update(memberRef, {'isActive': false});
      if (roomSnap.exists) {
        final count = roomSnap.data()?['memberCount'] as int? ?? 1;
        tx.update(roomRef, {
          'memberCount': count > 0 ? count - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
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

  /// 전역 유일 숫자 코드 — 매장·직책과 무관하게 코드 하나 = 방 하나
  Future<String> _generateUniqueInviteCode({int length = 8}) async {
    final random = Random.secure();

    for (var attempt = 0; attempt < 64; attempt++) {
      final code = List.generate(
        length,
        (_) => random.nextInt(10).toString(),
      ).join();

      final existing = await _invites
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }

    throw StateError('초대 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }
}
