import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/exceptions/room_exceptions.dart';
import '../core/exceptions/schedule_exceptions.dart';
import '../core/time/kst_date_time.dart';
import '../features/notifications/domain/app_notification_dispatcher.dart';
import '../models/models.dart';
import '../services/payroll_calculator.dart';
import 'mock_session.dart';
import 'mock_user.dart';

/// 인메모리 목업 DB (방 · 멤버 · 초대 · 스케줄 · 출퇴근)
///
/// Firebase 없이 UI 플로우 전체를 즉시 반영한다.
class MockStore extends ChangeNotifier {
  MockStore._();
  static final MockStore instance = MockStore._();

  /// 사장·직원 공통 데모 매장 (계정 전환 시에도 유지)
  static const demoRoomId = 'demo_room_shared';
  static const demoInviteId = 'demo_invite_shared';
  /// 데모 알바 초대 코드 (숫자 8자리 · 전역 유일)
  static const demoInviteCode = '48290173';
  static const demoScheduleId = 'demo_schedule_today';

  final _uuid = const Uuid();
  final _random = Random();

  final Map<String, RoomModel> rooms = {};
  final Map<String, RoomMemberModel> members = {};
  final Map<String, RoomInviteModel> invites = {};
  final Map<String, ScheduleModel> schedules = {};
  final Map<String, AttendanceLogModel> attendanceLogs = {};
  final Map<String, ShiftSwapRequest> shiftSwaps = {};
  final Map<String, CommuteCorrectionRequest> commuteCorrections = {};
  final Map<String, NoticeModel> notices = {};

  /// 최근 배정 메타 — 직원 화면 진입 시 피드백용 (계정 전환 후에도 유지)
  DateTime? lastScheduleAssignedAt;
  String? lastAssignedWorkerId;
  String? lastAssignedRoomId;
  int lastAssignedCount = 0;

  /// 개발/테스트용 GPS 우회 (UI 비노출 — 내부 출퇴근 로직만 사용)
  bool gpsBypassEnabled = true;

  /// 매장별 사장 설정 (시급·수당·알림)
  final Map<String, RoomOwnerPrefs> roomOwnerPrefs = {};

  MockSession get _session => MockSession.instance;

  void setGpsBypassEnabled(bool enabled) {
    if (gpsBypassEnabled == enabled) return;
    gpsBypassEnabled = enabled;
    notifyListeners();
  }

  RoomOwnerPrefs prefsForRoom(String roomId) {
    return roomOwnerPrefs.putIfAbsent(roomId, RoomOwnerPrefs.newDefaults);
  }

  void updateRoomOwnerPrefs(String roomId, RoomOwnerPrefs prefs) {
    roomOwnerPrefs[roomId] = prefs;
    notifyListeners();
  }

  /// Play 계정 삭제 — 해당 사용자 관련 데이터 제거(익명화)
  void deleteAccountData(String userId) {
    // 소유 매장 삭제
    final ownedRoomIds =
        rooms.values.where((r) => r.ownerId == userId).map((r) => r.id).toList();
    for (final roomId in ownedRoomIds) {
      members.removeWhere((k, _) => k.startsWith('$roomId|'));
      invites.removeWhere((_, v) => v.roomId == roomId);
      schedules.removeWhere((_, v) => v.roomId == roomId);
      attendanceLogs.removeWhere((_, v) => v.roomId == roomId);
      shiftSwaps.removeWhere((_, v) => v.roomId == roomId);
      notices.removeWhere((_, v) => v.roomId == roomId);
      rooms.remove(roomId);
    }

    // 타 매장 멤버십·본인 근무·출퇴근·공지 작성분
    members.removeWhere((_, m) => m.userId == userId);
    schedules.removeWhere((_, s) => s.workerId == userId);
    attendanceLogs.removeWhere((_, a) => a.userId == userId);
    notices.removeWhere((_, n) => n.authorId == userId);
    shiftSwaps.removeWhere(
      (_, s) => s.fromWorkerId == userId || s.toWorkerId == userId,
    );

    // 멤버 수 재계산
    for (final room in rooms.values.toList()) {
      final count =
          members.values.where((m) => m.roomId == room.id).length;
      rooms[room.id] = room.copyWith(memberCount: count);
    }
    notifyListeners();
  }

  void resetAll() {
    rooms.clear();
    members.clear();
    invites.clear();
    schedules.clear();
    attendanceLogs.clear();
    shiftSwaps.clear();
    notices.clear();
    ensureDemoWorkspace();
  }

  /// 프로필 수정 시 방 멤버 표시 이름 동기화
  void syncMemberDisplayName({
    required String userId,
    required String displayName,
  }) {
    var changed = false;
    for (final entry in members.entries) {
      final m = entry.value;
      if (m.userId != userId || m.displayName == displayName) continue;
      members[entry.key] = m.copyWith(displayName: displayName);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// 사장 — 직원 기본 계약(시급·휴게·수당) 저장
  RoomMemberModel updateEmployeeContract({
    required String roomId,
    required String workerId,
    required EmployeeContractModel contract,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final actor = getMembership(roomId, user.uid);
    if (actor == null || !actor.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('직원 설정을 변경할 권한이 없습니다.');
    }

    final key = _memberKey(roomId, workerId);
    final target = members[key];
    if (target == null || !target.isActive) {
      throw const RoomPermissionDeniedException('직원을 찾을 수 없습니다.');
    }
    if (target.role.isAdminDashboard) {
      throw const RoomPermissionDeniedException('사장 계정에는 적용할 수 없습니다.');
    }

    final updated = target.copyWith(contract: contract);
    members[key] = updated;
    notifyListeners();
    return updated;
  }

  /// 사장 매장 + 초대 직원 멤버십이 없으면 시드
  void ensureDemoWorkspace() {
    if (!rooms.containsKey(demoRoomId)) {
      _seedDemoWorkspace();
      return;
    }
    // 기존 세션에도 직원 5명 로스터가 채워지도록 보강
    var changed = _ensureDemoStaffRoster();
    // 데모·시스템 자동 공지 제거 — 사장이 직접 작성한 공지만 유지
    if (_purgeNonOwnerNotices()) changed = true;
    // 날짜가 바뀌면 데모 '오늘 근무'를 현재 날짜로 맞춤
    if (_syncDemoTodaySchedule()) changed = true;
    if (changed) notifyListeners();
  }

  /// 사장이 [createNotice]로 작성하지 않은 공지(데모·시스템) 제거
  bool _purgeNonOwnerNotices() {
    final removeIds = notices.entries
        .where((e) {
          final n = e.value;
          if (n.authorId == 'system') return true;
          if (e.key.startsWith('demo_notice')) return true;
          return false;
        })
        .map((e) => e.key)
        .toList();
    if (removeIds.isEmpty) return false;
    for (final id in removeIds) {
      notices.remove(id);
    }
    return true;
  }

  /// 데모 오늘 근무표를 [KstDateTime.now] 기준으로 갱신. 변경 시 true
  bool _syncDemoTodaySchedule() {
    final now = KstDateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final start = DateTime(now.year, now.month, now.day, 9);
    final end = DateTime(now.year, now.month, now.day, 18);
    final existing = schedules[demoScheduleId];
    if (existing != null &&
        existing.date == today &&
        existing.startTime.year == start.year &&
        existing.startTime.month == start.month &&
        existing.startTime.day == start.day &&
        existing.startTime.hour == 9 &&
        existing.endTime.hour == 18) {
      return false;
    }

    final owner = MockUser.owner;
    final staff = MockUser.staff;
    schedules[demoScheduleId] = ScheduleModel(
      id: demoScheduleId,
      roomId: demoRoomId,
      workerId: staff.uid,
      assignedBy: owner.uid,
      date: today,
      startTime: start,
      endTime: end,
      isConfirmed: false,
      status: ScheduleStatus.normal,
      estimatedPay: PayrollCalculator.estimatePay(
        startTime: start,
        endTime: end,
        hourlyWage: AppConstants.minimumHourlyWage,
      ),
      note: '데모 — 직원 계정 오늘 근무',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    return true;
  }

  /// 데모 직원 5명 멤버십 보강. 추가되면 true
  bool _ensureDemoStaffRoster() {
    final now = KstDateTime.now();
    final roles = <MemberRole>[
      MemberRole.staff,
      MemberRole.parttime,
      MemberRole.manager,
      MemberRole.staff,
      MemberRole.parttime,
    ];
    final wages = <int>[
      AppConstants.minimumHourlyWage,
      AppConstants.minimumHourlyWage + 100,
      12000,
      AppConstants.minimumHourlyWage + 180,
      AppConstants.minimumHourlyWage,
    ];
    var added = false;

    for (var i = 0; i < MockUser.demoStaffRoster.length; i++) {
      final user = MockUser.demoStaffRoster[i];
      final key = _memberKey(demoRoomId, user.uid);
      final existing = members[key];
      if (existing != null) {
        // 레거시 데모 시급(10,000) → 최저시급 이상으로 보정
        if (existing.contract.hourlyWage < AppConstants.minimumHourlyWage) {
          members[key] = existing.copyWith(
            contract: existing.contract.copyWith(hourlyWage: wages[i]),
          );
          added = true;
        }
        continue;
      }
      members[key] = RoomMemberModel(
        roomId: demoRoomId,
        userId: user.uid,
        role: roles[i],
        displayName: user.displayName,
        contract: EmployeeContractModel(hourlyWage: wages[i]),
        joinedAt: now.subtract(Duration(days: i)),
      );
      added = true;
    }

    if (added) {
      final room = rooms[demoRoomId];
      if (room != null) {
        rooms[demoRoomId] = room.copyWith(
          memberCount: 1 + MockUser.demoStaffRoster.length,
          updatedAt: now,
        );
      }
    }
    return added;
  }

  void _seedDemoWorkspace() {
    final owner = MockUser.owner;
    final staff = MockUser.staff;
    final now = KstDateTime.now();

    rooms[demoRoomId] = RoomModel(
      id: demoRoomId,
      name: '테스트 매장',
      ownerId: owner.uid,
      location: const GeoLocation(
        latitude: 37.5665,
        longitude: 126.9780,
        address: '서울특별시 중구 세종대로 110',
      ),
      memberCount: 1 + MockUser.demoStaffRoster.length,
      createdAt: now,
      updatedAt: now,
    );

    members[_memberKey(demoRoomId, owner.uid)] = RoomMemberModel(
      roomId: demoRoomId,
      userId: owner.uid,
      role: MemberRole.owner,
      displayName: owner.displayName,
      joinedAt: now,
    );

    _ensureDemoStaffRoster();

    invites[demoInviteId] = RoomInviteModel(
      id: demoInviteId,
      roomId: demoRoomId,
      code: demoInviteCode, // 숫자만 (예: 482901)
      role: MemberRole.parttime,
      createdBy: owner.uid,
      expiresAt: now.add(const Duration(days: 30)),
      createdAt: now,
      maxUses: null,
      usedCount: 1,
      isActive: true,
    );

    final start = DateTime(now.year, now.month, now.day, 9);
    final end = DateTime(now.year, now.month, now.day, 18);
    schedules[demoScheduleId] = ScheduleModel(
      id: demoScheduleId,
      roomId: demoRoomId,
      workerId: staff.uid,
      assignedBy: owner.uid,
      date: DateFormat('yyyy-MM-dd').format(start),
      startTime: start,
      endTime: end,
      isConfirmed: false,
      status: ScheduleStatus.normal,
      estimatedPay: PayrollCalculator.estimatePay(
        startTime: start,
        endTime: end,
        hourlyWage: AppConstants.minimumHourlyWage,
      ),
      note: '데모 — 직원 계정 오늘 근무',
      createdAt: now,
      updatedAt: now,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 방 생성 / 초대 / 참여
  // ---------------------------------------------------------------------------

  RoomModel createRoom({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final ownedCount =
        rooms.values.where((r) => r.ownerId == user.uid).length;
    if (ownedCount >= AppConstants.freeMaxOwnedRooms) {
      throw RoomLimitExceededException(
        currentCount: ownedCount,
        freeLimit: AppConstants.freeMaxOwnedRooms,
      );
    }

    final roomId = _uuid.v4();
    final now = KstDateTime.now();
    final room = RoomModel(
      id: roomId,
      name: name.trim(),
      ownerId: user.uid,
      location: GeoLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      ),
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    );
    rooms[roomId] = room;

    members[_memberKey(roomId, user.uid)] = RoomMemberModel(
      roomId: roomId,
      userId: user.uid,
      role: MemberRole.owner,
      displayName: user.displayName,
      joinedAt: now,
    );

    notifyListeners();
    return room;
  }

  /// 사장/매니저 — 매장명 변경
  RoomModel renameRoom({
    required String roomId,
    required String name,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final room = rooms[roomId];
    if (room == null) throw const RoomNotFoundException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('매장명을 수정할 권한이 없습니다.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const RoomPermissionDeniedException('매장명을 입력해 주세요.');
    }

    final updated = room.copyWith(
      name: trimmed,
      updatedAt: KstDateTime.now(),
    );
    rooms[roomId] = updated;
    notifyListeners();
    return updated;
  }

  /// 사장/매니저 — 주소·출퇴근 반경 (좌표는 유지 또는 갱신)
  RoomModel updateRoomLocationSettings({
    required String roomId,
    String? address,
    double? latitude,
    double? longitude,
    double? geofenceRadiusMeters,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final room = rooms[roomId];
    if (room == null) throw const RoomNotFoundException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('매장 위치를 수정할 권한이 없습니다.');
    }

    final nextLat = latitude ?? room.location.latitude;
    final nextLng = longitude ?? room.location.longitude;
    final nextAddress = address?.trim().isNotEmpty == true
        ? address!.trim()
        : room.location.address;
    final nextRadius = geofenceRadiusMeters ?? room.geofenceRadiusMeters;

    final updated = room.copyWith(
      location: GeoLocation(
        latitude: nextLat,
        longitude: nextLng,
        address: nextAddress,
      ),
      geofenceRadiusMeters: nextRadius,
      updatedAt: KstDateTime.now(),
    );
    rooms[roomId] = updated;
    notifyListeners();
    return updated;
  }

  RoomInviteModel createInvite({
    required String roomId,
    required MemberRole role,
    Duration? validFor,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.role.canInviteMembers) {
      throw const RoomPermissionDeniedException('초대 권한이 없습니다.');
    }
    if (!rooms.containsKey(roomId)) {
      throw const RoomNotFoundException();
    }

    return _putInvite(
      roomId: roomId,
      role: role,
      createdBy: user.uid,
      validFor: validFor,
    );
  }

  /// 해당 직책의 활성 초대가 있으면 반환, 없으면 생성.
  /// 예전 한글 접두사 코드는 비활성 후 숫자 코드로 재발급.
  RoomInviteModel ensureInviteForRole({
    required String roomId,
    required MemberRole role,
    Duration validFor = const Duration(days: 7),
  }) {
    final existing = activeInviteForRole(roomId, role);
    if (existing != null) {
      if (_isNumericInviteCode(existing.code)) return existing;
      invites[existing.id] = existing.copyWith(isActive: false);
    }
    return createInvite(
      roomId: roomId,
      role: role,
      validFor: validFor,
    );
  }

  static bool _isNumericInviteCode(String code) {
    if (code.isEmpty) return false;
    for (final c in code.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  RoomInviteModel? activeInviteForRole(String roomId, MemberRole role) {
    for (final invite in invites.values) {
      if (invite.roomId == roomId &&
          invite.role == role &&
          invite.canBeUsed) {
        return invite;
      }
    }
    return null;
  }

  RoomInviteModel seedInviteFromOtherOwner({
    MemberRole role = MemberRole.parttime,
    String roomName = '이웃 카페 (데모)',
  }) {
    final other = MockUser.otherOwner;
    final roomId = _uuid.v4();
    final now = KstDateTime.now();

    rooms[roomId] = RoomModel(
      id: roomId,
      name: roomName,
      ownerId: other.uid,
      location: const GeoLocation(latitude: 37.5700, longitude: 126.9820),
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    );

    members[_memberKey(roomId, other.uid)] = RoomMemberModel(
      roomId: roomId,
      userId: other.uid,
      role: MemberRole.owner,
      displayName: other.displayName,
      joinedAt: now,
    );

    final invite = _putInvite(
      roomId: roomId,
      role: role,
      createdBy: other.uid,
      validFor: const Duration(days: 7),
    );
    notifyListeners();
    return invite;
  }

  RoomInviteModel _putInvite({
    required String roomId,
    required MemberRole role,
    required String createdBy,
    Duration? validFor,
  }) {
    final inviteId = _uuid.v4();
    final code = _generateGloballyUniqueNumericCode();
    // 매장·직책과 무관하게 코드는 전역 1:1 (같은 코드 → 다른 방 진입 불가)
    assert(
      !_isInviteCodeTaken(code),
      'invite code collision: $code',
    );
    final invite = RoomInviteModel(
      id: inviteId,
      roomId: roomId,
      code: code,
      role: role,
      createdBy: createdBy,
      expiresAt: validFor != null ? KstDateTime.now().add(validFor) : null,
      createdAt: KstDateTime.now(),
    );
    invites[inviteId] = invite;
    notifyListeners();
    return invite;
  }

  RoomMemberModel joinWithInviteCode(String rawCode) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final code = rawCode.trim();
    final matches = invites.values
        .where((i) => i.isActive && i.code == code)
        .toList();
    if (matches.length > 1) {
      // 데이터 무결성 오류 — 동일 코드가 두 방에 있으면 안 됨
      throw const InviteInvalidException('초대 코드가 올바르지 않습니다.');
    }
    final invite = matches.isEmpty ? null : matches.first;
    if (invite == null || !invite.canBeUsed) {
      throw const InviteInvalidException();
    }

    final room = rooms[invite.roomId];
    if (room == null) throw const RoomNotFoundException();

    if (room.ownerId == user.uid) {
      throw const AlreadyRoomMemberException('내가 만든 방입니다.');
    }

    final docId = _memberKey(invite.roomId, user.uid);
    final existing = members[docId];
    if (existing != null && existing.isActive) {
      throw const AlreadyRoomMemberException();
    }

    final member = RoomMemberModel(
      roomId: invite.roomId,
      userId: user.uid,
      role: invite.role,
      displayName: user.displayName,
      contract: const EmployeeContractModel(),
      joinedAt: KstDateTime.now(),
    );
    members[docId] = member;

    rooms[invite.roomId] = room.copyWith(
      memberCount: room.memberCount + (existing == null ? 1 : 0),
      updatedAt: KstDateTime.now(),
    );

    final nextUsed = invite.usedCount + 1;
    invites[invite.id] = invite.copyWith(
      usedCount: nextUsed,
      isActive: invite.maxUses == null || nextUsed < invite.maxUses!,
    );

    // 합류 시 오늘 근무표 1건 자동 시드 (확인 테스트용)
    _seedTodaySchedule(
      roomId: invite.roomId,
      workerId: user.uid,
      assignedBy: invite.createdBy,
      hourlyWage: member.hourlyWage ?? AppConstants.minimumHourlyWage,
    );

    notifyListeners();

    // 1) 직원 등록 → 사장
    AppNotificationDispatcher.staffJoined(
      ownerUid: room.ownerId,
      staffDisplayName: member.displayName,
      storeId: invite.roomId,
      staffUid: user.uid,
    );

    return member;
  }

  // ---------------------------------------------------------------------------
  // 스케줄
  // ---------------------------------------------------------------------------

  /// 사장/매니저가 직원에게 근무 일정을 배정합니다.
  ///
  /// [estimatedPay]가 없으면 시급·수당 옵션으로 자동 계산합니다.
  /// 생성 직후 [isConfirmed]는 false(확인 대기)이며,
  /// [notifyListeners]로 직원 캘린더·내 근무표에 즉시 반영됩니다.
  ScheduleModel createSchedule({
    required String roomId,
    required String workerId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
    String? assignmentBatchId,
    bool isPeriodBatch = false,
    int? hourlyWage,
    int? estimatedPay,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
    int breakMinutes = 0,
    PayEstimate? payEstimate,
    bool notifyWorker = true,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('근무표 작성 권한이 없습니다.');
    }

    final worker = getMembership(roomId, workerId);
    if (worker == null || !worker.isActive) {
      throw const RoomPermissionDeniedException('배정할 직원을 찾을 수 없습니다.');
    }
    if (worker.role == MemberRole.owner) {
      throw const RoomPermissionDeniedException('사장에게는 근무표를 배정할 수 없습니다.');
    }
    if (!endTime.isAfter(startTime)) {
      throw const InvalidScheduleTimeException();
    }
    if (_hasDuplicateShift(
      roomId: roomId,
      workerId: workerId,
      startTime: startTime,
      endTime: endTime,
    )) {
      throw const DuplicateScheduleException();
    }

    final id = _uuid.v4();
    final wage = hourlyWage ?? worker.hourlyWage ?? 10000;
    final estimate = payEstimate ??
        PayrollCalculator.estimate(
          startTime: startTime,
          endTime: endTime,
          hourlyWage: wage,
          breakMinutes: breakMinutes,
          includeWeeklyHoliday: includeWeeklyHoliday,
          includeOvertimeNight: includeOvertimeNight,
        );
    final pay = estimatedPay ?? estimate.total;
    final schedule = ScheduleModel(
      id: id,
      roomId: roomId,
      workerId: workerId,
      assignedBy: user.uid,
      date: DateFormat('yyyy-MM-dd').format(startTime),
      startTime: startTime,
      endTime: endTime,
      isConfirmed: false,
      status: ScheduleStatus.normal,
      estimatedPay: pay,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight,
      breakMinutes: estimate.breakMinutes,
      basePay: estimate.basePay,
      weeklyHolidayPay: estimate.weeklyHolidayPay,
      overtimeNightPay: estimate.overtimeNightPay,
      payEstimate: estimate,
      note: note,
      assignmentBatchId: assignmentBatchId,
      isPeriodBatch: isPeriodBatch,
      createdAt: KstDateTime.now(),
      updatedAt: KstDateTime.now(),
    );
    schedules[id] = schedule;
    _markAssigned(
      roomId: roomId,
      workerId: workerId,
      count: 1,
    );
    notifyListeners();

    // 2) 근무 배정 → 알바 (일괄 배정 시 첫 건만 + burst/content dedupe)
    if (notifyWorker) {
      final roomName = rooms[roomId]?.name ?? '매장';
      AppNotificationDispatcher.scheduleAssigned(
        workerUid: workerId,
        storeId: roomId,
        scheduleId: id,
        storeName: roomName,
        assignmentBatchId: assignmentBatchId,
      );
    }

    return schedule;
  }

  void _markAssigned({
    required String roomId,
    required String workerId,
    required int count,
  }) {
    lastScheduleAssignedAt = KstDateTime.now();
    lastAssignedRoomId = roomId;
    lastAssignedWorkerId = workerId;
    lastAssignedCount = count;
  }

  /// 같은 직원 · 같은 날 · 같은 출퇴근 시각이면 중복
  bool _hasDuplicateShift({
    required String roomId,
    required String workerId,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final date = DateFormat('yyyy-MM-dd').format(startTime);
    for (final s in schedules.values) {
      if (s.roomId != roomId) continue;
      if (s.workerId != workerId) continue;
      if (s.date != date) continue;
      if (s.startTime.hour == startTime.hour &&
          s.startTime.minute == startTime.minute &&
          s.endTime.hour == endTime.hour &&
          s.endTime.minute == endTime.minute) {
        return true;
      }
    }
    return false;
  }

  /// 여러 날짜에 동일 출퇴근·수당 옵션으로 근무표를 일괄 배정합니다.
  ///
  /// 개별 선택(10/3, 10/7) · 기간 선택(10/1~10/31) 모두 이 API를 사용합니다.
  List<ScheduleModel> createSchedulesForDates({
    required String roomId,
    required String workerId,
    required List<DateTime> dates,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? note,
    int? hourlyWage,
    int? estimatedPay,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
    int breakMinutes = 0,
    /// 기간 선택 배정이면 true → 목록에서 `시작일 ~ 종료일`로 묶음 표기
    bool asPeriod = false,
  }) {
    if (dates.isEmpty) {
      throw const InvalidScheduleTimeException('근무 날짜를 선택하세요.');
    }

    final uniqueDays = <String, DateTime>{};
    for (final raw in dates) {
      final day = DateTime(raw.year, raw.month, raw.day);
      uniqueDays[DateFormat('yyyy-MM-dd').format(day)] = day;
    }
    final sorted = uniqueDays.values.toList()..sort();

    // 배정 전에 날짜별 중복을 한 번에 검사 (부분 생성 방지)
    for (final day in sorted) {
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        startHour,
        startMinute,
      );
      final end = DateTime(
        day.year,
        day.month,
        day.day,
        endHour,
        endMinute,
      );
      if (_hasDuplicateShift(
        roomId: roomId,
        workerId: workerId,
        startTime: start,
        endTime: end,
      )) {
        throw const DuplicateScheduleException();
      }
    }

    final periodBatch = asPeriod && sorted.length > 1;
    final batchId = periodBatch ? _uuid.v4() : null;

    // 권한·시간 검증은 첫 건으로 수행 후, 나머지는 동일 규칙으로 일괄 삽입
    final first = createSchedule(
      roomId: roomId,
      workerId: workerId,
      startTime: DateTime(
        sorted.first.year,
        sorted.first.month,
        sorted.first.day,
        startHour,
        startMinute,
      ),
      endTime: DateTime(
        sorted.first.year,
        sorted.first.month,
        sorted.first.day,
        endHour,
        endMinute,
      ),
      note: note,
      assignmentBatchId: batchId,
      isPeriodBatch: periodBatch,
      hourlyWage: hourlyWage,
      estimatedPay: estimatedPay,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight,
      breakMinutes: breakMinutes,
    );

    final created = <ScheduleModel>[first];
    for (final day in sorted.skip(1)) {
      created.add(
        createSchedule(
          roomId: roomId,
          workerId: workerId,
          startTime: DateTime(
            day.year,
            day.month,
            day.day,
            startHour,
            startMinute,
          ),
          endTime: DateTime(
            day.year,
            day.month,
            day.day,
            endHour,
            endMinute,
          ),
          note: note,
          assignmentBatchId: batchId,
          isPeriodBatch: periodBatch,
          hourlyWage: hourlyWage,
          estimatedPay: estimatedPay,
          includeWeeklyHoliday: includeWeeklyHoliday,
          includeOvertimeNight: includeOvertimeNight,
          breakMinutes: breakMinutes,
          notifyWorker: false,
        ),
      );
    }
    // 일괄 배정 건수로 메타 갱신 (기간 선택은 1건으로 안내)
    _markAssigned(
      roomId: roomId,
      workerId: workerId,
      count: periodBatch ? 1 : created.length,
    );
    notifyListeners();
    return created;
  }

  /// workerId → 표시 이름 (없으면 uid 일부)
  String memberDisplayName(String roomId, String userId) {
    return getMembership(roomId, userId)?.displayName ?? userId;
  }

  /// 오늘 09:00–18:00 샘플 근무표
  ScheduleModel _seedTodaySchedule({
    required String roomId,
    required String workerId,
    required String assignedBy,
    required int hourlyWage,
  }) {
    final now = KstDateTime.now();
    final start = DateTime(now.year, now.month, now.day, 9);
    final end = DateTime(now.year, now.month, now.day, 18);
    final id = _uuid.v4();
    final schedule = ScheduleModel(
      id: id,
      roomId: roomId,
      workerId: workerId,
      assignedBy: assignedBy,
      date: DateFormat('yyyy-MM-dd').format(start),
      startTime: start,
      endTime: end,
      isConfirmed: false,
      status: ScheduleStatus.normal,
      estimatedPay: PayrollCalculator.estimatePay(
        startTime: start,
        endTime: end,
        hourlyWage: hourlyWage,
      ),
      note: '목업 샘플 근무',
      createdAt: now,
      updatedAt: now,
    );
    schedules[id] = schedule;
    return schedule;
  }

  /// 사장/매니저 — 해당 근무 결근 처리
  ScheduleModel markScheduleAbsent(String scheduleId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }

    final membership = getMembership(schedule.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('결근 처리할 권한이 없습니다.');
    }
    if (schedule.isAbsent) {
      throw const RoomPermissionDeniedException('이미 결근 처리된 근무입니다.');
    }

    final updated = schedule.copyWith(
      isAbsent: true,
      absentMarkedAt: KstDateTime.now(),
      absentMarkedBy: user.uid,
      updatedAt: KstDateTime.now(),
    );
    schedules[scheduleId] = updated;
    notifyListeners();

    // 7) 결근 처리 → 해당 알바
    final roomName = rooms[schedule.roomId]?.name ?? '매장';
    AppNotificationDispatcher.scheduleAbsent(
      workerUid: schedule.workerId,
      storeName: roomName,
      storeId: schedule.roomId,
      scheduleId: scheduleId,
    );

    return updated;
  }

  /// 사장/매니저 — 결근 처리 해제
  ScheduleModel clearScheduleAbsent(String scheduleId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }

    final membership = getMembership(schedule.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('결근을 해제할 권한이 없습니다.');
    }
    if (!schedule.isAbsent) {
      throw const RoomPermissionDeniedException('결근 처리된 근무가 아닙니다.');
    }

    final updated = schedule.copyWith(
      clearAbsent: true,
      updatedAt: KstDateTime.now(),
    );
    schedules[scheduleId] = updated;
    notifyListeners();
    return updated;
  }

  ScheduleModel confirmSchedule(String scheduleId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }
    if (schedule.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 근무표만 확인할 수 있습니다.');
    }

    final now = KstDateTime.now();
    var didConfirm = false;
    ScheduleModel result;

    // 기간 선택 배정은 같은 묶음을 한 번에 확인
    final batchId = schedule.assignmentBatchId;
    if (schedule.isPeriodBatch && batchId != null) {
      ScheduleModel? latest;
      for (final s in schedules.values) {
        if (s.assignmentBatchId != batchId) continue;
        if (s.workerId != user.uid) continue;
        if (s.isConfirmed) continue;
        final updated = s.copyWith(
          isConfirmed: true,
          confirmedAt: now,
          updatedAt: now,
        );
        schedules[s.id] = updated;
        latest = updated;
        didConfirm = true;
      }
      result = latest ??
          schedule.copyWith(
            isConfirmed: true,
            confirmedAt: now,
            updatedAt: now,
          );
    } else if (schedule.isConfirmed) {
      result = schedule;
    } else {
      result = schedule.copyWith(
        isConfirmed: true,
        confirmedAt: now,
        updatedAt: now,
      );
      schedules[scheduleId] = result;
      didConfirm = true;
    }

    if (didConfirm) {
      notifyListeners();
      final room = rooms[schedule.roomId];
      final ownerUid = room?.ownerId;
      if (ownerUid != null &&
          prefsForRoom(schedule.roomId).notifyScheduleChanges) {
        AppNotificationDispatcher.scheduleConfirmed(
          ownerUid: ownerUid,
          staffDisplayName: user.displayName,
          storeId: schedule.roomId,
          scheduleId: result.id,
          assignmentBatchId: batchId,
        );
      }
    }
    return result;
  }

  /// 확인 대기 근무 전체 확인 (사장 알림은 1회만)
  int confirmAllPendingSchedules({
    required String roomId,
    required String workerId,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();
    if (user.uid != workerId) {
      throw const RoomPermissionDeniedException('본인 근무표만 확인할 수 있습니다.');
    }

    final pending = pendingConfirmForWorker(roomId, workerId);
    if (pending.isEmpty) return 0;

    final now = KstDateTime.now();
    var count = 0;
    ScheduleModel? sample;
    for (final s in pending) {
      if (s.isConfirmed) continue;
      final updated = s.copyWith(
        isConfirmed: true,
        confirmedAt: now,
        updatedAt: now,
      );
      schedules[s.id] = updated;
      sample ??= updated;
      count++;
    }
    if (count == 0) return 0;

    notifyListeners();
    final ownerUid = rooms[roomId]?.ownerId;
    if (ownerUid != null &&
        sample != null &&
        prefsForRoom(roomId).notifyScheduleChanges) {
      AppNotificationDispatcher.scheduleConfirmed(
        ownerUid: ownerUid,
        staffDisplayName: user.displayName,
        storeId: roomId,
        scheduleId: sample.id,
        assignmentBatchId:
            sample.isPeriodBatch ? sample.assignmentBatchId : null,
      );
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // 근무 일정 변경 요청 (사장 → 직원 승인)
  // ---------------------------------------------------------------------------

  /// 해당 근무일에 출근·퇴근·근무 중 기록이 있으면 변경 불가
  bool hasAttendanceActivityForSchedule(ScheduleModel schedule) {
    final key = DateFormat('yyyy-MM-dd').format(schedule.startTime);
    final logs = attendanceForUser(schedule.roomId, schedule.workerId)
        .where((a) => DateFormat('yyyy-MM-dd').format(a.timestamp) == key);
    if (logs.isNotEmpty) return true;
    // 오늘 근무 중이면 오늘 스케줄도 잠금
    final todayKey = DateFormat('yyyy-MM-dd').format(KstDateTime.now());
    if (key == todayKey &&
        isWorkingToday(schedule.roomId, schedule.workerId)) {
      return true;
    }
    return false;
  }

  String? scheduleChangeBlockReason(ScheduleModel schedule) {
    if (schedule.isAbsent) {
      return '결근 처리된 근무는 일정 변경을 요청할 수 없습니다.';
    }
    if (schedule.isChangeRequested) {
      return '이미 변경 요청이 대기 중입니다. 직원 응답 후 다시 시도해 주세요.';
    }
    if (hasAttendanceActivityForSchedule(schedule)) {
      return '출퇴근이 진행·완료된 근무는 일정을 변경할 수 없습니다.';
    }
    return null;
  }

  bool canRequestScheduleChange(ScheduleModel schedule) =>
      scheduleChangeBlockReason(schedule) == null;

  List<ScheduleModel> pendingOwnerChangeRequestsForWorker(
    String roomId,
    String workerId,
  ) {
    return schedules.values
        .where(
          (s) =>
              s.roomId == roomId &&
              s.workerId == workerId &&
              s.status == ScheduleStatus.changeRequestedByOwner &&
              s.isChangeRequested,
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<ScheduleModel> pendingOwnerChangeRequestsForRoom(String roomId) {
    return schedules.values
        .where(
          (s) =>
              s.roomId == roomId &&
              s.status == ScheduleStatus.changeRequestedByOwner &&
              s.isChangeRequested,
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 직원이 보낸 일정 변경 요청 (사장 승인 대기)
  List<ScheduleModel> pendingStaffChangeRequestsForRoom(String roomId) {
    return schedules.values
        .where(
          (s) =>
              s.roomId == roomId &&
              s.status == ScheduleStatus.changeRequestedByStaff &&
              s.isChangeRequested,
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 알바 — 사장에게 일정 변경 요청 (이벤트 3)
  ScheduleModel requestScheduleChangeByStaff({
    required String scheduleId,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String reason,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }
    if (schedule.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 근무만 변경 요청할 수 있습니다.');
    }
    final block = scheduleChangeBlockReason(schedule);
    if (block != null) {
      throw RoomPermissionDeniedException(block);
    }
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const RoomPermissionDeniedException('변경 사유를 입력해 주세요.');
    }
    if (!newEndTime.isAfter(newStartTime)) {
      throw const InvalidScheduleTimeException();
    }

    final pending = PendingChange(
      startTime: newStartTime,
      endTime: newEndTime,
      reason: trimmed,
      requestedBy: user.uid,
      requestedAt: KstDateTime.now(),
      changeType: ScheduleChangeType.timeChange,
      status: ChangeRequestStatus.pending,
    );
    final updated = schedule.copyWith(
      status: ScheduleStatus.changeRequestedByStaff,
      pendingChange: pending,
      updatedAt: KstDateTime.now(),
    );
    schedules[scheduleId] = updated;
    notifyListeners();

    final ownerUid = rooms[schedule.roomId]?.ownerId;
    if (ownerUid != null &&
        prefsForRoom(schedule.roomId).notifyScheduleChanges) {
      AppNotificationDispatcher.scheduleChangeRequested(
        ownerUid: ownerUid,
        staffDisplayName: user.displayName,
        storeId: schedule.roomId,
        scheduleId: scheduleId,
      );
    }
    return updated;
  }

  /// 사장 — 알바 일정 변경 요청 승인/거절 (이벤트 4)
  ScheduleModel resolveStaffScheduleChange({
    required String scheduleId,
    required bool approve,
    String? rejectReason,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }
    final membership = getMembership(schedule.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('일정 변경을 처리할 권한이 없습니다.');
    }
    if (schedule.status != ScheduleStatus.changeRequestedByStaff) {
      throw const RoomPermissionDeniedException('직원 변경 요청이 없습니다.');
    }
    final pending = schedule.pendingChange;
    if (pending == null || !pending.isPending) {
      throw const RoomPermissionDeniedException('대기 중인 변경 요청이 없습니다.');
    }

    final now = KstDateTime.now();
    late ScheduleModel updated;
    if (approve) {
      final wage =
          getMembership(schedule.roomId, schedule.workerId)?.hourlyWage ??
              schedule.payEstimate?.hourlyWage ??
              10000;
      final estimate = PayrollCalculator.estimate(
        startTime: pending.startTime,
        endTime: pending.endTime,
        hourlyWage: wage,
        breakMinutes: PayrollCalculator.suggestedBreakMinutes(
          pending.endTime.difference(pending.startTime).inMinutes,
        ),
        includeWeeklyHoliday: schedule.includeWeeklyHoliday,
        includeOvertimeNight: schedule.includeOvertimeNight,
      );
      updated = schedule.copyWith(
        date: DateFormat('yyyy-MM-dd').format(pending.startTime),
        startTime: pending.startTime,
        endTime: pending.endTime,
        breakMinutes: estimate.breakMinutes,
        payEstimate: estimate,
        estimatedPay: estimate.total,
        basePay: estimate.basePay,
        weeklyHolidayPay: estimate.weeklyHolidayPay,
        overtimeNightPay: estimate.overtimeNightPay,
        status: ScheduleStatus.normal,
        clearPendingChange: true,
        reason: pending.reason,
        updatedAt: now,
      );
    } else {
      final reasonText = rejectReason?.trim();
      updated = schedule.copyWith(
        status: ScheduleStatus.normal,
        clearPendingChange: true,
        reason: reasonText != null && reasonText.isNotEmpty
            ? '거절: $reasonText'
            : '변경 요청 거절',
        updatedAt: now,
      );
    }
    schedules[scheduleId] = updated;
    notifyListeners();

    AppNotificationDispatcher.scheduleChangeResult(
      workerUid: schedule.workerId,
      approved: approve,
      storeId: schedule.roomId,
      scheduleId: scheduleId,
    );
    return updated;
  }

  /// 사장 — 직원에게 일정 변경 요청
  ScheduleModel requestScheduleChange({
    required String scheduleId,
    required ScheduleChangeType changeType,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String reason,
    String? substituteWorkerId,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }

    final membership = getMembership(schedule.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('일정 변경 요청 권한이 없습니다.');
    }

    final block = scheduleChangeBlockReason(schedule);
    if (block != null) {
      throw RoomPermissionDeniedException(block);
    }

    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const RoomPermissionDeniedException('변경 사유를 입력해 주세요.');
    }

    if (changeType != ScheduleChangeType.cancel) {
      if (!newEndTime.isAfter(newStartTime)) {
        throw const InvalidScheduleTimeException();
      }
    }

    if (changeType == ScheduleChangeType.substitute) {
      final subId = substituteWorkerId?.trim();
      if (subId == null || subId.isEmpty) {
        throw const RoomPermissionDeniedException('대체 직원을 선택해 주세요.');
      }
      final sub = getMembership(schedule.roomId, subId);
      if (sub == null || !sub.isActive || sub.role == MemberRole.owner) {
        throw const RoomPermissionDeniedException('유효한 대체 직원이 아닙니다.');
      }
      if (subId == schedule.workerId) {
        throw const RoomPermissionDeniedException('현재 근무자와 다른 직원을 선택해 주세요.');
      }
    }

    final pending = PendingChange(
      startTime: changeType == ScheduleChangeType.cancel
          ? schedule.startTime
          : newStartTime,
      endTime: changeType == ScheduleChangeType.cancel
          ? schedule.endTime
          : newEndTime,
      reason: trimmed,
      requestedBy: user.uid,
      requestedAt: KstDateTime.now(),
      changeType: changeType,
      status: ChangeRequestStatus.pending,
      substituteWorkerId: changeType == ScheduleChangeType.substitute
          ? substituteWorkerId
          : null,
    );

    final updated = schedule.copyWith(
      status: ScheduleStatus.changeRequestedByOwner,
      pendingChange: pending,
      updatedAt: KstDateTime.now(),
    );
    schedules[scheduleId] = updated;
    notifyListeners();

    final roomName = rooms[schedule.roomId]?.name ?? '매장';
    AppNotificationDispatcher.ownerScheduleChangeRequested(
      workerUid: schedule.workerId,
      storeName: roomName,
      storeId: schedule.roomId,
      scheduleId: scheduleId,
    );

    return updated;
  }

  /// 직원 — 변경 요청 수락 (스케줄·급여 즉시 반영)
  ScheduleModel acceptScheduleChange(String scheduleId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }
    if (schedule.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 근무 변경만 수락할 수 있습니다.');
    }
    final pending = schedule.pendingChange;
    if (pending == null || !pending.isPending) {
      throw const RoomPermissionDeniedException('대기 중인 변경 요청이 없습니다.');
    }
    if (schedule.status != ScheduleStatus.changeRequestedByOwner) {
      throw const RoomPermissionDeniedException('사장 변경 요청만 수락할 수 있습니다.');
    }

    final now = KstDateTime.now();
    final wage = getMembership(schedule.roomId, schedule.workerId)?.hourlyWage ??
        schedule.payEstimate?.hourlyWage ??
        10000;

    ScheduleModel updated;
    switch (pending.changeType) {
      case ScheduleChangeType.cancel:
        updated = schedule.copyWith(
          isAbsent: true,
          absentMarkedAt: now,
          absentMarkedBy: pending.requestedBy,
          status: ScheduleStatus.normal,
          clearPendingChange: true,
          reason: pending.reason,
          estimatedPay: 0,
          basePay: 0,
          weeklyHolidayPay: 0,
          overtimeNightPay: 0,
          updatedAt: now,
        );
      case ScheduleChangeType.substitute:
        final subId = pending.substituteWorkerId!;
        updated = schedule.copyWith(
          workerId: subId,
          status: ScheduleStatus.normal,
          clearPendingChange: true,
          reason: pending.reason,
          isConfirmed: false,
          confirmedAt: null,
          updatedAt: now,
        );
      case ScheduleChangeType.timeChange:
      case ScheduleChangeType.dateChange:
        final estimate = PayrollCalculator.estimate(
          startTime: pending.startTime,
          endTime: pending.endTime,
          hourlyWage: wage,
          breakMinutes: PayrollCalculator.suggestedBreakMinutes(
            pending.endTime.difference(pending.startTime).inMinutes,
          ),
          includeWeeklyHoliday: schedule.includeWeeklyHoliday,
          includeOvertimeNight: schedule.includeOvertimeNight,
        );
        updated = schedule.copyWith(
          date: DateFormat('yyyy-MM-dd').format(pending.startTime),
          startTime: pending.startTime,
          endTime: pending.endTime,
          breakMinutes: estimate.breakMinutes,
          payEstimate: estimate,
          estimatedPay: estimate.total,
          basePay: estimate.basePay,
          weeklyHolidayPay: estimate.weeklyHolidayPay,
          overtimeNightPay: estimate.overtimeNightPay,
          status: ScheduleStatus.normal,
          clearPendingChange: true,
          reason: pending.reason,
          updatedAt: now,
        );
    }

    schedules[scheduleId] = updated;
    notifyListeners();

    final ownerUid = rooms[schedule.roomId]?.ownerId;
    if (ownerUid != null &&
        prefsForRoom(schedule.roomId).notifyScheduleChanges) {
      AppNotificationDispatcher.staffScheduleChangeResult(
        ownerUid: ownerUid,
        staffDisplayName: user.displayName,
        approved: true,
        storeId: schedule.roomId,
        scheduleId: scheduleId,
      );
    }
    return updated;
  }

  /// 직원 — 변경 요청 거절 (스케줄 유지)
  ScheduleModel rejectScheduleChange(
    String scheduleId, {
    String? rejectReason,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }
    if (schedule.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 근무 변경만 거절할 수 있습니다.');
    }
    final pending = schedule.pendingChange;
    if (pending == null || !pending.isPending) {
      throw const RoomPermissionDeniedException('대기 중인 변경 요청이 없습니다.');
    }
    if (schedule.status != ScheduleStatus.changeRequestedByOwner) {
      throw const RoomPermissionDeniedException('사장 변경 요청만 거절할 수 있습니다.');
    }

    final now = KstDateTime.now();
    final reasonText = rejectReason?.trim();
    schedules[scheduleId] = schedule.copyWith(
      status: ScheduleStatus.normal,
      clearPendingChange: true,
      reason: reasonText != null && reasonText.isNotEmpty
          ? '거절: $reasonText'
          : '변경 요청 거절',
      updatedAt: now,
    );

    notifyListeners();

    final ownerUid = rooms[schedule.roomId]?.ownerId;
    if (ownerUid != null &&
        prefsForRoom(schedule.roomId).notifyScheduleChanges) {
      AppNotificationDispatcher.staffScheduleChangeResult(
        ownerUid: ownerUid,
        staffDisplayName: user.displayName,
        approved: false,
        storeId: schedule.roomId,
        scheduleId: scheduleId,
      );
    }
    return schedules[scheduleId]!;
  }

  /// 확인 대기 단위 수 — 기간 배정 묶음은 1건으로 집계
  int pendingConfirmUnitCount(String roomId, String workerId) {
    return pendingConfirmUnits(roomId, workerId).length;
  }

  /// 확인 대기 단위 목록 (기간 묶음 / 개별 일정)
  List<List<ScheduleModel>> pendingConfirmUnits(
    String roomId,
    String workerId,
  ) {
    final pending = pendingConfirmForWorker(roomId, workerId)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final units = <List<ScheduleModel>>[];
    final seenBatches = <String>{};

    for (final s in pending) {
      final batchId = s.assignmentBatchId;
      if (s.isPeriodBatch && batchId != null) {
        if (seenBatches.contains(batchId)) continue;
        seenBatches.add(batchId);
        final batch = pending
            .where((x) => x.assignmentBatchId == batchId)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        units.add(batch);
        continue;
      }
      units.add([s]);
    }
    return units;
  }

  /// 사장: 이 방의 직원에게 오늘 샘플 근무표 생성
  ScheduleModel? createDemoScheduleForFirstStaff(String roomId) {
    final staff = members.values
        .where(
          (m) =>
              m.roomId == roomId &&
              m.isActive &&
              m.role != MemberRole.owner,
        )
        .toList();
    if (staff.isEmpty) return null;

    final target = staff.first;
    return createSchedule(
      roomId: roomId,
      workerId: target.userId,
      startTime: DateTime(
        KstDateTime.now().year,
        KstDateTime.now().month,
        KstDateTime.now().day,
        10,
      ),
      endTime: DateTime(
        KstDateTime.now().year,
        KstDateTime.now().month,
        KstDateTime.now().day,
        19,
      ),
      note: '목업 작성 근무표',
      hourlyWage: target.hourlyWage ?? 10000,
    );
  }

  List<ScheduleModel> schedulesForRoom(String roomId) {
    final list =
        schedules.values.where((s) => s.roomId == roomId).toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  List<ScheduleModel> schedulesForWorker(String roomId, String workerId) {
    final list = schedules.values
        .where((s) => s.roomId == roomId && s.workerId == workerId)
        .toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  List<ScheduleModel> pendingConfirmForWorker(String roomId, String workerId) {
    return schedulesForWorker(roomId, workerId)
        .where((s) => !s.isConfirmed && !s.isAbsent)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 대타 (Shift Swap)
  // ---------------------------------------------------------------------------

  List<ShiftSwapRequest> shiftSwapsForRoom(String roomId) {
    final list =
        shiftSwaps.values.where((s) => s.roomId == roomId).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(0))
        .compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  List<ShiftSwapRequest> openShiftSwapsForRoom(String roomId) =>
      shiftSwapsForRoom(roomId).where((s) => s.status.isOpen).toList();

  /// 나에게 들어온 대타 요청 (동료 수락 대기만)
  List<ShiftSwapRequest> incomingShiftSwapsForWorker(
    String roomId,
    String userId,
  ) {
    return shiftSwapsForRoom(roomId)
        .where(
          (s) =>
              s.toWorkerId == userId &&
              s.status == ShiftSwapStatus.pendingColleague,
        )
        .toList();
  }

  ShiftSwapRequest? openSwapForSchedule(String scheduleId) {
    for (final s in shiftSwaps.values) {
      if (s.scheduleId == scheduleId && s.status.isOpen) return s;
    }
    return null;
  }

  /// 직원이 본인 근무에 대타 요청 (동료 수락 → 사장 승인 2단계)
  ShiftSwapRequest requestShiftSwap({
    required String scheduleId,
    required String toWorkerId,
    required String reason,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final schedule = schedules[scheduleId];
    if (schedule == null) {
      throw StateError('근무표를 찾을 수 없습니다.');
    }
    if (schedule.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 근무만 대타 요청할 수 있습니다.');
    }
    if (toWorkerId == user.uid) {
      throw const RoomPermissionDeniedException('본인을 대타로 지정할 수 없습니다.');
    }
    if (getMembership(schedule.roomId, toWorkerId) == null) {
      throw const RoomPermissionDeniedException('같은 매장 직원만 지정할 수 있습니다.');
    }
    if (openSwapForSchedule(scheduleId) != null) {
      throw const RoomPermissionDeniedException('이미 진행 중인 대타 요청이 있습니다.');
    }
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const RoomPermissionDeniedException('대타 사유를 입력해 주세요.');
    }

    final id = _uuid.v4();
    final req = ShiftSwapRequest(
      id: id,
      roomId: schedule.roomId,
      scheduleId: scheduleId,
      fromWorkerId: user.uid,
      toWorkerId: toWorkerId,
      reason: trimmed,
      status: ShiftSwapStatus.pendingColleague,
      createdAt: KstDateTime.now(),
    );
    shiftSwaps[id] = req;
    notifyListeners();

    // 5-1) 대타 요청 → 동료 B
    AppNotificationDispatcher.swapRequested(
      toWorkerUid: toWorkerId,
      fromDisplayName: user.displayName,
      storeId: schedule.roomId,
      swapId: id,
      scheduleId: scheduleId,
    );

    return req;
  }

  /// 대타 대상 동료가 수락 → 사장 승인 대기로 전환
  ShiftSwapRequest acceptShiftSwapAsColleague(String swapId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final req = shiftSwaps[swapId];
    if (req == null) throw StateError('대타 요청을 찾을 수 없습니다.');
    if (req.toWorkerId != user.uid) {
      throw const RoomPermissionDeniedException('지정된 동료만 수락할 수 있습니다.');
    }
    if (req.status != ShiftSwapStatus.pendingColleague) {
      throw const RoomPermissionDeniedException('수락할 수 있는 상태가 아닙니다.');
    }

    final updated = req.copyWith(status: ShiftSwapStatus.pendingOwner);
    shiftSwaps[swapId] = updated;
    notifyListeners();

    // 5-2) 동료 수락 → 사장
    final room = rooms[req.roomId];
    final ownerUid = room?.ownerId;
    if (ownerUid != null &&
        prefsForRoom(req.roomId).notifyScheduleChanges) {
      AppNotificationDispatcher.swapColleagueAccepted(
        ownerUid: ownerUid,
        storeName: room?.name ?? '매장',
        fromName: memberDisplayName(req.roomId, req.fromWorkerId),
        toName: memberDisplayName(req.roomId, req.toWorkerId),
        storeId: req.roomId,
        swapId: swapId,
      );
    }

    return updated;
  }

  /// 대타 대상 동료가 거절 — 기존 근무자 유지
  ShiftSwapRequest rejectShiftSwapAsColleague(String swapId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final req = shiftSwaps[swapId];
    if (req == null) throw StateError('대타 요청을 찾을 수 없습니다.');
    if (req.toWorkerId != user.uid) {
      throw const RoomPermissionDeniedException('지정된 동료만 거절할 수 있습니다.');
    }
    if (req.status != ShiftSwapStatus.pendingColleague) {
      throw const RoomPermissionDeniedException('거절할 수 있는 상태가 아닙니다.');
    }

    final updated = req.copyWith(
      status: ShiftSwapStatus.rejected,
      resolvedAt: KstDateTime.now(),
    );
    shiftSwaps[swapId] = updated;
    notifyListeners();

    AppNotificationDispatcher.swapColleagueRejected(
      fromWorkerUid: req.fromWorkerId,
      toDisplayName: user.displayName,
      storeId: req.roomId,
      swapId: swapId,
    );

    return updated;
  }

  /// 사장 최종 승인 — 근무자 교체
  ShiftSwapRequest approveShiftSwap(String swapId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final req = shiftSwaps[swapId];
    if (req == null) throw StateError('대타 요청을 찾을 수 없습니다.');

    final membership = getMembership(req.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('사장/매니저만 승인할 수 있습니다.');
    }
    if (!req.status.isOpen) {
      throw const RoomPermissionDeniedException('이미 처리된 요청입니다.');
    }

    final schedule = schedules[req.scheduleId];
    if (schedule == null) throw StateError('근무표를 찾을 수 없습니다.');

    final fromName = memberDisplayName(req.roomId, req.fromWorkerId);
    schedules[req.scheduleId] = schedule.copyWith(
      workerId: req.toWorkerId,
      isConfirmed: false,
      confirmedAt: null,
      note: '대타 승인 · 요청자 $fromName · 사유: ${req.reason}',
      updatedAt: KstDateTime.now(),
    );

    final updated = req.copyWith(
      status: ShiftSwapStatus.approved,
      resolvedAt: KstDateTime.now(),
    );
    shiftSwaps[swapId] = updated;
    notifyListeners();

    // 5-3) 사장 최종 승인 → A, B
    final roomName = rooms[req.roomId]?.name ?? '매장';
    AppNotificationDispatcher.swapOwnerApproved(
      fromWorkerUid: req.fromWorkerId,
      toWorkerUid: req.toWorkerId,
      storeName: roomName,
      storeId: req.roomId,
      swapId: swapId,
    );

    return updated;
  }

  /// 사장 거절 — 기존 근무자 유지
  ShiftSwapRequest rejectShiftSwap(String swapId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final req = shiftSwaps[swapId];
    if (req == null) throw StateError('대타 요청을 찾을 수 없습니다.');

    final membership = getMembership(req.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('사장/매니저만 거절할 수 있습니다.');
    }
    if (!req.status.isOpen) {
      throw const RoomPermissionDeniedException('이미 처리된 요청입니다.');
    }

    final updated = req.copyWith(
      status: ShiftSwapStatus.rejected,
      resolvedAt: KstDateTime.now(),
    );
    shiftSwaps[swapId] = updated;
    notifyListeners();

    final roomName = rooms[req.roomId]?.name ?? '매장';
    AppNotificationDispatcher.swapOwnerRejected(
      fromWorkerUid: req.fromWorkerId,
      toWorkerUid: req.toWorkerId,
      storeName: roomName,
      storeId: req.roomId,
      swapId: swapId,
    );

    return updated;
  }

  // ---------------------------------------------------------------------------
  // 매장 공지
  // ---------------------------------------------------------------------------

  List<NoticeModel> noticesForRoom(String roomId) {
    // 사장이 직접 작성한 공지만 (시스템·데모 제외)
    final list = notices.values
        .where((n) => n.roomId == roomId && n.authorId != 'system')
        .where((n) => !n.id.startsWith('demo_notice'))
        .toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(0))
        .compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  int unreadNoticeCount(String roomId, String userId) =>
      noticesForRoom(roomId).where((n) => !n.isReadBy(userId)).length;

  NoticeModel createNotice({
    required String roomId,
    required String title,
    required String body,
    bool isImportant = false,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('사장/매니저만 공지를 작성할 수 있습니다.');
    }
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty || b.isEmpty) {
      throw const RoomPermissionDeniedException('제목과 내용을 입력해 주세요.');
    }

    final id = _uuid.v4();
    final notice = NoticeModel(
      id: id,
      roomId: roomId,
      authorId: user.uid,
      authorName: '사장님',
      title: t,
      body: b,
      isImportant: isImportant,
      createdAt: KstDateTime.now(),
    );
    notices[id] = notice;
    notifyListeners();

    // 8) 매장 공지 → 전 직원
    final roomName = rooms[roomId]?.name ?? '매장';
    final staffUids = members.values
        .where(
          (m) =>
              m.roomId == roomId &&
              m.isActive &&
              m.userId != user.uid &&
              m.role != MemberRole.owner,
        )
        .map((m) => m.userId);
    AppNotificationDispatcher.storeNotice(
      staffUids: staffUids,
      storeName: roomName,
      storeId: roomId,
      noticeId: id,
    );

    return notice;
  }

  void deleteNotice(String noticeId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final notice = notices[noticeId];
    if (notice == null) return;

    final membership = getMembership(notice.roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('사장/매니저만 공지를 삭제할 수 있습니다.');
    }
    notices.remove(noticeId);
    notifyListeners();
  }

  void markNoticeRead(String noticeId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final notice = notices[noticeId];
    if (notice == null) return;
    if (notice.isReadBy(user.uid)) return;

    notices[noticeId] = notice.copyWith(
      readByUserIds: {...notice.readByUserIds, user.uid},
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 출퇴근 (목업 — GPS/DB 없이 즉시 기록)
  // ---------------------------------------------------------------------------

  AttendanceLogModel clockIn({
    required String roomId,
    GeoLocation? location,
    double distanceFromStoreMeters = 0,
  }) {
    return _clock(
      roomId: roomId,
      type: AttendanceType.clockIn,
      location: location,
      distanceFromStoreMeters: distanceFromStoreMeters,
    );
  }

  AttendanceLogModel clockOut({
    required String roomId,
    GeoLocation? location,
    double distanceFromStoreMeters = 0,
  }) {
    return _clock(
      roomId: roomId,
      type: AttendanceType.clockOut,
      location: location,
      distanceFromStoreMeters: distanceFromStoreMeters,
    );
  }

  AttendanceLogModel _clock({
    required String roomId,
    required AttendanceType type,
    GeoLocation? location,
    double distanceFromStoreMeters = 0,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final room = rooms[roomId];
    if (room == null) throw const RoomNotFoundException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.isActive) {
      throw const RoomPermissionDeniedException();
    }

    if (!hasConfirmedTodaySchedule(roomId, user.uid)) {
      throw const RoomPermissionDeniedException(
        '배정된 근무를 확인한 뒤에만 출퇴근할 수 있습니다.',
      );
    }

    final todaySchedule = todayScheduleForWorker(roomId, user.uid);
    if (todaySchedule?.isAbsent == true) {
      throw const RoomPermissionDeniedException(
        '결근 처리된 근무는 출퇴근할 수 없습니다.',
      );
    }

    // 멱등: 동일 유형 중복 기록 방지
    if (type == AttendanceType.clockIn &&
        todayClockIn(roomId, user.uid) != null &&
        todayClockOut(roomId, user.uid) == null) {
      throw const RoomPermissionDeniedException('이미 출근 처리되었습니다.');
    }
    if (type == AttendanceType.clockOut) {
      if (todayClockIn(roomId, user.uid) == null) {
        throw const RoomPermissionDeniedException('출근 기록이 없습니다.');
      }
      if (todayClockOut(roomId, user.uid) != null) {
        throw const RoomPermissionDeniedException('이미 퇴근 처리되었습니다.');
      }
    }

    final id = _uuid.v4();
    final now = KstDateTime.now();
    final log = AttendanceLogModel(
      id: id,
      roomId: roomId,
      userId: user.uid,
      type: type,
      timestamp: now,
      location: location ??
          GeoLocation(
            latitude: room.location.latitude,
            longitude: room.location.longitude,
            isMocked: gpsBypassEnabled,
          ),
      distanceFromStoreMeters: distanceFromStoreMeters,
      isValid: true,
      scheduleId: todaySchedule?.id,
      createdAt: now,
    );
    attendanceLogs[id] = log;
    notifyListeners();

    // 6) 출·퇴근 → 사장 (설정 on 일 때)
    final prefs = prefsForRoom(roomId);
    if (prefs.notifyAttendance && room.ownerId != user.uid) {
      AppNotificationDispatcher.attendance(
        ownerUid: room.ownerId,
        staffDisplayName: user.displayName,
        isClockIn: type == AttendanceType.clockIn,
        storeId: roomId,
        workerUid: user.uid,
      );
    }

    return log;
  }

  // ---------------------------------------------------------------------------
  // 근태 수정 요청 (사장 → 알바 상호 승인)
  // ---------------------------------------------------------------------------

  List<CommuteCorrectionRequest> pendingCorrectionsForWorker(String workerId) {
    return commuteCorrections.values
        .where(
          (r) =>
              r.workerId == workerId &&
              r.status == CommuteCorrectionStatus.pending,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  CommuteCorrectionRequest? pendingCorrectionForWorkerToday({
    required String roomId,
    required String workerId,
  }) {
    final today = KstDateTime.today();
    for (final r in commuteCorrections.values) {
      if (r.roomId != roomId || r.workerId != workerId) continue;
      if (r.status != CommuteCorrectionStatus.pending) continue;
      final d = r.createdAt;
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        return r;
      }
    }
    return null;
  }

  CommuteCorrectionRequest? commuteCorrectionById(String id) =>
      commuteCorrections[id];

  /// 사장 — 즉시 반영 없이 pending 요청 생성
  CommuteCorrectionRequest requestCommuteCorrection({
    required String roomId,
    required String workerId,
    required CommuteCorrectionIntent intent,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    String reason = '',
    String? scheduleId,
  }) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final membership = getMembership(roomId, user.uid);
    if (membership == null || !membership.role.canManageSchedules) {
      throw const RoomPermissionDeniedException('근태를 수정할 권한이 없습니다.');
    }

    final existing = pendingCorrectionForWorkerToday(
      roomId: roomId,
      workerId: workerId,
    );
    if (existing != null) {
      throw const RoomPermissionDeniedException(
        '이미 승인 대기 중인 근태 수정 요청이 있습니다.',
      );
    }

    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const RoomPermissionDeniedException('수정 사유를 입력해 주세요.');
    }

    final schedule =
        scheduleId != null ? schedules[scheduleId] : todayScheduleForWorker(roomId, workerId);
    final clockIn = todayClockIn(roomId, workerId);
    final clockOut = todayClockOut(roomId, workerId);

    final id = _uuid.v4();
    final req = CommuteCorrectionRequest(
      id: id,
      roomId: roomId,
      workerId: workerId,
      requestedBy: user.uid,
      scheduleId: schedule?.id,
      intent: intent,
      status: CommuteCorrectionStatus.pending,
      originalClockIn: clockIn?.timestamp,
      originalClockOut: clockOut?.timestamp,
      proposedClockIn: proposedClockIn,
      proposedClockOut: proposedClockOut,
      reason: trimmed,
      createdAt: KstDateTime.now(),
    );
    commuteCorrections[id] = req;
    notifyListeners();

    final roomName = rooms[roomId]?.name ?? '매장';
    AppNotificationDispatcher.commuteCorrectionRequested(
      workerUid: workerId,
      storeName: roomName,
      storeId: roomId,
      requestId: id,
    );

    return req;
  }

  /// 알바 — 근태 수정 승인 → 실제 기록 반영
  CommuteCorrectionRequest approveCommuteCorrection(String requestId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final req = commuteCorrections[requestId];
    if (req == null) throw StateError('근태 수정 요청을 찾을 수 없습니다.');
    if (req.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 요청만 승인할 수 있습니다.');
    }
    if (req.status != CommuteCorrectionStatus.pending) {
      throw const RoomPermissionDeniedException('이미 처리된 요청입니다.');
    }

    _applyCommuteCorrection(req);

    final updated = req.copyWith(
      status: CommuteCorrectionStatus.approved,
      resolvedAt: KstDateTime.now(),
    );
    commuteCorrections[requestId] = updated;
    notifyListeners();

    final room = rooms[req.roomId];
    final ownerUid = room?.ownerId;
    if (ownerUid != null) {
      AppNotificationDispatcher.commuteCorrectionResult(
        ownerUid: ownerUid,
        staffDisplayName: memberDisplayName(req.roomId, req.workerId),
        approved: true,
        storeId: req.roomId,
        requestId: requestId,
      );
    }
    return updated;
  }

  /// 알바 — 거절 (기록 유지)
  CommuteCorrectionRequest rejectCommuteCorrection(String requestId) {
    final user = _session.currentUser;
    if (user == null) throw const NotAuthenticatedException();

    final req = commuteCorrections[requestId];
    if (req == null) throw StateError('근태 수정 요청을 찾을 수 없습니다.');
    if (req.workerId != user.uid) {
      throw const RoomPermissionDeniedException('본인 요청만 거절할 수 있습니다.');
    }
    if (req.status != CommuteCorrectionStatus.pending) {
      throw const RoomPermissionDeniedException('이미 처리된 요청입니다.');
    }

    final updated = req.copyWith(
      status: CommuteCorrectionStatus.rejected,
      resolvedAt: KstDateTime.now(),
    );
    commuteCorrections[requestId] = updated;
    notifyListeners();

    final room = rooms[req.roomId];
    final ownerUid = room?.ownerId;
    if (ownerUid != null) {
      AppNotificationDispatcher.commuteCorrectionResult(
        ownerUid: ownerUid,
        staffDisplayName: memberDisplayName(req.roomId, req.workerId),
        approved: false,
        storeId: req.roomId,
        requestId: requestId,
      );
    }
    return updated;
  }

  void _applyCommuteCorrection(CommuteCorrectionRequest req) {
    final room = rooms[req.roomId];
    if (room == null) return;

    if (req.intent == CommuteCorrectionIntent.absent) {
      final sid = req.scheduleId ??
          todayScheduleForWorker(req.roomId, req.workerId)?.id;
      if (sid != null) {
        final s = schedules[sid];
        if (s != null && !s.isAbsent) {
          schedules[sid] = s.copyWith(
            isAbsent: true,
            absentMarkedAt: KstDateTime.now(),
            absentMarkedBy: req.requestedBy,
            updatedAt: KstDateTime.now(),
          );
        }
      }
      return;
    }

    // 결근 해제
    final sid =
        req.scheduleId ?? todayScheduleForWorker(req.roomId, req.workerId)?.id;
    if (sid != null) {
      final s = schedules[sid];
      if (s != null && s.isAbsent) {
        schedules[sid] = s.copyWith(
          clearAbsent: true,
          updatedAt: KstDateTime.now(),
        );
      }
    }

    void upsertLog(AttendanceType type, DateTime? ts) {
      if (ts == null) return;
      final existing = type == AttendanceType.clockIn
          ? todayClockIn(req.roomId, req.workerId)
          : todayClockOut(req.roomId, req.workerId);
      if (existing != null) {
        attendanceLogs[existing.id] = existing.copyWith(
          timestamp: ts,
          scheduleId: sid,
        );
      } else {
        final id = _uuid.v4();
        attendanceLogs[id] = AttendanceLogModel(
          id: id,
          roomId: req.roomId,
          userId: req.workerId,
          type: type,
          timestamp: ts,
          location: GeoLocation(
            latitude: room.location.latitude,
            longitude: room.location.longitude,
            isMocked: true,
          ),
          distanceFromStoreMeters: 0,
          isValid: true,
          scheduleId: sid,
          createdAt: KstDateTime.now(),
        );
      }
    }

    if (req.intent == CommuteCorrectionIntent.manualClockOut) {
      upsertLog(AttendanceType.clockOut, req.proposedClockOut);
    } else {
      upsertLog(AttendanceType.clockIn, req.proposedClockIn);
      upsertLog(AttendanceType.clockOut, req.proposedClockOut);
    }
  }

  /// 오늘 배정된 근무 목록 (직원 중복 시 가장 이른 시작)
  List<ScheduleModel> todayAssignedSchedules(String roomId) {
    final key = KstDateTime.todayKey();
    final list = schedules.values
        .where((s) => s.roomId == roomId && s.date == key)
        .toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  List<AttendanceLogModel> attendanceForRoom(String roomId) {
    final list =
        attendanceLogs.values.where((a) => a.roomId == roomId).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<AttendanceLogModel> attendanceForUser(String roomId, String userId) {
    final list = attendanceLogs.values
        .where((a) => a.roomId == roomId && a.userId == userId)
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  AttendanceLogModel? latestAttendanceToday(String roomId, String userId) {
    final today = DateFormat('yyyy-MM-dd').format(KstDateTime.now());
    final logs = attendanceForUser(roomId, userId).where((a) {
      return DateFormat('yyyy-MM-dd').format(a.timestamp) == today;
    });
    return logs.isEmpty ? null : logs.first;
  }

  List<AttendanceLogModel> attendanceToday(String roomId, String userId) {
    final today = DateFormat('yyyy-MM-dd').format(KstDateTime.now());
    return attendanceForUser(roomId, userId)
        .where((a) => DateFormat('yyyy-MM-dd').format(a.timestamp) == today)
        .toList();
  }

  AttendanceLogModel? todayClockIn(String roomId, String userId) {
    final logs = attendanceToday(roomId, userId)
        .where((a) => a.type == AttendanceType.clockIn);
    return logs.isEmpty ? null : logs.first; // 최신 출근 (재출근 반영)
  }

  AttendanceLogModel? todayClockOut(String roomId, String userId) {
    final logs = attendanceToday(roomId, userId)
        .where((a) => a.type == AttendanceType.clockOut);
    return logs.isEmpty ? null : logs.first; // 최신 퇴근
  }

  /// 오늘 근무 중인지 (마지막 기록이 출근이면 true → 재퇴근 대기)
  bool isWorkingToday(String roomId, String userId) {
    final latest = latestAttendanceToday(roomId, userId);
    return latest?.type == AttendanceType.clockIn;
  }

  /// 오늘 퇴근을 한 번이라도 했는지 (재출근·재퇴근 문구용)
  bool hasClockedOutToday(String roomId, String userId) {
    return attendanceToday(roomId, userId)
        .any((a) => a.type == AttendanceType.clockOut);
  }

  /// 해당 날짜에 퇴근 기록이 있는지 (내 근무표 일급여 표시용)
  bool hasClockedOutOnDate(String roomId, String userId, DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return attendanceForUser(roomId, userId).any(
      (a) =>
          a.type == AttendanceType.clockOut &&
          DateFormat('yyyy-MM-dd').format(a.timestamp) == key,
    );
  }

  /// 해당 날짜의 실제 출근~퇴근 구간 (재출근 구간 포함)
  List<({DateTime start, DateTime end})> workedIntervalsOnDate(
    String roomId,
    String userId,
    DateTime day,
  ) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final logs = attendanceForUser(roomId, userId)
        .where((a) => DateFormat('yyyy-MM-dd').format(a.timestamp) == key)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final intervals = <({DateTime start, DateTime end})>[];
    DateTime? openIn;
    for (final log in logs) {
      if (log.type == AttendanceType.clockIn) {
        openIn = log.timestamp;
      } else if (log.type == AttendanceType.clockOut && openIn != null) {
        if (log.timestamp.isAfter(openIn)) {
          intervals.add((start: openIn, end: log.timestamp));
        }
        openIn = null;
      }
    }
    return intervals;
  }

  /// 실제 출퇴근 시간 기준 급여 산정 (배정 시간이 아닌 실근무)
  PayEstimate? actualPayEstimateOnDate(
    String roomId,
    String userId,
    DateTime day,
  ) {
    final intervals = workedIntervalsOnDate(roomId, userId, day);
    if (intervals.isEmpty) return null;

    final dayKey = DateFormat('yyyy-MM-dd').format(day);
    final daySchedules = schedulesForWorker(roomId, userId)
        .where((s) => s.date == dayKey && !s.isAbsent)
        .toList();
    // 배정 근무가 없으면(또는 전부 결근) 실근무 급여 미산정
    if (daySchedules.isEmpty) return null;

    final wage = getMembership(roomId, userId)?.hourlyWage ?? 10000;
    final includeWeekly =
        daySchedules.any((s) => s.includeWeeklyHoliday);
    final includeOt =
        daySchedules.any((s) => s.includeOvertimeNight);

    var basePay = 0;
    var weeklyHolidayPay = 0;
    var overtimeNightPay = 0;
    var totalWorkedMinutes = 0;
    var breakMinutes = 0;
    var netWorkedMinutes = 0;
    var overtimeMinutes = 0;
    var nightMinutes = 0;

    for (final iv in intervals) {
      final worked = iv.end.difference(iv.start).inMinutes;
      final br = PayrollCalculator.suggestedBreakMinutes(worked);
      final e = PayrollCalculator.estimate(
        startTime: iv.start,
        endTime: iv.end,
        hourlyWage: wage,
        breakMinutes: br,
        includeWeeklyHoliday: includeWeekly,
        includeOvertimeNight: includeOt,
      );
      basePay += e.basePay;
      weeklyHolidayPay += e.weeklyHolidayPay;
      overtimeNightPay += e.overtimeNightPay;
      totalWorkedMinutes += e.totalWorkedMinutes;
      breakMinutes += e.breakMinutes;
      netWorkedMinutes += e.netWorkedMinutes;
      overtimeMinutes += e.overtimeMinutes;
      nightMinutes += e.nightMinutes;
    }

    return PayEstimate(
      hourlyWage: wage,
      totalWorkedMinutes: totalWorkedMinutes,
      breakMinutes: breakMinutes,
      netWorkedMinutes: netWorkedMinutes,
      basePay: basePay,
      weeklyHolidayPay: weeklyHolidayPay,
      overtimeNightPay: overtimeNightPay,
      includeWeeklyHoliday: includeWeekly,
      includeOvertimeNight: includeOt,
      overtimeMinutes: overtimeMinutes,
      nightMinutes: nightMinutes,
    );
  }

  /// 실제 출퇴근 기준 일급여 (없으면 0)
  int actualPayOnDate(String roomId, String userId, DateTime day) {
    return actualPayEstimateOnDate(roomId, userId, day)?.total ?? 0;
  }

  /// 실근무 급여 합계 (퇴근한 날만)
  int actualPayTotalForWorker(String roomId, String userId) {
    final dates = <String>{};
    for (final a in attendanceForUser(roomId, userId)) {
      if (a.type != AttendanceType.clockOut) continue;
      dates.add(DateFormat('yyyy-MM-dd').format(a.timestamp));
    }
    var total = 0;
    for (final key in dates) {
      final parts = key.split('-');
      if (parts.length != 3) continue;
      total += actualPayOnDate(
        roomId,
        userId,
        DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
      );
    }
    return total;
  }

  /// 오늘 배정된 근무(가장 이른 1건). 없으면 null
  ScheduleModel? todayScheduleForWorker(String roomId, String workerId) {
    final today = DateFormat('yyyy-MM-dd').format(KstDateTime.now());
    final list = schedulesForWorker(roomId, workerId)
        .where((s) => s.date == today)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return list.isEmpty ? null : list.first;
  }

  /// 오늘 배정 근무를 직원이 확인했는지 (출퇴근 허용 조건)
  bool hasConfirmedTodaySchedule(String roomId, String workerId) {
    final s = todayScheduleForWorker(roomId, workerId);
    return s != null && s.isConfirmed;
  }

  /// 확인된 스케줄 기준 예상 급여 합계
  int estimatedPayForWorker(String roomId, String workerId, int hourlyWage) {
    var total = 0;
    for (final s in schedulesForWorker(roomId, workerId)) {
      if (!s.isConfirmed) continue;
      total += s.estimatedPay ??
          PayrollCalculator.estimatePay(
            startTime: s.startTime,
            endTime: s.endTime,
            hourlyWage: hourlyWage,
          );
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // 조회
  // ---------------------------------------------------------------------------

  List<RoomMembershipEntry> myRoomEntries() {
    final uid = _session.currentUser?.uid;
    if (uid == null) return const [];

    final entries = <RoomMembershipEntry>[];
    for (final m in members.values) {
      if (m.userId != uid || !m.isActive) continue;
      final room = rooms[m.roomId];
      if (room == null) continue;
      entries.add(RoomMembershipEntry(room: room, membership: m));
    }
    entries.sort((a, b) {
      if (a.isOwnedByMe != b.isOwnedByMe) {
        return a.isOwnedByMe ? -1 : 1;
      }
      return a.room.name.compareTo(b.room.name);
    });
    return entries;
  }

  RoomMembershipEntry? roomEntry(String roomId) {
    final uid = _session.currentUser?.uid;
    if (uid == null) return null;
    final m = getMembership(roomId, uid);
    if (m == null || !m.isActive) return null;
    final room = rooms[roomId];
    if (room == null) return null;
    return RoomMembershipEntry(room: room, membership: m);
  }

  RoomMemberModel? getMembership(String roomId, String userId) {
    return members[_memberKey(roomId, userId)];
  }

  List<RoomMemberModel> activeMembers(String roomId) {
    return members.values
        .where((m) => m.roomId == roomId && m.isActive)
        .toList();
  }

  /// 직원만 (사장/owner 역할 제외)
  List<RoomMemberModel> activeStaffMembers(String roomId) {
    return activeMembers(roomId)
        .where((m) => m.role != MemberRole.owner)
        .toList();
  }

  int staffCount(String roomId) => activeStaffMembers(roomId).length;

  List<RoomInviteModel> activeInvitesForRoom(String roomId) {
    return invites.values
        .where((i) => i.roomId == roomId && i.canBeUsed)
        .toList();
  }

  List<RoomInviteModel> joinableInvites() {
    final uid = _session.currentUser?.uid;
    return invites.values.where((i) {
      if (!i.canBeUsed) return false;
      final room = rooms[i.roomId];
      if (room == null) return false;
      if (uid != null && room.ownerId == uid) return false;
      final already =
          uid != null && getMembership(i.roomId, uid)?.isActive == true;
      return !already;
    }).toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
  }

  List<RoomInviteModel> allActiveInvites() => joinableInvites();

  String _memberKey(String roomId, String userId) => '${roomId}_$userId';

  /// 전역 유일 숫자 초대 코드 (활성·비활성·모든 매장 포함해 중복 금지)
  String _generateGloballyUniqueNumericCode({int length = 8}) {
    for (var attempt = 0; attempt < 64; attempt++) {
      final code = List.generate(
        length,
        (_) => _random.nextInt(10).toString(),
      ).join();
      if (!_isInviteCodeTaken(code)) return code;
    }
    throw StateError('초대 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }

  /// 어떤 매장이든 이미 쓰인 코드인지 (비활성 포함)
  bool _isInviteCodeTaken(String code) {
    return invites.values.any((i) => i.code == code);
  }
}

/// 매장 사장 설정 — 시급·수당·알림
class RoomOwnerPrefs {
  const RoomOwnerPrefs({
    required this.defaultHourlyWage,
    required this.includeWeeklyHoliday,
    required this.includeOvertimeNight,
    required this.notifyScheduleChanges,
    required this.notifyAttendance,
  });

  factory RoomOwnerPrefs.newDefaults() => const RoomOwnerPrefs(
        defaultHourlyWage: AppConstants.minimumHourlyWage,
        includeWeeklyHoliday: true,
        includeOvertimeNight: true,
        notifyScheduleChanges: true,
        notifyAttendance: true,
      );

  final int defaultHourlyWage;
  final bool includeWeeklyHoliday;
  final bool includeOvertimeNight;
  final bool notifyScheduleChanges;
  final bool notifyAttendance;

  RoomOwnerPrefs copyWith({
    int? defaultHourlyWage,
    bool? includeWeeklyHoliday,
    bool? includeOvertimeNight,
    bool? notifyScheduleChanges,
    bool? notifyAttendance,
  }) {
    return RoomOwnerPrefs(
      defaultHourlyWage: defaultHourlyWage ?? this.defaultHourlyWage,
      includeWeeklyHoliday: includeWeeklyHoliday ?? this.includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight ?? this.includeOvertimeNight,
      notifyScheduleChanges:
          notifyScheduleChanges ?? this.notifyScheduleChanges,
      notifyAttendance: notifyAttendance ?? this.notifyAttendance,
    );
  }
}
