import 'package:flutter_test/flutter_test.dart';
import 'package:money_shift/core/navigation/notification_deep_link.dart';
import 'package:money_shift/models/enums/notification_type.dart';
import 'package:money_shift/models/notification_model.dart';

void main() {
  group('NotificationDeepLink route mapping', () {
    test('8 event types map to expected targetRoute', () {
      expect(
        NotificationDeepLink.routeForType(NotificationType.register),
        NotificationRoutes.employees,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.assign),
        NotificationRoutes.assignedSchedule,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.requestUpdate),
        NotificationRoutes.scheduleChange,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.resultUpdate),
        NotificationRoutes.schedule,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.subRequest),
        NotificationRoutes.substituteAccept,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.subAccept),
        NotificationRoutes.substituteApprove,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.subConfirm),
        NotificationRoutes.schedule,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.commute),
        NotificationRoutes.commuteHistory,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.absent),
        NotificationRoutes.myAttendance,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.notice),
        NotificationRoutes.noticeDetail,
      );
      expect(
        NotificationDeepLink.routeForType(NotificationType.commuteCorrection),
        NotificationRoutes.commuteCorrection,
      );
      expect(
        NotificationDeepLink.routeForType(
          NotificationType.commuteCorrectionResult,
        ),
        NotificationRoutes.commuteHistory,
      );
    });

    test('buildParams fills requestId / noticeId aliases', () {
      final change = NotificationDeepLink.fromType(
        type: NotificationType.requestUpdate,
        storeId: 'store_1',
        data: const {'scheduleId': 'sch_1', 'requestId': 'req_1'},
      );
      expect(change.targetRoute, NotificationRoutes.scheduleChange);
      expect(change.params['storeId'], 'store_1');
      expect(change.params['requestId'], 'req_1');
      expect(change.params['id'], 'req_1');

      final notice = NotificationDeepLink.fromType(
        type: NotificationType.notice,
        storeId: 'store_1',
        data: const {'noticeId': 'n_1'},
      );
      expect(notice.targetRoute, NotificationRoutes.noticeDetail);
      expect(notice.noticeId, 'n_1');
    });

    test('parse recovers from FCM-style flattened payload', () {
      final link = NotificationDeepLink.parse(
        data: {
          'type': 'sub_request',
          'targetRoute': '/requests/substitute/accept',
          'storeId': 's1',
          'swapId': 'sw1',
          'params': '{"storeId":"s1","swapId":"sw1","requestId":"sw1"}',
        },
      );
      expect(link.targetRoute, NotificationRoutes.substituteAccept);
      expect(link.storeId, 's1');
      expect(link.swapId, 'sw1');
    });

    test('NotificationModel.withDeepLink embeds targetRoute/params', () {
      final model = NotificationModel.withDeepLink(
        id: '1',
        userId: 'u1',
        storeId: 's1',
        type: NotificationType.assign,
        title: 't',
        body: 'b',
        isRead: false,
        createdAt: DateTime(2026, 1, 1),
        data: const {'scheduleId': 'sch_9'},
      );
      expect(model.targetRoute, NotificationRoutes.assignedSchedule);
      expect(model.params['shiftId'], 'sch_9');
      expect(
        model.data['targetRoute'],
        NotificationRoutes.assignedSchedule,
      );
      expect(model.deepLink.uriString.contains('storeId'), isTrue);
    });

    test('owner/staff tab indices for key routes', () {
      // 사장: 0직원목록 · 1근무표 · 2초대하기 · 3설정
      expect(
        NotificationDeepLink.tabIndexFor(
          targetRoute: NotificationRoutes.employees,
          isOwner: true,
        ),
        0,
      );
      expect(
        NotificationDeepLink.tabIndexFor(
          targetRoute: NotificationRoutes.schedule,
          isOwner: true,
        ),
        1,
      );
      expect(
        NotificationDeepLink.tabIndexFor(
          targetRoute: NotificationRoutes.substituteAccept,
          isOwner: false,
        ),
        0,
      );
      expect(
        NotificationDeepLink.tabIndexFor(
          targetRoute: NotificationRoutes.commuteHistory,
          isOwner: true,
        ),
        isNull, // OwnerCommuteDashboardScreen 으로 푸시
      );
      expect(
        NotificationDeepLink.tabIndexFor(
          targetRoute: NotificationRoutes.myAttendance,
          isOwner: false,
        ),
        0,
      );
    });
  });
}
