import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums/member_role.dart';
import '../models/user_model.dart';

/// `users` 컬렉션 CRUD
class UserFirestoreService {
  UserFirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.users);

  Future<UserModel?> getById(String uid) async {
    try {
      final snap = await _col.doc(uid).get();
      if (!snap.exists) {
        debugPrint('[UserFirestore] getById miss uid=$uid');
        return null;
      }
      debugPrint('[UserFirestore] getById ok uid=$uid');
      return UserModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] getById FAIL uid=$uid code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<UserModel?> findByKakaoId(String kakaoId) async {
    try {
      final q = await _col
          .where('kakaoId', isEqualTo: kakaoId)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return UserModel.fromFirestore(q.docs.first);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] findByKakaoId FAIL kakaoId=$kakaoId '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<UserModel> upsert(UserModel user, {bool mergeKakao = false}) async {
    try {
      final ref = _col.doc(user.uid);
      final existing = await ref.get();
      final isCreate = !existing.exists;
      final data = mergeKakao
          ? user.toKakaoUpsertMap(isCreate: isCreate)
          : user.toFirestore(forCreate: isCreate);

      await ref.set(data, SetOptions(merge: true));
      debugPrint(
        '[UserFirestore] upsert ok uid=${user.uid} create=$isCreate '
        'kakaoId=${user.kakaoId}',
      );

      final snap = await ref.get();
      return UserModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] upsert FAIL uid=${user.uid} code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> updateRole(String uid, MemberRole role) async {
    try {
      await _col.doc(uid).update({
        'role': role.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserFirestore] updateRole ok uid=$uid role=${role.name}');
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] updateRole FAIL uid=$uid code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  /// 온보딩 실명 저장 — `users/{uid}` merge
  Future<UserModel> saveRealName({
    required String uid,
    required String realName,
  }) async {
    final trimmed = realName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError('실명은 2자 이상이어야 합니다.');
    }
    try {
      final ref = _col.doc(uid);
      await ref.set({
        'realName': trimmed,
        // 표시명도 실명으로 맞춰 급여·근태 UI와 일치
        'displayName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[UserFirestore] saveRealName ok uid=$uid');
      final snap = await ref.get();
      if (!snap.exists) {
        throw StateError('사용자 문서를 찾을 수 없습니다.');
      }
      return UserModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] saveRealName FAIL uid=$uid code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> delete(String uid) async {
    try {
      await _col.doc(uid).delete();
      debugPrint('[UserFirestore] delete ok uid=$uid');
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] delete FAIL uid=$uid code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }
}
