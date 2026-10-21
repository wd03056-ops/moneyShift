import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/scrollable_page_body.dart';
import '../../../models/models.dart';
import '../../../services/schedule_repository.dart';

class ScheduleLogsScreen extends StatelessWidget {
  const ScheduleLogsScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final repo = ScheduleRepository();
    final fmt = DateFormat('M/d HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('근무시간 변경 이력')),
      body: StreamBuilder<List<ScheduleLogModel>>(
        stream: repo.watchLogsForRoom(roomId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ScrollablePageBody(
              top: false,
              child: Text(
                '오류: ${snapshot.error}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return ScrollablePageBody(
              top: false,
              child: Text(
                '변경 이력이 없습니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ScrollablePageBody(
            top: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < logs.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(logs[i].action.labelKo),
                    subtitle: Text(
                      '${fmt.format(logs[i].previousStartTime)}~${fmt.format(logs[i].previousEndTime)}'
                      ' → ${fmt.format(logs[i].newStartTime)}~${fmt.format(logs[i].newEndTime)}\n'
                      '사유: ${logs[i].reason}\n'
                      '요청: ${logs[i].requestedBy}'
                      '${logs[i].resolvedBy != null ? ' / 처리: ${logs[i].resolvedBy}' : ''}',
                    ),
                    isThreeLine: true,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
