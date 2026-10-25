import 'package:flutter_test/flutter_test.dart';
import 'package:money_shift/features/notifications/data/mock_notification_repository.dart';
import 'package:money_shift/features/notifications/domain/notification_dedupe.dart';
import 'package:money_shift/models/enums/notification_type.dart';
import 'package:money_shift/models/notification_model.dart';

void main() {
  setUp(() {
    NotificationDedupe.clear();
    MockNotificationRepository.instance.clearAll();
  });

  test('인박스 적재 전 shouldSkipContent 하면 저장이 스킵되는 회귀를 막는다', () {
    const uid = 'mock_owner_1';
    const title = '[직원 등록] 새로운 팀원이 합류했어요';
    const body = '테스트 알바가 매장에 합류했습니다.';
    const storeId = 'test_store_001';

    // 예전에 디스패처가 미리 shouldSkipContent 호출 → repo 가 항상 skip
    // 지금은 repo 한 곳에서만 디듀프해야 1건 저장된다.
    final item = NotificationModel.withDeepLink(
      id: 'n1',
      userId: uid,
      storeId: storeId,
      type: NotificationType.register,
      title: title,
      body: body,
      isRead: false,
      createdAt: DateTime(2026, 10, 25),
    );

    MockNotificationRepository.instance.addNotification(uid, item);
    expect(MockNotificationRepository.instance.listFor(uid).length, 1);

    // 동일 내용 재시도는 스킵
    MockNotificationRepository.instance.addNotification(
      uid,
      item.copyWith(id: 'n2'),
    );
    expect(MockNotificationRepository.instance.listFor(uid).length, 1);
  });
}
