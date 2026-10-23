import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../data/services/api_service.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../attendance/presentation/owner_commute_dashboard_screen.dart';
import '../../../notices/presentation/notice_board_screen.dart';
import '../employee_detail_setting_screen.dart';

/// 사장 직원목록 탭 — 경영 지표 + 계약·기본 조건 관리
class OwnerHomeTab extends StatefulWidget {
  const OwnerHomeTab({
    super.key,
    required this.room,
    required this.membership,
  });

  final RoomModel room;
  final RoomMemberModel membership;

  @override
  State<OwnerHomeTab> createState() => _OwnerHomeTabState();
}

class _OwnerHomeTabState extends State<OwnerHomeTab> {
  MonthlyLaborCost? _labor;
  var _laborLoading = true;
  String? _laborError;

  static final _won = NumberFormat('#,###', 'ko_KR');
  static final _hours = NumberFormat('#,##0.#', 'ko_KR');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLaborCost());
  }

  @override
  void didUpdateWidget(covariant OwnerHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _loadLaborCost();
    }
  }

  Future<void> _loadLaborCost() async {
    final roomId = widget.room.id;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    if (mounted) {
      setState(() {
        _laborLoading = true;
        _laborError = null;
      });
    }

    final local = MockStore.instance.monthlyLaborCost(
      roomId: roomId,
      year: year,
      month: month,
    );

    MonthlyLaborCost? remote;
    try {
      remote = await ApiService.instance.fetchMonthlyLaborCost(
        roomId: roomId,
        year: year,
        month: month,
      );
    } catch (_) {
      remote = null;
    }

    if (!mounted) return;
    // 방 전환 중이면 무시
    if (widget.room.id != roomId) return;

    setState(() {
      _laborLoading = false;
      if (remote != null) {
        _labor = remote;
        _laborError = null;
      } else {
        // API 실패·미연동 시 로컬 집계로 카드는 유지
        _labor = local;
        _laborError = null;
      }
    });
  }

  void _openEmployeeContract(
    BuildContext context,
    RoomModel liveRoom,
    RoomMemberModel member,
  ) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.employeeContract(liveRoom.id, member.userId),
      stopAtNames: [AppRouteNames.room(liveRoom.id)],
      builder: (_) => EmployeeDetailSettingScreen(
        roomId: liveRoom.id,
        member: member,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final liveRoom =
            MockStore.instance.rooms[widget.room.id] ?? widget.room;
        final staff = MockStore.instance.activeStaffMembers(liveRoom.id);
        final textTheme = Theme.of(context).textTheme;
        final labor = _labor;

        return RefreshIndicator(
          color: AppColors.buttonFill,
          onRefresh: _loadLaborCost,
          child: ScrollablePageBody(
            top: false,
            bottom: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  liveRoom.name,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.membership.roleLabel,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _LaborCostHighlightCard(
                  loading: _laborLoading && labor == null,
                  labor: labor,
                  error: _laborError,
                  wonFormat: _won,
                  hoursFormat: _hours,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickLinkCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: '출·퇴근 현황',
                        onTap: () {
                          AppNavigation.pushSingleTop(
                            name: AppRouteNames.ownerCommute(liveRoom.id),
                            stopAtNames: [AppRouteNames.room(liveRoom.id)],
                            builder: (_) => OwnerCommuteDashboardScreen(
                              roomId: liveRoom.id,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickLinkCard(
                        icon: Icons.campaign_outlined,
                        label: '매장 공지사항',
                        onTap: () {
                          AppNavigation.pushSingleTop(
                            name: AppRouteNames.noticeBoard(liveRoom.id),
                            stopAtNames: [AppRouteNames.room(liveRoom.id)],
                            builder: (_) => NoticeBoardScreen(
                              room: liveRoom,
                              canManage: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '직원 목록',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '직원별 기본 시급과 수당 조건을 설정하세요. '
                  '근무 배정은 \'근무표\' 탭에서 진행할 수 있습니다.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                if (staff.isEmpty)
                  AppCard(
                    child: Text(
                      '직원이 없습니다. 초대하기 탭에서 코드를 공유해 주세요.',
                      style: textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final m in staff)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () =>
                            _openEmployeeContract(context, liveRoom, m),
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          m.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        m.roleLabel,
                                        style: textTheme.labelSmall?.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textCaption,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '시급 ${NumberFormat('#,###').format(m.contract.hourlyWage)}원',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.textCaption,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 이번 달 누적 인건비 강조 카드
class _LaborCostHighlightCard extends StatelessWidget {
  const _LaborCostHighlightCard({
    required this.loading,
    required this.labor,
    required this.error,
    required this.wonFormat,
    required this.hoursFormat,
  });

  final bool loading;
  final MonthlyLaborCost? labor;
  final String? error;
  final NumberFormat wonFormat;
  final NumberFormat hoursFormat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.buttonFill,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowStrong,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: loading
            ? const SizedBox(
                height: 88,
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 달 누적 인건비',
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (error != null && labor == null)
                    Text(
                      error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    Text(
                      '${wonFormat.format(labor?.totalLaborCost ?? 0)}원',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '근무 직원 ${labor?.activeWorkerCount ?? 0}명'
                      ' · 총 ${hoursFormat.format(labor?.totalWorkHours ?? 0)}시간'
                      '${labor?.periodFrom != null && labor!.periodFrom.isNotEmpty && labor!.periodTo.isNotEmpty ? ' · ${labor!.periodFrom.substring(5)}~${labor!.periodTo.substring(5)}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.textPrimary),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
