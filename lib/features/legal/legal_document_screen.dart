import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/scrollable_page_body.dart';

/// 개인정보처리방침·이용약관 등 인앱 전문
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lines = body.trim().split('\n');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines) _LegalLine(line: line, textTheme: textTheme),
          ],
        ),
      ),
    );
  }
}

class _LegalLine extends StatelessWidget {
  const _LegalLine({required this.line, required this.textTheme});

  final String line;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox(height: 10);

    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(
          line.substring(2),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          line.substring(3),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (line.startsWith('|') || line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          line,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textCaption,
            height: 1.45,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        line,
        style: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}
