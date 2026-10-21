import '../../../models/enums/member_role.dart';
import '../../../models/store_member_model.dart';
import '../../../models/store_model.dart';
import '../../../services/store_firestore_service.dart';
import '../../../services/store_member_service.dart';

/// 매장·멤버 도메인 서비스 (features/store)
class StoreService {
  StoreService({
    StoreFirestoreService? stores,
    StoreMemberService? members,
  })  : _stores = stores ?? StoreFirestoreService(),
        _members = members ?? StoreMemberService();

  static final StoreService instance = StoreService();

  final StoreFirestoreService _stores;
  final StoreMemberService _members;

  Future<StoreModel> createStore({
    required String name,
    required String ownerUid,
    required double latitude,
    required double longitude,
    String? ownerDisplayName,
    String? address,
  }) {
    return _stores.create(
      name: name,
      ownerId: ownerUid,
      latitude: latitude,
      longitude: longitude,
      ownerDisplayName: ownerDisplayName,
      address: address,
    );
  }

  Future<StoreModel?> getStore(String storeId) => _stores.getById(storeId);

  Future<List<StoreModel>> listOwned(String ownerUid) =>
      _stores.listByOwner(ownerUid);

  Future<StoreMemberModel> inviteWorker({
    required String storeId,
    required String workerUid,
    required String displayName,
    required String ownerUid,
    int? hourlyWage,
  }) {
    return _members.addMember(
      storeId: storeId,
      userId: workerUid,
      displayName: displayName,
      role: MemberRole.worker,
      actorUid: ownerUid,
      invitedBy: ownerUid,
      hourlyWage: hourlyWage,
    );
  }

  Future<List<StoreMemberModel>> listMembers(String storeId) =>
      _members.listByStore(storeId);

  Future<List<StoreMemberModel>> listMemberships(String userUid) =>
      _members.listByUser(userUid);

  Future<void> removeMember({
    required String storeId,
    required String userId,
    required String actorUid,
  }) {
    return _members.removeMember(
      storeId: storeId,
      userId: userId,
      actorUid: actorUid,
    );
  }

  Future<void> deleteStore({
    required String storeId,
    required String actorUid,
  }) {
    return _stores.delete(storeId: storeId, actorUid: actorUid);
  }
}
