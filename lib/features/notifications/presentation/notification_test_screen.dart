import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/navigation/notification_deep_link.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../mock/mock_user.dart';
import '../../../models/enums/notification_type.dart';
import '../../../services/local_notification_service.dart';
import '../data/mock_notification_repository.dart';
import '../domain/app_notification_dispatcher.dart';
import '../domain/notification_router.dart';
import '../domain/notification_templates.dart';

/// 개발/Mock 전용 알림 시뮬레이터
///
/// 8종 버튼 → 문구 미리보기 + Mock 알림함 적재 + 로컬 푸시
class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  static bool get isAvailable => kDebugMode;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) {
      return const Scaffold(
        body: Center(child: Text('디버그 모드에서만 사용할 수 있습니다.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final owner = MockUser.owner;
    final staff = MockUser.staff;
    final staff2 = MockUser.demoStaffRoster.length > 1
        ? MockUser.demoStaffRoster[1]
        : MockUser.staff;
    final storeName =
        MockStore.instance.rooms[MockStore.demoRoomId]?.name ?? '데모 카페';
    final storeId = MockStore.demoRoomId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 테스트'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: Colors.white,
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mock / Debug 전용',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.holiday,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '버튼을 누르면 문구 미리보기 · 대상 계정 알림함 반영 · 로컬 푸시가 실행됩니다.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '현재 로그인: ${MockSession.instance.currentUser?.displayName ?? '-'}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _TestButton(
              label: '1. [직원 등록]',
              subtitle: '수신: 사장님',
              onPressed: () => _run(
                context,
                recipientLabel: '사장님 (${owner.displayName})',
                targetUids: [owner.uid],
                type: NotificationType.register,
                title: NotificationTemplates.staffJoinedTitle,
                body: NotificationTemplates.staffJoinedBody(staff.displayName),
                storeId: storeId,
                trigger: () => AppNotificationDispatcher.staffJoined(
                  ownerUid: owner.uid,
                  staffDisplayName: staff.displayName,
                  storeId: storeId,
                ),
              ),
            ),
            _TestButton(
              label: '2. [근무 배정]',
              subtitle: '수신: 알바생',
              onPressed: () => _run(
                context,
                recipientLabel: '직원 (${staff.displayName})',
                targetUids: [staff.uid],
                type: NotificationType.assign,
                title: NotificationTemplates.scheduleAssignedTitle,
                body: NotificationTemplates.scheduleAssignedBody(storeName),
                storeId: storeId,
                data: const {'scheduleId': 'test_schedule'},
                trigger: () => AppNotificationDispatcher.scheduleAssigned(
                  workerUid: staff.uid,
                  storeId: storeId,
                  scheduleId: 'test_schedule',
                  storeName: storeName,
                ),
              ),
            ),
            _TestButton(
              label: '3. [일정 변경 요청]',
              subtitle: '수신: 사장님',
              onPressed: () => _run(
                context,
                recipientLabel: '사장님 (${owner.displayName})',
                targetUids: [owner.uid],
                type: NotificationType.requestUpdate,
                title: NotificationTemplates.scheduleChangeRequestTitle,
                body: NotificationTemplates.scheduleChangeRequestBody(
                  staff.displayName,
                ),
                storeId: storeId,
                data: const {
                  'scheduleId': 'test_schedule',
                  'requestId': 'test_schedule',
                },
                trigger: () =>
                    AppNotificationDispatcher.scheduleChangeRequested(
                  ownerUid: owner.uid,
                  staffDisplayName: staff.displayName,
                  storeId: storeId,
                  scheduleId: 'test_schedule',
                ),
              ),
            ),
            _TestButton(
              label: '4. [일정 변경 결과] 승인',
              subtitle: '수신: 알바생',
              onPressed: () => _run(
                context,
                recipientLabel: '직원 (${staff.displayName})',
                targetUids: [staff.uid],
                type: NotificationType.resultUpdate,
                title: NotificationTemplates.scheduleChangeResultTitle,
                body: NotificationTemplates.scheduleChangeResultBody(
                  approved: true,
                ),
                storeId: storeId,
                data: const {
                  'scheduleId': 'test_schedule',
                  'approved': 'true',
                },
                trigger: () => AppNotificationDispatcher.scheduleChangeResult(
                  workerUid: staff.uid,
                  approved: true,
                  storeId: storeId,
                  scheduleId: 'test_schedule',
                ),
              ),
            ),
            _TestButton(
              label: '4-b. [일정 변경 결과] 거절',
              subtitle: '수신: 알바생',
              onPressed: () => _run(
                context,
                recipientLabel: '직원 (${staff.displayName})',
                targetUids: [staff.uid],
                type: NotificationType.resultUpdate,
                title: NotificationTemplates.scheduleChangeResultTitle,
                body: NotificationTemplates.scheduleChangeResultBody(
                  approved: false,
                ),
                storeId: storeId,
                data: const {
                  'scheduleId': 'test_schedule',
                  'approved': 'false',
                },
                trigger: () => AppNotificationDispatcher.scheduleChangeResult(
                  workerUid: staff.uid,
                  approved: false,
                  storeId: storeId,
                  scheduleId: 'test_schedule',
                ),
              ),
            ),
            _TestButton(
              label: '5-1. [대타 요청]',
              subtitle: '수신: 동료 알바생 B',
              onPressed: () => _run(
                context,
                recipientLabel: '직원 B (${staff2.displayName})',
                targetUids: [staff2.uid],
                type: NotificationType.subRequest,
                title: NotificationTemplates.swapRequestTitle,
                body: NotificationTemplates.swapRequestBody(staff.displayName),
                storeId: storeId,
                data: const {
                  'swapId': 'test_swap',
                  'requestId': 'test_swap',
                  'scheduleId': 'test_schedule',
                },
                trigger: () => AppNotificationDispatcher.swapRequested(
                  toWorkerUid: staff2.uid,
                  fromDisplayName: staff.displayName,
                  storeId: storeId,
                  swapId: 'test_swap',
                  scheduleId: 'test_schedule',
                ),
              ),
            ),
            _TestButton(
              label: '5-2. [대타 승인 요청]',
              subtitle: '수신: 사장님',
              onPressed: () => _run(
                context,
                recipientLabel: '사장님 (${owner.displayName})',
                targetUids: [owner.uid],
                type: NotificationType.subAccept,
                title: NotificationTemplates.swapOwnerApprovalTitle,
                body: NotificationTemplates.swapOwnerApprovalBody(
                  storeName: storeName,
                  fromName: staff.displayName,
                  toName: staff2.displayName,
                ),
                storeId: storeId,
                data: const {
                  'swapId': 'test_swap',
                  'requestId': 'test_swap',
                },
                trigger: () =>
                    AppNotificationDispatcher.swapColleagueAccepted(
                  ownerUid: owner.uid,
                  storeName: storeName,
                  fromName: staff.displayName,
                  toName: staff2.displayName,
                  storeId: storeId,
                  swapId: 'test_swap',
                ),
              ),
            ),
            _TestButton(
              label: '5-3. [대타 확정]',
              subtitle: '수신: 알바 A · B',
              onPressed: () => _run(
                context,
                recipientLabel:
                    '직원 A·B (${staff.displayName}, ${staff2.displayName})',
                targetUids: [staff.uid, staff2.uid],
                type: NotificationType.subConfirm,
                title: NotificationTemplates.swapConfirmedTitle,
                body: NotificationTemplates.swapConfirmedBody(storeName),
                storeId: storeId,
                data: const {'swapId': 'test_swap'},
                trigger: () => AppNotificationDispatcher.swapOwnerApproved(
                  fromWorkerUid: staff.uid,
                  toWorkerUid: staff2.uid,
                  storeName: storeName,
                  storeId: storeId,
                  swapId: 'test_swap',
                ),
              ),
            ),
            _TestButton(
              label: '6. [출·퇴근] 출근',
              subtitle: '수신: 사장님',
              onPressed: () => _run(
                context,
                recipientLabel: '사장님 (${owner.displayName})',
                targetUids: [owner.uid],
                type: NotificationType.commute,
                title: NotificationTemplates.attendanceTitle,
                body: NotificationTemplates.attendanceBody(
                  displayName: staff.displayName,
                  isClockIn: true,
                ),
                storeId: storeId,
                data: const {'action': 'clock_in'},
                trigger: () => AppNotificationDispatcher.attendance(
                  ownerUid: owner.uid,
                  staffDisplayName: staff.displayName,
                  isClockIn: true,
                  storeId: storeId,
                ),
              ),
            ),
            _TestButton(
              label: '6-b. [출·퇴근] 퇴근',
              subtitle: '수신: 사장님',
              onPressed: () => _run(
                context,
                recipientLabel: '사장님 (${owner.displayName})',
                targetUids: [owner.uid],
                type: NotificationType.commute,
                title: NotificationTemplates.attendanceTitle,
                body: NotificationTemplates.attendanceBody(
                  displayName: staff.displayName,
                  isClockIn: false,
                ),
                storeId: storeId,
                data: const {'action': 'clock_out'},
                trigger: () => AppNotificationDispatcher.attendance(
                  ownerUid: owner.uid,
                  staffDisplayName: staff.displayName,
                  isClockIn: false,
                  storeId: storeId,
                ),
              ),
            ),
            _TestButton(
              label: '7. [결근 처리]',
              subtitle: '수신: 알바생',
              onPressed: () => _run(
                context,
                recipientLabel: '직원 (${staff.displayName})',
                targetUids: [staff.uid],
                type: NotificationType.absent,
                title: NotificationTemplates.absentTitle,
                body: NotificationTemplates.absentBody(storeName),
                storeId: storeId,
                data: const {'scheduleId': 'test_schedule'},
                trigger: () => AppNotificationDispatcher.scheduleAbsent(
                  workerUid: staff.uid,
                  storeName: storeName,
                  storeId: storeId,
                  scheduleId: 'test_schedule',
                ),
              ),
            ),
            _TestButton(
              label: '8. [매장 공지사항]',
              subtitle: '수신: 매장 전체 직원',
              onPressed: () {
                final staffUids = MockUser.demoStaffRoster.map((e) => e.uid);
                _run(
                  context,
                  recipientLabel: '매장 직원 전원',
                  targetUids: staffUids.toList(),
                  type: NotificationType.notice,
                  title: NotificationTemplates.noticeTitle,
                  body: NotificationTemplates.noticeBody(storeName),
                  storeId: storeId,
                  data: const {'noticeId': 'test_notice'},
                  trigger: () => AppNotificationDispatcher.storeNotice(
                    staffUids: staffUids,
                    storeName: storeName,
                    storeId: storeId,
                    noticeId: 'test_notice',
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _verifyAllRoutes(context, storeId),
              icon: const Icon(Icons.route_outlined, size: 18),
              label: const Text('8종 라우트 매핑 검증'),
            ),
            const SizedBox(height: 12),
            Text(
              'Mock 알림 건수 — 사장 ${MockNotificationRepository.instance.listFor(owner.uid).length} · '
              '직원 ${MockNotificationRepository.instance.listFor(staff.uid).length}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _run(
    BuildContext context, {
    required String recipientLabel,
    required List<String> targetUids,
    required NotificationType type,
    required String title,
    required String body,
    required String storeId,
    required VoidCallback trigger,
    Map<String, String> data = const {},
  }) async {
    final link = NotificationDeepLink.fromType(
      type: type,
      storeId: storeId,
      data: data,
    );

    if (!context.mounted) return;
    final proceed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('알림 미리보기'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '수신: $recipientLabel',
                style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Title',
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(title, style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 10),
              Text(
                'Body',
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                'type: ${type.firestoreValue}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textCaption,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'targetRoute: ${link.uriString}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'navigate'),
            child: const Text('바로 이동'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'send'),
            child: const Text('발송 테스트'),
          ),
        ],
      ),
    );
    if (proceed == null || proceed == 'cancel' || !context.mounted) return;

    if (proceed == 'navigate') {
      NotificationRouter.openDeepLink(link);
      return;
    }

    trigger();

    await LocalNotificationService.instance.show(
      title: title,
      body: body,
      type: type,
      storeId: storeId,
      data: data,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '발송 완료 → $recipientLabel\n${link.targetRoute}',
            maxLines: 3,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '이동',
            onPressed: () => NotificationRouter.openDeepLink(link),
          ),
        ),
      );

    assert(targetUids.isNotEmpty);
  }

  static Future<void> _verifyAllRoutes(
    BuildContext context,
    String storeId,
  ) async {
    const expected = <NotificationType, String>{
      NotificationType.register: NotificationRoutes.employees,
      NotificationType.assign: NotificationRoutes.assignedSchedule,
      NotificationType.scheduleConfirmed: NotificationRoutes.schedule,
      NotificationType.requestUpdate: NotificationRoutes.scheduleChange,
      NotificationType.resultUpdate: NotificationRoutes.schedule,
      NotificationType.subRequest: NotificationRoutes.substituteAccept,
      NotificationType.subAccept: NotificationRoutes.substituteApprove,
      NotificationType.subConfirm: NotificationRoutes.schedule,
      NotificationType.commute: NotificationRoutes.commuteHistory,
      NotificationType.absent: NotificationRoutes.myAttendance,
      NotificationType.notice: NotificationRoutes.noticeDetail,
    };

    final failures = <String>[];
    for (final e in expected.entries) {
      final got = NotificationDeepLink.routeForType(e.key);
      if (got != e.value) {
        failures.add('${e.key.firestoreValue}: $got ≠ ${e.value}');
      }
    }

    // Mock 알림함 항목에 targetRoute가 채워지는지
    final probe = MockNotificationRepository.instance.createAndAdd(
      targetUserId: MockUser.owner.uid,
      type: NotificationType.assign,
      title: 'route-probe',
      body: 'verify',
      storeId: storeId,
      data: const {'scheduleId': 'probe_schedule'},
    );
    if (probe.targetRoute != NotificationRoutes.assignedSchedule) {
      failures.add(
        'mock inbox targetRoute=${probe.targetRoute} '
        '(expected ${NotificationRoutes.assignedSchedule})',
      );
    }
    if (probe.params['scheduleId'] != 'probe_schedule') {
      failures.add('mock inbox params missing scheduleId');
    }

    if (!context.mounted) return;
    final ok = failures.isEmpty;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? '라우트 검증 통과' : '라우트 검증 실패'),
        content: SingleChildScrollView(
          child: Text(
            ok
                ? '8종 type → targetRoute 매핑 OK\n'
                    'Mock 알림함 targetRoute/params OK\n\n'
                    '${expected.entries.map((e) => '• ${e.key.firestoreValue} → ${e.value}').join('\n')}'
                : failures.join('\n'),
          ),
        ),
        actions: [
          if (ok)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                NotificationRouter.openFromNotification(probe);
              },
              child: const Text('샘플 알림으로 이동'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
