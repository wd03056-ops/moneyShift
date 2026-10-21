import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import '../models/geo_location.dart';
import '../models/store_model.dart';
import 'store_member_service.dart';

/// `stores` 컬렉션 CRUD
class StoreFirestoreService {
  StoreFirestoreService({
    FirebaseFirestore? firestore,
    StoreMemberService? members,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _members = members ?? StoreMemberService(firestore: firestore);

  final FirebaseFirestore _db;
  final StoreMemberService _members;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.stores);

  Future<StoreModel> create({
    required String name,
    required String ownerId,
    required double latitude,
    required double longitude,
    String? ownerDisplayName,
    String? address,
    double geofenceRadiusMeters =
        AppConstants.attendanceGeofenceRadiusMeters,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('매장 이름을 입력해주세요.');
    }

    try {
      final ref = _col.doc();
      final store = StoreModel(
        id: ref.id,
        name: trimmed,
        ownerId: ownerId,
        location: GeoLocation(
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
        geofenceRadiusMeters: geofenceRadiusMeters,
      );
      await ref.set(store.toFirestore(forCreate: true));
      await _members.ensureOwnerMember(
        storeId: ref.id,
        ownerUid: ownerId,
        displayName: ownerDisplayName?.trim().isNotEmpty == true
            ? ownerDisplayName!.trim()
            : '사장',
      );
      debugPrint(
        '[StoreFirestore] create ok id=${ref.id} ownerId=$ownerId name=$trimmed',
      );
      final snap = await ref.get();
      return StoreModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[StoreFirestore] create FAIL code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<StoreModel?> getById(String storeId) async {
    try {
      final snap = await _col.doc(storeId).get();
      if (!snap.exists) return null;
      return StoreModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[StoreFirestore] getById FAIL id=$storeId code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<List<StoreModel>> listByOwner(String ownerId) async {
    try {
      final q = await _col.where('ownerId', isEqualTo: ownerId).get();
      debugPrint(
        '[StoreFirestore] listByOwner ok ownerId=$ownerId count=${q.docs.length}',
      );
      return q.docs.map(StoreModel.fromFirestore).toList();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[StoreFirestore] listByOwner FAIL ownerId=$ownerId code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<StoreModel> update(StoreModel store) async {
    try {
      await _col.doc(store.id).update(store.toFirestore());
      debugPrint('[StoreFirestore] update ok id=${store.id}');
      final snap = await _col.doc(store.id).get();
      return StoreModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[StoreFirestore] update FAIL id=${store.id} code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> delete({
    required String storeId,
    required String actorUid,
  }) async {
    final snap = await _col.doc(storeId).get();
    if (!snap.exists) return;
    final store = StoreModel.fromFirestore(snap);
    if (store.ownerId != actorUid) {
      throw StateError('매장 삭제는 사장만 가능합니다.');
    }
    try {
      await _col.doc(storeId).delete();
      debugPrint('[StoreFirestore] delete ok id=$storeId by=$actorUid');
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[StoreFirestore] delete FAIL id=$storeId code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }
}
