import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_paths.dart';
import '../exceptions/room_exceptions.dart';
import '../../models/enums/member_role.dart';
import '../../models/store_member_model.dart';

/// 매장 UID·역할 기반 권한 검증
class StorePermissionGuard {
  StorePermissionGuard({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<StoreMemberModel> requireMember({
    required String storeId,
    required String uid,
  }) async {
    final snap = await _db
        .collection(FirestorePaths.storeMembers)
        .doc(FirestorePaths.storeMemberDocId(storeId, uid))
        .get();
    if (!snap.exists) {
      debugPrint(
        '[Permission] DENIED not a member store=$storeId uid=$uid',
      );
      throw const RoomPermissionDeniedException('매장 멤버가 아닙니다.');
    }
    final member = StoreMemberModel.fromFirestore(snap);
    if (!member.isActive) {
      throw const RoomPermissionDeniedException('비활성 멤버입니다.');
    }
    return member;
  }

  /// 사장/매니저만 허용
  Future<StoreMemberModel> requireManager({
    required String storeId,
    required String uid,
  }) async {
    final member = await requireMember(storeId: storeId, uid: uid);
    if (!member.isOwnerOrManager) {
      debugPrint(
        '[Permission] DENIED not manager store=$storeId uid=$uid '
        'role=${member.role}',
      );
      throw const RoomPermissionDeniedException(
        '사장 또는 매니저만 수행할 수 있습니다.',
      );
    }
    return member;
  }

  /// 본인 또는 사장/매니저
  Future<StoreMemberModel> requireSelfOrManager({
    required String storeId,
    required String uid,
    required String resourceOwnerUid,
  }) async {
    final member = await requireMember(storeId: storeId, uid: uid);
    if (uid == resourceOwnerUid || member.isOwnerOrManager) {
      return member;
    }
    debugPrint(
      '[Permission] DENIED self-or-manager store=$storeId uid=$uid '
      'owner=$resourceOwnerUid',
    );
    throw const RoomPermissionDeniedException(
      '본인 또는 관리자만 수정·삭제할 수 있습니다.',
    );
  }

  Future<bool> isManager(String storeId, String uid) async {
    try {
      final m = await requireMember(storeId: storeId, uid: uid);
      return m.isOwnerOrManager;
    } catch (_) {
      return false;
    }
  }

  Future<MemberRole?> roleOf(String storeId, String uid) async {
    try {
      return (await requireMember(storeId: storeId, uid: uid)).role;
    } catch (_) {
      return null;
    }
  }
}
