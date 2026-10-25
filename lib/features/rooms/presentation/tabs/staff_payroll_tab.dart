import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../../services/payroll_calculator.dart';
import '../../../notifications/presentation/push_notification_switch_tile.dart';
import '../../../profile/presentation/account_extras_section.dart';
import '../../../schedules/widgets/pay_disclaimer_caption.dart';
import '../../../../services/month_payroll_aggregator.dart';
import '../widgets/staff_month_pay_summary_card.dart';

/// 알바 3탭 — 급여·정보 (상단 요약 + ListTile 메뉴)
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
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final store = MockStore.instance;
        final live =
            store.getMembership(room.id, membership.userId) ?? membership;
        final summary = MonthPayrollAggregator.forWorker(
          store: store,
          roomId: room.id,
          userId: live.userId,
        );

        return ScrollablePageBody(
          top: false,
          bottom: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '내 정보',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                room.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),

              // 1. 급여 및 근무
              _MenuSection(
                title: '급여 및 근무',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 24,
                    horizontalTitleGap: 12,
                    leading: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      '실근무 급여 상세 내역',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    subtitle: Text(
                      summary.workedDays == 0
                          ? '이번 달 퇴근 기록 없음'
                          : '이번 달 ${summary.workedDays}일 · '
                              '${formatStaffWorkHours(summary.netWorkedMinutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => _openPayDetail(
                      context,
                      room: room,
                      member: live,
                      summary: summary,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 24,
                    horizontalTitleGap: 12,
                    leading: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      '기본 시급 및 수당 조건',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    subtitle: Text(
                      '시급 ${currency.format(live.contract.hourlyWage)}원',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => _openContractDetail(
                      context,
                      contract: live.contract,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. 계정 및 알림
              _MenuSection(
                title: '계정 및 알림',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 24,
                    horizontalTitleGap: 12,
                    title: Text(
                      '내 프로필',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        '${live.displayName} · ${live.roleLabel}',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    onTap: () => _openMyInfoSheet(
                      context,
                      member: live,
                      roomName: room.name,
                    ),
                  ),
                  const AccountExtrasSection(
                    showProfileEdit: true,
                    showNotificationTest: false,
                    showTestAccounts: false,
                    showLogoutDelete: false,
                    showLegal: false,
                    showSupportEmail: false,
                  ),
                  const Divider(height: 1),
                  const PushNotificationSwitchTile(
                    dense: true,
                    inCard: false,
                  ),
                  const AccountExtrasSection(
                    showProfileEdit: false,
                    showNotificationTest: true,
                    showTestAccounts: true,
                    showLogoutDelete: false,
                    showLegal: false,
                    showSupportEmail: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. 약관 및 정책 · 로그아웃/회원탈퇴
              const _MenuSection(
                title: '약관 및 정책',
                children: [
                  AccountExtrasSection(
                    showProfileEdit: false,
                    showLogoutDelete: true,
                    showTestAccounts: false,
                    showNotificationTest: false,
                    showLegal: true,
                    showLegalSectionLabel: false,
                    showSupportEmail: true,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static void _openContractDetail(
    BuildContext context, {
    required EmployeeContractModel contract,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ContractDetailScreen(contract: contract),
      ),
    );
  }

  static void _openPayDetail(
    BuildContext context, {
    required RoomModel room,
    required RoomMemberModel member,
    required WorkerMonthPaySummary summary,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PayDetailScreen(
          room: room,
          member: member,
          summary: summary,
        ),
      ),
    );
  }

  static void _openMyInfoSheet(
    BuildContext context, {
    required RoomMemberModel member,
    required String roomName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '내 프로필',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _DetailRow(label: '이름', value: member.displayName),
                _DetailRow(label: '직책', value: member.roleLabel),
                _DetailRow(label: '매장', value: roomName),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuSectionTitle(title: title),
        ...children,
      ],
    );
  }
}

class _ContractDetailScreen extends StatelessWidget {
  const _ContractDetailScreen({required this.contract});

  final EmployeeContractModel contract;

  String get _breakLabel {
    switch (contract.breakTimeType) {
      case BreakTimeType.auto:
        return '자동 (4시간↑ 30분 · 8시간↑ 60분)';
      case BreakTimeType.fixed:
        final m = contract.fixedBreakMinutes;
        return m == 0 ? '고정 · 없음' : '고정 · $m분';
      case BreakTimeType.none:
        return '없음 (0분)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###');
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기본 시급 및 수당 조건'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '사장님이 지정한 조건입니다. 확인만 가능합니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기본 시급', style: textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    '${currency.format(contract.hourlyWage)}원',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppConstants.minimumWageYear}년 최저시급 '
                    '${currency.format(AppConstants.minimumHourlyWage)}원',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _DetailRow(label: '휴게', value: _breakLabel),
                  const Divider(height: 16),
                  _DetailRow(
                    label: '주휴수당',
                    value: contract.isWeekPayEnabled
                        ? '포함 (주 ${PayrollCalculator.weeklyHolidayThresholdHours.toStringAsFixed(0)}시간↑)'
                        : '미포함',
                  ),
                  const Divider(height: 16),
                  _DetailRow(
                    label: '야간수당',
                    value: contract.isNightPayEnabled
                        ? '포함 (22시~06시 +0.5)'
                        : '미포함',
                  ),
                  const Divider(height: 16),
                  _DetailRow(
                    label: '연장수당',
                    value: contract.isOvertimePayEnabled
                        ? '포함 (1일 8시간↑ +0.5)'
                        : '미포함',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayDetailScreen extends StatelessWidget {
  const _PayDetailScreen({
    required this.room,
    required this.member,
    required this.summary,
  });

  final RoomModel room;
  final RoomMemberModel member;
  final WorkerMonthPaySummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###');
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('실근무 급여 상세'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              summary.monthLabel,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              room.name,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '실근무 급여',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${currency.format(summary.actualPay)}원',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: '기본급',
                    value: '${currency.format(summary.actualBasePay)}원',
                  ),
                  if (summary.actualWeeklyPay > 0)
                    _DetailRow(
                      label: '주휴수당',
                      value: '${currency.format(summary.actualWeeklyPay)}원',
                    ),
                  if (summary.actualOvertimePay > 0)
                    _DetailRow(
                      label: '연장·야간',
                      value: '${currency.format(summary.actualOvertimePay)}원',
                    ),
                  const Divider(height: 20),
                  _DetailRow(
                    label: '근무시간',
                    value: formatStaffWorkHours(summary.actualNetMinutes),
                  ),
                  _DetailRow(
                    label: '근무일수',
                    value: summary.workedDays == 0
                        ? '-'
                        : '${summary.workedDays}일',
                  ),
                  const Divider(height: 20),
                  if (summary.remainingSchedulePay > 0)
                    _DetailRow(
                      label: '남은 배정',
                      value:
                          '${currency.format(summary.remainingSchedulePay)}원',
                    ),
                  _DetailRow(
                    label: '이번 달 예상',
                    value: '${currency.format(summary.projectedPay)}원',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              summary.workedDays == 0
                  ? '퇴근 확정분 + 남은 배정으로 예상을 계산합니다.'
                  : '실근무는 퇴근 시각·계약 수당, 예상은 남은 배정·주휴를 포함합니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const PayDisclaimerCaption(),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
