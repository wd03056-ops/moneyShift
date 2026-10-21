import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../notifications/presentation/push_notification_switch_tile.dart';
import '../../../schedules/widgets/pay_disclaimer_caption.dart';

/// 알바 3탭 — 급여 및 정보 (실제 출퇴근 기준 합산)
class StaffPayrollTab extends StatelessWidget {
  const StaffPayrollTab({
    super.key,
    required this.room,
    required this.membership,
  });

  final RoomModel room;
  final RoomMemberModel membership;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###');

    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final wage = membership.hourlyWage ?? 10000;
        final store = MockStore.instance;
        // 실제 출퇴근이 있는 날짜만 집계
        final clockOutDates = <DateTime>{};
        for (final a in store.attendanceForUser(room.id, membership.userId)) {
          if (a.type != AttendanceType.clockOut) continue;
          clockOutDates.add(
            DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day),
          );
        }

        var baseTotal = 0;
        var weeklyTotal = 0;
        var overtimeTotal = 0;
        var workedDays = 0;
        for (final day in clockOutDates) {
          final e = store.actualPayEstimateOnDate(
            room.id,
            membership.userId,
            day,
          );
          if (e == null || e.total <= 0) continue;
          workedDays++;
          baseTotal += e.basePay;
          weeklyTotal += e.weeklyHolidayPay;
          overtimeTotal += e.overtimeNightPay;
        }
        final estimated = baseTotal + weeklyTotal + overtimeTotal;

        return ScrollablePageBody(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '급여 및 정보',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                room.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '시급',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${AppConstants.minimumWageYear}년 최저시급 '
                          '${currency.format(AppConstants.minimumHourlyWage)}원',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currency.format(wage)}원',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '실근무 급여 (출퇴근 기준)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currency.format(estimated)}원',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _sumLine(context, '기본급', baseTotal, currency),
                    if (weeklyTotal > 0)
                      _sumLine(context, '주휴수당', weeklyTotal, currency),
                    if (overtimeTotal > 0)
                      _sumLine(context, '연장수당', overtimeTotal, currency),
                    const SizedBox(height: 8),
                    Text(
                      workedDays == 0
                          ? '퇴근한 근무가 있으면 여기에 합산됩니다.'
                          : '퇴근한 근무 $workedDays일 기준 · 실제 출퇴근 시간으로 산정됩니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                    ),
                    const PayDisclaimerCaption(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 정보',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: '이름', value: membership.displayName),
                    _InfoRow(label: '직책', value: membership.role.labelKo),
                    _InfoRow(label: '매장', value: room.name),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const PushNotificationSwitchTile(),
            ],
          ),
        );
      },
    );
  }

  Widget _sumLine(
    BuildContext context,
    String label,
    int amount,
    NumberFormat currency,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Text(
            '${currency.format(amount)}원',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
