import 'package:flutter/material.dart';

/// 앱 공통 토글 — ON: 초록 트랙 + 흰 썸 / OFF: 회색 트랙 + 흰 썸
class OutlinedToggle extends StatelessWidget {
  const OutlinedToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const Color onTrack = Color(0xFF34C759);
  static const Color offTrack = Color(0xFFE5E5EA);
  /// bodyLarge(~16) 옆 비율에 맞춘 콤팩트 사이즈
  static const double width = 40;
  static const double height = 22;
  static const double thumb = 18;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? onTrack : offTrack,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: enabled
                    ? const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 수당 옵션 행 (제목·설명 + [OutlinedToggle])
class AllowanceOptionTile extends StatelessWidget {
  const AllowanceOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8B95A1),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
