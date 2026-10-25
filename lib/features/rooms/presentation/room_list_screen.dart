import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/navigation/room_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/app_listenables.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../widgets/room_role_badge.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

/// 통합 초기 화면 — 모던 카드형 방 리스트 홈
class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  bool _editing = false;

  void _openCreate(BuildContext context) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.createRoom,
      builder: (_) => const CreateRoomScreen(),
    );
  }

  void _openJoin(BuildContext context) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.joinRoom,
      builder: (_) => const JoinRoomScreen(),
    );
  }

  void _openDetail(BuildContext context, RoomMembershipEntry entry) {
    RoomNavigation.openRoom(
      roomId: entry.room.id,
      entry: entry,
    );
  }

  Future<void> _renameRoom(
    BuildContext context,
    RoomMembershipEntry entry,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameRoomDialog(initialName: entry.room.name),
    );
    if (result == null || !context.mounted) return;

    try {
      MockStore.instance.renameRoom(
        roomId: entry.room.id,
        name: result,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('매장명이 변경되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = MockSession.instance.currentUser!;

    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final liveUser = MockSession.instance.currentUser ?? user;
        final entries = MockStore.instance.myRoomEntries();
        final canEditRooms =
            entries.any((e) => e.role.isAdminDashboard);

        // MainShell Scaffold 중첩 시 AppBar 가 상태바와에 겹칠 수 있어
        // SafeArea + 상단 액션 바로 구성한다.
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HomeAppBar(),
                Expanded(
                  child: AppScrollView(
                    top: false,
                    bottom: false,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HomeHeader(
                          displayName: liveUser.preferredDisplayName,
                        ),
                        if (entries.isEmpty)
                          _EmptyRoomState(
                            onCreate: () => _openCreate(context),
                            onJoin: () => _openJoin(context),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _editing
                                        ? '매장을 선택해 이름을 바꾸세요'
                                        : '근무지 목록',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                if (canEditRooms)
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _editing = !_editing);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _editing ? '완료' : '수정하기',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _editing
                                                ? AppColors.success
                                                : AppColors.accentMuted,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (var i = 0; i < entries.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _RoomListCard(
                              entry: entries[i],
                              editing: _editing,
                              onTap: () {
                                final entry = entries[i];
                                if (_editing && entry.role.isAdminDashboard) {
                                  _renameRoom(context, entry);
                                  return;
                                }
                                if (_editing) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '초대받은 매장명은 수정할 수 없습니다.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _openDetail(context, entry);
                              },
                            ),
                          ],
                        ],
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

/// 상태바 아래 고정 — 제목 (중첩 Scaffold AppBar 대체)
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '근무일지',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _RenameRoomDialog extends StatefulWidget {
  const _RenameRoomDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameRoomDialog> createState() => _RenameRoomDialogState();
}

class _RenameRoomDialogState extends State<_RenameRoomDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('매장명 변경'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        style: const TextStyle(decoration: TextDecoration.none),
        decoration: const InputDecoration(
          hintText: '매장명',
          labelText: '매장명',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Text(
        '$displayName 님',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RoomListCard extends StatelessWidget {
  const _RoomListCard({
    required this.entry,
    required this.onTap,
    this.editing = false,
  });

  final RoomMembershipEntry entry;
  final VoidCallback onTap;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final room = entry.room;
    final canRename = editing && entry.role.isAdminDashboard;

    return AppCard(
      onTap: onTap,
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (canRename)
                      const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      )
                    else
                      RoomRoleBadge(role: entry.role),
                  ],
                ),
                if (editing && canRename) ...[
                  const SizedBox(height: 12),
                  const _InfoChip(label: '탭하여 매장명 변경'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _EmptyRoomState extends StatelessWidget {
  const _EmptyRoomState({
    required this.onCreate,
    required this.onJoin,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '아직 참여 중인 매장이 없어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '새 매장을 만들면 사장으로,\n'
            '초대 코드로 들어가면 직원으로 시작할 수 있어요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCreate,
                  child: const Text('방 만들기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onJoin,
                  child: const Text('초대 코드'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
