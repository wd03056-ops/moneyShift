import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../mock/mock_store.dart';
import '../../../models/attendance_session_model.dart';
import '../../../models/employee_contract_model.dart';
import '../../../models/enums/member_role.dart';
import '../../../models/enums/schedule_status.dart';
import '../../../models/geo_location.dart';
import '../../../models/room_member_model.dart';
import '../../../models/schedule_model.dart';
import '../../../models/store_member_model.dart';
import '../../../models/store_model.dart';
import 'mock_auth_service.dart';

/// Mock 인증용 더미 stores / store_members / schedules / attendances 시드
class MockFirestoreSeedService {
  MockFirestoreSeedService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static final MockFirestoreSeedService instance = MockFirestoreSeedService();

  static const _demoLocation = GeoLocation(
    latitude: 37.5665,
    longitude: 126.9780,
    address: '서울특별시 중구 세종대로 110 (서울특별시청)',
  );

  Future<void> ensureDemoData({required String ownerUid}) async {
    try {
      await _ensureStore(ownerUid);
      await _ensureMembers(ownerUid);
      await _ensureRoomMembers(ownerUid);
      await _ensureSchedule(ownerUid);
      await _ensureAttendance(ownerUid);
      debugPrint('[MockSeed] demo data ready ownerUid=$ownerUid');
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[MockSeed] FAIL code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
    } catch (e, st) {
      debugPrint('[MockSeed] FAIL: $e');
      debugPrint('$st');
    }
  }

  Future<void> _ensureStore(String ownerUid) async {
    final ref =
        _db.collection(FirestorePaths.stores).doc(MockAuthService.demoStoreId);
    if ((await ref.get()).exists) {
      debugPrint('[MockSeed] store exists ${ref.path}');
      return;
    }
    final store = StoreModel(
      id: MockAuthService.demoStoreId,
      name: '테스트 카페',
      ownerId: ownerUid,
      location: _demoLocation,
    );
    await ref.set(store.toFirestore(forCreate: true));
    debugPrint('[MockSeed] store created ${ref.path}');
  }

  Future<void> _ensureMembers(String ownerUid) async {
    final owner = StoreMemberModel(
      storeId: MockAuthService.demoStoreId,
      userId: ownerUid,
      role: MemberRole.owner,
      displayName: '테스트 사용자',
      invitedBy: ownerUid,
    );
    final staff = StoreMemberModel(
      storeId: MockAuthService.demoStoreId,
      userId: MockAuthService.staffUid,
      role: MemberRole.parttime,
      displayName: '테스트 알바',
      invitedBy: ownerUid,
      hourlyWage: 10320,
    );
    for (final m in [owner, staff]) {
      final ref = _db
          .collection(FirestorePaths.storeMembers)
          .doc(m.docId);
      if ((await ref.get()).exists) continue;
      await ref.set(m.toFirestore(forCreate: true));
      debugPrint('[MockSeed] member created ${ref.path}');
    }
  }

  /// UI MockStore 데모 방(`demo_room_shared`) room_members — Rules·스케줄 쓰기용
  Future<void> _ensureRoomMembers(String ownerUid) async {
    const roomId = MockStore.demoRoomId;
    final members = [
      RoomMemberModel(
        roomId: roomId,
        userId: ownerUid,
        role: MemberRole.owner,
        displayName: '테스트 사용자',
        contract: const EmployeeContractModel(hourlyWage: 10320),
      ),
      RoomMemberModel(
        roomId: roomId,
        userId: MockAuthService.staffUid,
        role: MemberRole.parttime,
        displayName: '테스트 알바',
        contract: const EmployeeContractModel(hourlyWage: 10320),
      ),
    ];
    for (final m in members) {
      final ref = _db.collection(FirestorePaths.roomMembers).doc(m.docId);
      if ((await ref.get()).exists) continue;
      await ref.set(m.toFirestore(forCreate: true));
      debugPrint('[MockSeed] room_member created ${ref.path}');
    }
  }

  Future<void> _ensureSchedule(String ownerUid) async {
    final ref = _db
        .collection(FirestorePaths.schedules)
        .doc(MockAuthService.demoScheduleId);
    final existing = await ref.get();
    if (existing.exists) {
      // 구 시드(test_store_001) → UI 데모 방 ID로 맞춤
      final data = existing.data();
      if (data != null && data['roomId'] != MockStore.demoRoomId) {
        await ref.set({
          'roomId': MockStore.demoRoomId,
          'storeId': MockStore.demoRoomId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint(
          '[MockSeed] schedule roomId migrated → ${MockStore.demoRoomId}',
        );
      } else {
        debugPrint('[MockSeed] schedule exists ${ref.path}');
      }
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final start = DateTime.now().copyWith(
      hour: 9,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final end = start.add(const Duration(hours: 5));

    // UI 데모 방과 동일 roomId — RoomDetail syncSchedulesForRoom 과 맞춤
    final schedule = ScheduleModel(
      id: MockAuthService.demoScheduleId,
      roomId: MockStore.demoRoomId,
      workerId: MockAuthService.staffUid,
      assignedBy: ownerUid,
      date: today,
      startTime: start,
      endTime: end,
      breakMinutes: 30,
      basePay: 10320,
      status: ScheduleStatus.normal,
      isConfirmed: true,
      note: 'Mock 시드 근무',
    );
    await ref.set({
      ...schedule.toFirestore(forCreate: true),
      'storeId': MockStore.demoRoomId,
      'createdBy': ownerUid,
      'workerUid': MockAuthService.staffUid,
      'hourlyWage': 10320,
    });
    debugPrint('[MockSeed] schedule created ${ref.path}');
  }

  Future<void> _ensureAttendance(String ownerUid) async {
    final ref = _db
        .collection(FirestorePaths.attendances)
        .doc(MockAuthService.demoAttendanceId);
    if ((await ref.get()).exists) {
      debugPrint('[MockSeed] attendance exists ${ref.path}');
      return;
    }

    final clockIn = DateTime.now().subtract(const Duration(hours: 2));
    final session = AttendanceSessionModel(
      id: MockAuthService.demoAttendanceId,
      storeId: MockAuthService.demoStoreId,
      userId: MockAuthService.staffUid,
      clockInAt: clockIn,
      clockInLocation: _demoLocation,
      status: AttendanceSessionStatus.clockedIn,
      scheduleId: MockAuthService.demoScheduleId,
      hourlyWage: 10320,
      isApproved: false,
    );
    await ref.set(session.toFirestore(forCreate: true));
    debugPrint('[MockSeed] attendance created ${ref.path}');
  }
}
