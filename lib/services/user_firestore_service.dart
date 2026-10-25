import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import '../core/firebase/firestore_query_limits.dart';
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
    if (mergeKakao) {
      return upsertKakaoProfile(user);
    }
    try {
      final ref = _col.doc(user.uid);
      final existing = await ref.get();
      final isCreate = !existing.exists;
      final data = user.toFirestore(forCreate: isCreate);

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

  /// 카카오 로그인용 — 트랜잭션으로 최초 생성 / 기존 유지 (레이스·중복 생성 방지)
  ///
  /// - 없으면: displayName·email·kakaoId·role·createdAt 생성
  /// - 있으면: 카카오 프로필(닉네임·이미지·email)만 갱신, realName·role·ownedRoomCount 유지
  Future<UserModel> upsertKakaoProfile(UserModel incoming) async {
    final ref = _col.doc(incoming.uid);
    try {
      final result = await _db.runTransaction<UserModel>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          final data = incoming.toKakaoUpsertMap(isCreate: true);
          tx.set(ref, data, SetOptions(merge: true));
          debugPrint(
            '[UserFirestore] kakao create uid=${incoming.uid} '
            'kakaoId=${incoming.kakaoId}',
          );
          return incoming.copyWith(
            createdAt: incoming.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }

        final existing = UserModel.fromFirestore(snap);
        final merged = incoming.copyWith(
          // 온보딩 실명·역할·매장 수·FCM 은 기존 유지
          realName: existing.realName,
          role: existing.role,
          ownedRoomCount: existing.ownedRoomCount,
          fcmToken: existing.fcmToken,
          fcmTokens: existing.fcmTokens,
          createdAt: existing.createdAt,
          // 카카오에서 비어 있으면 기존 email 유지
          email: incoming.email.trim().isNotEmpty
              ? incoming.email
              : existing.email,
          displayName: incoming.displayName.trim().isNotEmpty
              ? incoming.displayName
              : existing.displayName,
        );
        tx.set(
          ref,
          merged.toKakaoUpsertMap(isCreate: false),
          SetOptions(merge: true),
        );
        debugPrint(
          '[UserFirestore] kakao merge uid=${merged.uid} '
          'hasRealName=${merged.hasRealName}',
        );
        return merged.copyWith(updatedAt: DateTime.now());
      });
      return result;
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] upsertKakaoProfile FAIL uid=${incoming.uid} '
        'code=${e.code} message=${e.message}',
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

  /// 탈퇴 — 개인정보 익명화 (rules: users delete 불가 → merge update)
  Future<void> anonymizeForDeletion(String uid) async {
    const deletedName = AppConstants.deletedMemberDisplayName;
    try {
      final ref = _col.doc(uid);
      await ref.set({
        'uid': uid,
        'email': '',
        'displayName': deletedName,
        'realName': FieldValue.delete(),
        'phoneNumber': FieldValue.delete(),
        'kakaoId': FieldValue.delete(),
        'googleId': FieldValue.delete(),
        'profileImageUrl': FieldValue.delete(),
        'fcmToken': FieldValue.delete(),
        'fcmTokens': <String>[],
        'fcmTokenUpdatedAt': FieldValue.delete(),
        'notificationCategories': FieldValue.delete(),
        'isNotificationEnabled': false,
        'authProvider': 'deleted',
        'accountDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 인앱 알림함 비우기 (최대 200건)
      try {
        final notifs = await ref.collection(FirestorePaths.notifications).limit(200).get();
        for (final doc in notifs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[UserFirestore] notif clear soft-fail: $e');
      }

      // 소속 멤버십 표시명 익명화
      await _anonymizeMemberships(uid, deletedName);

      debugPrint('[UserFirestore] anonymizeForDeletion ok uid=$uid');
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[UserFirestore] anonymizeForDeletion FAIL uid=$uid '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> _anonymizeMemberships(String uid, String deletedName) async {
    Future<void> patchCollection(String collection) async {
      final q = await _db
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .limit(FirestoreQueryLimits.batchPage)
          .get();
      for (final doc in q.docs) {
        await doc.reference.set({
          'displayName': deletedName,
          'isActive': false,
          'accountDeleted': true,
          'linkedUserId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    try {
      await patchCollection(FirestorePaths.roomMembers);
    } catch (e) {
      debugPrint('[UserFirestore] room_members anonymize soft-fail: $e');
    }
    try {
      await patchCollection(FirestorePaths.storeMembers);
    } catch (e) {
      debugPrint('[UserFirestore] store_members anonymize soft-fail: $e');
    }
  }
}
