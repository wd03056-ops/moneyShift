import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/outlined_toggle.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';

/// 매장 공지사항 — 사장 작성/삭제, 직원 읽기·확인
class NoticeBoardScreen extends StatelessWidget {
  const NoticeBoardScreen({
    super.key,
    required this.room,
    required this.canManage,
  });

  final RoomModel room;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final uid = MockSession.instance.requireUid;
    final dateFmt = DateFormat('M월 d일 HH:mm', 'ko_KR');

    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final notices = MockStore.instance.noticesForRoom(room.id);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('매장 공지사항'),
          ),
          floatingActionButton: canManage
              ? FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 2,
                  onPressed: () => _openCompose(context),
                  child: const Icon(Icons.add),
                )
              : null,
          body: ScrollablePageBody(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  canManage
                      ? '공지를 작성·삭제할 수 있어요'
                      : '필독 공지는 확인 후 ‘확인함’으로 표시됩니다',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                if (notices.isEmpty)
                  AppCard(
                    child: Text(
                      '등록된 공지가 없습니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                else
                  for (final n in notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => _openDetail(context, n),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (n.isImportant) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '필독',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    n.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                ),
                                if (!n.isReadBy(uid))
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${n.authorName} · ${n.createdAt != null ? dateFmt.format(n.createdAt!) : '-'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ),
                                if (n.isReadBy(uid)) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '확인함',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ],
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

  Future<void> _openCompose(BuildContext context) async {
    await AppNavigation.pushSingleTop(
      name: AppRouteNames.noticeCompose(room.id),
      stopAtNames: [AppRouteNames.noticeBoard(room.id)],
      builder: (_) => _NoticeComposeScreen(roomId: room.id),
    );
  }

  Future<void> _openDetail(BuildContext context, NoticeModel notice) async {
    await AppNavigation.pushSingleTop(
      name: AppRouteNames.noticeDetail(notice.id),
      stopAtNames: [AppRouteNames.noticeBoard(room.id)],
      builder: (_) => NoticeDetailScreen(
        noticeId: notice.id,
        canManage: canManage,
      ),
    );
  }
}

class _NoticeComposeScreen extends StatefulWidget {
  const _NoticeComposeScreen({required this.roomId});

  final String roomId;

  @override
  State<_NoticeComposeScreen> createState() => _NoticeComposeScreenState();
}

class _NoticeComposeScreenState extends State<_NoticeComposeScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _important = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      MockStore.instance.createNotice(
        roomId: widget.roomId,
        title: _titleCtrl.text,
        body: _bodyCtrl.text,
        isImportant: _important,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('공지 작성')),
      body: ScrollablePageBody(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('제목', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppBorderedField(
              height: 52,
              child: AppPlainTextField(
                controller: _titleCtrl,
                hintText: '공지 제목',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191F28),
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF8B95A1),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('내용', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppBorderedField(
              height: null,
              child: AppPlainTextField(
                controller: _bodyCtrl,
                maxLines: 8,
                minLines: 5,
                hintText: '공지 내용을 입력하세요',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF191F28),
                  height: 1.4,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF8B95A1),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '필독 공지',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                OutlinedToggle(
                  value: _important,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _important = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StickyActionButton(
              label: '등록하기',
              variant: StickyActionVariant.filled,
              onPressed: _saving ? null : _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

/// 공지 상세 — 알림 딥링크 `/notices/detail` 에서도 사용
class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({
    super.key,
    required this.noticeId,
    required this.canManage,
  });

  final String noticeId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy.M.d HH:mm', 'ko_KR');
    final uid = MockSession.instance.requireUid;

    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final notice = MockStore.instance.notices[noticeId];
        if (notice == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('공지를 찾을 수 없습니다.')),
          );
        }

        final read = notice.isReadBy(uid);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('공지 상세'),
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('공지 삭제'),
                        content: const Text('이 공지를 삭제할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    MockStore.instance.deleteNotice(noticeId);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          body: ScrollablePageBody(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice.isImportant)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '필독',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                Text(
                  notice.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${notice.authorName} · ${notice.createdAt != null ? dateFmt.format(notice.createdAt!) : '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    if (read) ...[
                      const SizedBox(width: 6),
                      Text(
                        '확인함',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                Text(
                  notice.body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                ),
                if (!canManage && !read) ...[
                  const SizedBox(height: 28),
                  StickyActionButton(
                    label: '확인함으로 표시',
                    variant: StickyActionVariant.primary,
                    onPressed: () {
                      MockStore.instance.markNoticeRead(noticeId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('공지를 확인했습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
