import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import 'app_card.dart';

/// 옵션 한 줄 (값 + 표시 라벨)
class AppPickerOption<T> {
  const AppPickerOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 바텀시트로 항목을 고르는 공통 피커
Future<T?> showAppOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<AppPickerOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = selected != null &&
                        opt.value == selected;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, opt.value),
                      child: Container(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                opt.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                size: 22,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 터치하면 바텀시트가 열리는 선택 필드 (드롭다운 대체)
class AppOptionPickerField<T> extends StatelessWidget {
  const AppOptionPickerField({
    super.key,
    required this.title,
    required this.options,
    required this.onSelected,
    this.selected,
    this.hint = '선택하세요',
    this.enabled = true,
    this.height = 52,
  });

  final String title;
  final List<AppPickerOption<T>> options;
  final ValueChanged<T> onSelected;
  final T? selected;
  final String hint;
  final bool enabled;
  final double height;

  String get _displayLabel {
    if (selected == null) return hint;
    for (final o in options) {
      if (o.value == selected) return o.label;
    }
    return hint;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    final picked = await showAppOptionPicker<T>(
      context: context,
      title: title,
      options: options,
      selected: selected,
    );
    if (picked == null) return;
    onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final empty = options.isEmpty;
    final label = empty ? '선택 가능한 항목이 없습니다' : _displayLabel;
    final isHint = selected == null || empty;

    return AppBorderedField(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !empty ? () => _open(context) : null,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: !enabled || isHint
                          ? AppColors.textSecondary
                          : const Color(0xFF191F28),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: enabled
                      ? AppColors.textCaption
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
