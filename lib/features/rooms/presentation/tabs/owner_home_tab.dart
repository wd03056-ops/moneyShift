import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ads/widgets/native_ad_card.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../data/services/api_service.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../../services/labor_cost_memo.dart';
import '../../../../services/month_payroll_aggregator.dart';
import '../../../attendance/presentation/owner_commute_dashboard_screen.dart';
import '../../../notices/presentation/notice_board_screen.dart';
import '../employee_detail_setting_screen.dart';
import '../labor_cost_detail_screen.dart';

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
  var _laborRequestId = 0;
  String? _lastRemoteKey;

  static final _won = NumberFormat('#,###', 'ko_KR');

  @override
  void initState() {
    super.initState();
    MockStore.instance.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLaborCost());
  }

  @override
  void dispose() {
    MockStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OwnerHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _loadLaborCost();
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    // 출퇴근·배정·계약 변경 시 로컬 인건비 즉시 재계산
    final now = DateTime.now();
    final local = _localLabor(widget.room.id, now.year, now.month);
    setState(() {
      _labor = local;
      _laborError = null;
      _laborLoading = false;
    });
  }

  String _memoKey(String roomId, int year, int month) {
    final rev = MockStore.instance.dataRevision;
    return '$roomId|$year|$month|w=0|i=0|r=$rev';
  }

  MonthlyLaborCost _localLabor(String roomId, int year, int month) {
    return LaborCostMemo.room(
      key: _memoKey(roomId, year, month),
      compute: () => MonthPayrollAggregator.forRoom(
        store: MockStore.instance,
        roomId: roomId,
        year: year,
        month: month,
        includeWeeklyHoliday: false,
        includeEmployerSocialInsurance: false,
      ),
    );
  }

  Future<void> _loadLaborCost({bool showFullLoading = true}) async {
    final roomId = widget.room.id;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final requestId = ++_laborRequestId;
    final remoteKey = '$roomId|$year|$month|w=0|i=0';

    // 새로고침 시 즉시 로컬 반영 (출퇴근 SSOT = MockStore)
    final local = _localLabor(roomId, year, month);
    if (mounted) {
      setState(() {
        if (showFullLoading && _labor == null) {
          _laborLoading = true;
        }
        _labor = local;
        _laborError = null;
      });
    }

    // 동일 파라미터 원격 조회가 연속이면 스킵
    if (!showFullLoading && _lastRemoteKey == remoteKey) {
      if (mounted) setState(() => _laborLoading = false);
      return;
    }

    MonthlyLaborCost? remote;
    Object? remoteError;
    try {
      remote = await ApiService.instance.fetchMonthlyLaborCost(
        roomId: roomId,
        year: year,
        month: month,
        includeWeeklyHoliday: false,
        includeEmployerSocialInsurance: false,
      );
      _lastRemoteKey = remoteKey;
    } catch (e) {
      remote = null;
      remoteError = e;
    }

    if (!mounted) return;
    if (widget.room.id != roomId) return;
    if (requestId != _laborRequestId) return;

    setState(() {
      _laborLoading = false;
      // 로컬(실출퇴근)을 우선. API는 로컬이 비어 있을 때만 보조.
      if (local.totalLaborCost == 0 &&
          remote != null &&
          remote.totalLaborCost > 0) {
        _labor = remote;
        _laborError = null;
      } else {
        _labor = local;
        _laborError = remote == null && remoteError != null
            ? '서버 동기화에 실패해 로컬 집계를 표시합니다.'
            : null;
      }
    });

    if (remote == null &&
        remoteError != null &&
        mounted &&
        local.totalLaborCost == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인건비를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.membership.roleLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textCaption,
                  ),
                ),
                const SizedBox(height: 24),
                _LaborCostHighlightCard(
                  loading: _laborLoading && labor == null,
                  labor: labor,
                  error: _laborError,
                  wonFormat: _won,
                  onOpenDetail: () {
                    AppNavigation.pushSingleTop(
                      name: AppRouteNames.laborCostDetail(liveRoom.id),
                      stopAtNames: [AppRouteNames.room(liveRoom.id)],
                      builder: (_) => LaborCostDetailScreen(room: liveRoom),
                    );
                  },
                ),
                const NativeAdCard(
                  margin: EdgeInsets.only(top: 16, bottom: 4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickLinkTile(
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
                      child: _QuickLinkTile(
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
                const SizedBox(height: 28),
                Text(
                  '직원 목록',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '직원별 기본 시급과 수당 조건을 설정하세요. '
                  '근무 배정은 \'근무표\' 탭에서 진행할 수 있습니다.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
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

/// 이번 달 누적 인건비 — 금액·기간 중심, 탭 시 상세로 이동
class _LaborCostHighlightCard extends StatelessWidget {
  const _LaborCostHighlightCard({
    required this.loading,
    required this.labor,
    required this.error,
    required this.wonFormat,
    required this.onOpenDetail,
  });

  final bool loading;
  final MonthlyLaborCost? labor;
  final String? error;
  final NumberFormat wonFormat;
  final VoidCallback onOpenDetail;

  int get _displayAmount => labor?.totalLaborCost ?? 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final period = labor != null &&
            labor!.periodFrom.length >= 10 &&
            labor!.periodTo.length >= 10
        ? labor!.periodLabel
        : null;

    if (loading) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return AppCard(
      onTap: onOpenDetail,
      padding: const EdgeInsets.fromLTRB(16, 22, 12, 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '이번 달 누적 인건비',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (error != null && labor == null)
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textCaption,
                    ),
                  )
                else ...[
                  Text(
                    '${wonFormat.format(_displayAmount)}원',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.1,
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (period != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      period,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// 홈 퀵링크 — 가로 2열 알약 바 (슬림)
class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const double _height = 40;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_height / 2);
    return SizedBox(
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: AppDecorations.softShadow,
        ),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
