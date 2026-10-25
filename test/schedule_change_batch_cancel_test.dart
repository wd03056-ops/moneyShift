import 'package:flutter_test/flutter_test.dart';
import 'package:money_shift/mock/mock_session.dart';
import 'package:money_shift/mock/mock_store.dart';
import 'package:money_shift/mock/mock_user.dart';
import 'package:money_shift/models/enums/schedule_change_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStore store;

  setUp(() {
    store = MockStore.instance;
    store.resetAll();
    MockSession.instance.loginAs(MockUser.owner);
  });

  tearDown(() {
    MockSession.instance.logout();
  });

  test('기간 배정 중 하루 취소 수락해도 나머지 배정은 유지된다', () {
    final room = store.rooms.values.first;
    final staffUid = MockUser.staff.uid;

    final now = DateTime.now();
    final y = now.month == 12 ? now.year + 1 : now.year;
    final m = now.month == 12 ? 1 : now.month + 1;
    final dates = [for (var d = 1; d <= 10; d++) DateTime(y, m, d)];

    final created = store.createSchedulesForDates(
      roomId: room.id,
      workerId: staffUid,
      dates: dates,
      startHour: 9,
      startMinute: 0,
      endHour: 18,
      endMinute: 0,
      note: '기간 테스트',
      asPeriod: true,
    );
    expect(created.length, 10);
    final batchId = created.first.assignmentBatchId;
    expect(batchId, isNotNull);

    final cancelTarget = created[1];

    store.requestScheduleChange(
      scheduleId: cancelTarget.id,
      changeType: ScheduleChangeType.cancel,
      newStartTime: cancelTarget.startTime,
      newEndTime: cancelTarget.endTime,
      reason: '하루 휴무',
    );

    MockSession.instance.loginAs(MockUser.staff);
    store.acceptScheduleChange(cancelTarget.id);

    expect(store.schedules.containsKey(cancelTarget.id), isFalse);

    final batchLeft = store
        .schedulesForWorker(room.id, staffUid)
        .where((s) => s.assignmentBatchId == batchId)
        .toList();
    expect(batchLeft.length, 9);
    expect(batchLeft.every((s) => !s.isAbsent), isTrue);
    expect(
      store
          .pendingConfirmForWorker(room.id, staffUid)
          .where((s) => s.assignmentBatchId == batchId)
          .length,
      9,
    );
  });
}
