import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../mock/mock_session.dart';
import '../../../models/notification_item.dart';
import '../domain/notification_router.dart';
import 'notification_inbox_controller.dart';

/// 알림함 — 편집 모드 · 스와이프 삭제 · Empty State · 당겨서 새로고침
class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key, this.uid});

  final String? uid;

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  late final NotificationInboxController _controller;
  final _dateFmt = DateFormat('M월 d일 HH:mm', 'ko_KR');

  @override
  void initState() {
    super.initState();
    final uid = widget.uid ?? MockSession.instance.requireUid;
    _controller = NotificationInboxController(uid: uid)..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onMarkRead() async {
    if (_controller.busy || _controller.items.isEmpty) return;
    final selectedMode =
        _controller.editing && _controller.hasSelection;
    if (!selectedMode && _controller.unreadCount == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('읽지 않은 알림이 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await _controller.markReadAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedMode ? '선택한 알림을 읽음 처리했습니다.' : '모든 알림을 읽음 처리했습니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('읽음 처리에 실패했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onDelete() async {
    if (_controller.busy || _controller.items.isEmpty) return;
    final selectedMode =
        _controller.editing && _controller.hasSelection;
    final count = selectedMode
        ? _controller.selectedCount
        : _controller.items.length;
    if (count == 0) return;

    final ok = await _confirmDelete(
      selectedMode ? '선택한 $count건을 삭제할까요?' : '알림 $count건을 모두 삭제할까요?',
    );
    if (ok != true || !mounted) return;

    try {
      await _controller.deleteAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count건을 삭제했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제에 실패했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool?> _confirmDelete(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('알림 삭제'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(color: AppColors.holiday),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmSwipeDelete() async {
    final ok = await _confirmDelete('이 알림을 삭제할까요?');
    return ok == true;
  }

  Future<void> _commitSwipeDelete(NotificationItem item) async {
    try {
      await _controller.deleteOne(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림을 삭제했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제에 실패했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final title = c.editing && c.hasSelection
            ? '${c.selectedCount}개 선택'
            : '알림함';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(title),
            leading: c.editing
                ? IconButton(
                    tooltip: '편집 종료',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: c.busy ? null : c.exitEditMode,
                  )
                : null,
            actions: [
              if (c.items.isNotEmpty)
                TextButton(
                  onPressed: c.busy ? null : c.toggleEditMode,
                  child: Text(
                    c.editing ? '완료' : '편집',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.editing && c.items.isNotEmpty)
                _SelectAllBar(
                  checked: c.isAllSelected,
                  onChanged: c.busy
                      ? null
                      : (_) => c.toggleSelectAll(),
                  label: c.isAllSelected ? '전체 선택 해제' : '전체 선택',
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => c.refresh(),
                  child: c.loading && c.items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: CircularProgressIndicator()),
                          ],
                        )
                      : c.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                              children: const [
                                _EmptyInboxState(),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: c.items.length +
                                  (c.unreadCount > 0 && !c.editing ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (c.unreadCount > 0 && !c.editing) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 2,
                                      ),
                                      child: Text(
                                        '읽지 않은 알림 ${c.unreadCount}건',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    );
                                  }
                                  index -= 1;
                                }
                                final item = c.items[index];
                                return _DismissibleNotification(
                                  key: ValueKey('${item.id}_${item.isRead}'),
                                  item: item,
                                  editing: c.editing,
                                  selected: c.selectedIds.contains(item.id),
                                  timeLabel: _dateFmt
                                      .format(item.timestamp.toLocal()),
                                  enabled: !c.busy,
                                  onToggle: () => c.toggleSelect(item.id),
                                  onTap: () async {
                                    if (c.editing) {
                                      c.toggleSelect(item.id);
                                      return;
                                    }
                                    // 스택 pop 전에 저장소에 읽음 확정
                                    await c.markOneRead(item.id);
                                    if (!context.mounted) return;
                                    NotificationRouter.openFromNotification(
                                      item,
                                    );
                                  },
                                  onLongPress: () =>
                                      c.enterEditMode(selectId: item.id),
                                  confirmDismiss: _confirmSwipeDelete,
                                  onDismissed: () => _commitSwipeDelete(item),
                                );
                              },
                            ),
                ),
              ),
              if (c.items.isNotEmpty)
                _InboxActionBar(
                  enabled: !c.busy,
                  selectionMode: c.editing && c.hasSelection,
                  selectedCount: c.selectedCount,
                  onMarkRead: _onMarkRead,
                  onDelete: _onDelete,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectAllBar extends StatelessWidget {
  const _SelectAllBar({
    required this.checked,
    required this.onChanged,
    required this.label,
  });

  final bool checked;
  final ValueChanged<bool?>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FA),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: onChanged,
                activeColor: AppColors.primary,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            '새로운 알림이 없습니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '근무 배정·교대 요청이 오면 여기에 표시됩니다.\n아래로 당겨 새로고침 할 수 있어요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DismissibleNotification extends StatelessWidget {
  const _DismissibleNotification({
    super.key,
    required this.item,
    required this.editing,
    required this.selected,
    required this.timeLabel,
    required this.enabled,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  final NotificationItem item;
  final bool editing;
  final bool selected;
  final String timeLabel;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function() confirmDismiss;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction:
          editing ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.holiday.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.holiday,
        ),
      ),
      child: _NotificationTile(
        item: item,
        editing: editing,
        selected: selected,
        timeLabel: timeLabel,
        onToggle: enabled ? onToggle : () {},
        onTap: enabled ? onTap : () {},
        onLongPress: enabled ? onLongPress : () {},
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.editing,
    required this.selected,
    required this.timeLabel,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
  });

  final NotificationItem item;
  final bool editing;
  final bool selected;
  final String timeLabel;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
          color: AppColors.textPrimary,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: unread ? AppColors.textSection : AppColors.textSecondary,
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        );

    return DecoratedBox(
      decoration: AppDecorations.borderedSurface(radius: 14).copyWith(
        color: unread ? const Color(0xFFF8F9FA) : Colors.white,
        border: Border.all(
          color: selected && editing ? AppColors.primary : AppColors.border,
          width: selected && editing ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.fromLTRB(editing ? 4 : 14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (editing)
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              item.title,
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            unread ? '안읽음' : '읽음',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: unread
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: bodyStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.targetRoute.isNotEmpty
                                  ? '${item.typeLabelKo} · ${item.targetRoute}'
                                  : item.typeLabelKo,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.accentMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxActionBar extends StatelessWidget {
  const _InboxActionBar({
    required this.enabled,
    required this.selectionMode,
    required this.selectedCount,
    required this.onMarkRead,
    required this.onDelete,
  });

  final bool enabled;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final readLabel =
        selectionMode ? '선택 읽음 ($selectedCount)' : '모두 읽음';
    final deleteLabel =
        selectionMode ? '선택 삭제 ($selectedCount)' : '전체삭제';

    return DecoratedBox(
      decoration: AppDecorations.topHairline,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? onMarkRead : null,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(
                    readLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? onDelete : null,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    deleteLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.holiday,
                    side: BorderSide(
                      color: AppColors.holiday.withValues(alpha: 0.35),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
