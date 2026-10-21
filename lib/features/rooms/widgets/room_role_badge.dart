import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/enums/member_role.dart';

/// 방 목록용 역할 배지
/// - 사장(owner): Deep Navy
/// - 직원(초대): Trust Blue
class RoomRoleBadge extends StatelessWidget {
  const RoomRoleBadge({super.key, required this.role});

  final MemberRole role;

  @override
  Widget build(BuildContext context) {
    final isOwner = role == MemberRole.owner;
    final bg = isOwner ? AppColors.badgeOwnerBg : AppColors.badgeStaffBg;
    final fg = isOwner ? AppColors.badgeOwnerFg : AppColors.badgeStaffFg;
    final label = isOwner ? '사장' : '직원';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              letterSpacing: -0.2,
            ),
      ),
    );
  }
}
