import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../core/exceptions/room_exceptions.dart';
import '../core/firebase/firestore_query_limits.dart';
import '../core/permissions/store_permission_guard.dart';
import '../models/enums/member_role.dart';
import '../models/store_member_model.dart';

/// `store_members` CRUD — 사장(초대자) ↔ 알바(참여자) UID 매칭
class StoreMemberService {
  StoreMemberService({
    FirebaseFirestore? firestore,
    StorePermissionGuard? permission,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _permission = permission ?? StorePermissionGuard(firestore: firestore);

  final FirebaseFirestore _db;
  final StorePermissionGuard _permission;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.storeMembers);

  Future<StoreMemberModel> addMember({
    required String storeId,
    required String userId,
    required String displayName,
    required MemberRole role,
    required String actorUid,
    String? invitedBy,
    int? hourlyWage,
  }) async {
    await _permission.requireManager(storeId: storeId, uid: actorUid);

    final ref = _col.doc(FirestorePaths.storeMemberDocId(storeId, userId));
    final existing = await ref.get();
    if (existing.exists &&
        (existing.data()?['isActive'] as bool? ?? true) == true) {
      throw const AlreadyRoomMemberException('이미 매장 멤버입니다.');
    }

    final member = StoreMemberModel(
      storeId: storeId,
      userId: userId,
      role: role,
      displayName: displayName,
      invitedBy: invitedBy ?? actorUid,
      hourlyWage: hourlyWage,
    );
    await ref.set(member.toFirestore(forCreate: true), SetOptions(merge: true));
    debugPrint('[StoreMember] add ok ${ref.path} role=${role.name}');
    return StoreMemberModel.fromFirestore(await ref.get());
  }

  /// 사장 본인을 owner 로 등록 (매장 생성 직후)
  Future<StoreMemberModel> ensureOwnerMember({
    required String storeId,
    required String ownerUid,
    required String displayName,
  }) async {
    final ref = _col.doc(FirestorePaths.storeMemberDocId(storeId, ownerUid));
    final member = StoreMemberModel(
      storeId: storeId,
      userId: ownerUid,
      role: MemberRole.owner,
      displayName: displayName,
      invitedBy: ownerUid,
    );
    await ref.set(member.toFirestore(forCreate: true), SetOptions(merge: true));
    debugPrint('[StoreMember] owner ensured ${ref.path}');
    return StoreMemberModel.fromFirestore(await ref.get());
  }

  Future<StoreMemberModel?> get({
    required String storeId,
    required String userId,
  }) async {
    final snap =
        await _col.doc(FirestorePaths.storeMemberDocId(storeId, userId)).get();
    if (!snap.exists) return null;
    return StoreMemberModel.fromFirestore(snap);
  }

  Future<List<StoreMemberModel>> listByStore(
    String storeId, {
    int limit = FirestoreQueryLimits.list,
  }) async {
    final q = await _col
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    return q.docs.map(StoreMemberModel.fromFirestore).toList();
  }

  Future<List<StoreMemberModel>> listByUser(
    String userId, {
    int limit = FirestoreQueryLimits.rooms,
  }) async {
    final q = await _col
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    return q.docs.map(StoreMemberModel.fromFirestore).toList();
  }

  Future<void> removeMember({
    required String storeId,
    required String userId,
    required String actorUid,
  }) async {
    await _permission.requireManager(storeId: storeId, uid: actorUid);
    final ref = _col.doc(FirestorePaths.storeMemberDocId(storeId, userId));
    await ref.update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[StoreMember] deactivate ok ${ref.path}');
  }

  Future<void> updateRole({
    required String storeId,
    required String userId,
    required MemberRole role,
    required String actorUid,
  }) async {
    await _permission.requireManager(storeId: storeId, uid: actorUid);
    await _col.doc(FirestorePaths.storeMemberDocId(storeId, userId)).update({
      'role': role.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[StoreMember] role updated user=$userId → ${role.name}');
  }
}
