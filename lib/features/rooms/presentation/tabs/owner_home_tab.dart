import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../attendance/presentation/owner_commute_dashboard_screen.dart';
import '../../../notices/presentation/notice_board_screen.dart';
import '../employee_detail_setting_screen.dart';
import '../invite_member_screen.dart';

/// 사장 1탭 — 직원목록 (계약·기본 조건 관리)
class OwnerHomeTab extends StatelessWidget {
  const OwnerHomeTab({
    super.key,
    required this.room,
    required this.membership,
  });

  final RoomModel room;
  final RoomMemberModel membership;

  void _openInvite(BuildContext context, RoomModel liveRoom) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.invite(liveRoom.id),
      stopAtNames: [AppRouteNames.room(liveRoom.id)],
      builder: (_) => InviteMemberScreen(
        roomId: liveRoom.id,
        roomName: liveRoom.name,
      ),
    );
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
        final liveRoom = MockStore.instance.rooms[room.id] ?? room;
        final staff = MockStore.instance.activeStaffMembers(liveRoom.id);
        final textTheme = Theme.of(context).textTheme;

        return ScrollablePageBody(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      liveRoom.name,
                      style: textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _openInvite(context, liveRoom),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      '초대하기',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                membership.role.labelKo,
                style: textTheme.bodyMedium,
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
                    '직원이 없습니다. 상단에서 초대해 주세요.',
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
                                      m.role.labelKo,
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
        );
      },
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
