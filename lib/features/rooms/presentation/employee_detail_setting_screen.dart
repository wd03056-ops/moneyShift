import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/outlined_toggle.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../../../services/payroll_calculator.dart';

/// 사장님 — 직원별 기본 시급·휴게·수당 계약 설정
class EmployeeDetailSettingScreen extends StatefulWidget {
  const EmployeeDetailSettingScreen({
    super.key,
    required this.roomId,
    required this.member,
  });

  final String roomId;
  final RoomMemberModel member;

  @override
  State<EmployeeDetailSettingScreen> createState() =>
      _EmployeeDetailSettingScreenState();
}

class _EmployeeDetailSettingScreenState
    extends State<EmployeeDetailSettingScreen> {
  late final TextEditingController _wageCtrl;
  late BreakTimeType _breakType;
  late int _fixedBreak;
  late bool _weekPay;
  late bool _nightPay;
  late bool _overtimePay;
  bool _saving = false;

  static const _fixedBreakOptions = [0, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    final c = widget.member.contract;
    _wageCtrl = TextEditingController(
      text: NumberFormat('#,###').format(c.hourlyWage),
    );
    _breakType = c.breakTimeType;
    _fixedBreak = c.fixedBreakMinutes;
    _weekPay = c.isWeekPayEnabled;
    _nightPay = c.isNightPayEnabled;
    _overtimePay = c.isOvertimePayEnabled;
  }

  @override
  void dispose() {
    _wageCtrl.dispose();
    super.dispose();
  }

  int get _parsedWage {
    final v = int.tryParse(_wageCtrl.text.replaceAll(',', '').trim());
    return (v != null && v > 0) ? v : AppConstants.minimumHourlyWage;
  }

  void _applyMinimumWage() {
    setState(() {
      _wageCtrl.text =
          NumberFormat('#,###').format(AppConstants.minimumHourlyWage);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      MockStore.instance.updateEmployeeContract(
        roomId: widget.roomId,
        workerId: widget.member.userId,
        contract: EmployeeContractModel(
          hourlyWage: _parsedWage,
          breakTimeType: _breakType,
          fixedBreakMinutes: _fixedBreak,
          isWeekPayEnabled: _weekPay,
          isNightPayEnabled: _nightPay,
          isOvertimePayEnabled: _overtimePay,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('직원 기본 설정을 저장했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.member.displayName} · 기본 설정'),
        surfaceTintColor: Colors.transparent,
      ),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '근무 배정 시 기본값으로 불러옵니다. '
              '개별 배정에서 바꾼 값은 이 프로필에 영향을 주지 않습니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text('기본 시급', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _wageCtrl,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              autocorrect: false,
              enableSuggestions: false,
              spellCheckConfiguration:
                  const SpellCheckConfiguration.disabled(),
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              style: const TextStyle(decoration: TextDecoration.none),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsSeparatorFormatter(),
              ],
              decoration: InputDecoration(
                suffixText: '원',
                border: const OutlineInputBorder(),
                hintText: '${AppConstants.minimumHourlyWage}',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _applyMinimumWage,
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: Text(
                  '최저시급 적용 (${AppConstants.minimumWageYear}년 '
                  '${NumberFormat('#,###').format(AppConstants.minimumHourlyWage)}원)',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('휴게시간', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final type in BreakTimeType.values) ...[
                        if (type != BreakTimeType.values.first)
                          const SizedBox(width: 8),
                        Expanded(
                          child: AppSelectChip(
                            label: type.labelKo,
                            selected: _breakType == type,
                            expand: true,
                            onTap: _saving
                                ? null
                                : () => setState(() => _breakType = type),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (_breakType) {
                      BreakTimeType.auto =>
                        '4시간↑ 30분 · 8시간↑ 60분 자동 적용',
                      BreakTimeType.fixed =>
                        '배정 시 아래 고정 분을 기본으로 불러옵니다.',
                      BreakTimeType.none => '휴게 없이 0분으로 배정에 불러옵니다.',
                    },
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_breakType == BreakTimeType.fixed) ...[
                    const SizedBox(height: 12),
                    Text(
                      '고정 휴게(분)',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppOptionPickerField<int>(
                      title: '고정 휴게시간 선택',
                      enabled: !_saving,
                      selected: _fixedBreakOptions.contains(_fixedBreak)
                          ? _fixedBreak
                          : 60,
                      options: [
                        for (final m in _fixedBreakOptions)
                          AppPickerOption(
                            value: m,
                            label: m == 0 ? '없음' : '$m분',
                          ),
                      ],
                      onSelected: (v) => setState(() => _fixedBreak = v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('수당 옵션', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  AllowanceOptionTile(
                    title: '주휴수당 포함',
                    subtitle:
                        '주 ${PayrollCalculator.weeklyHolidayThresholdHours.toStringAsFixed(0)}시간 이상 근무 시 '
                        '주휴수당이 발생할 수 있습니다. '
                        '(근무시간÷40)×8×시급으로 일할 반영',
                    value: _weekPay,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _weekPay = v),
                  ),
                  const Divider(height: 1),
                  AllowanceOptionTile(
                    title: '야간수당 포함',
                    subtitle: '22시~06시 구간에 시급의 0.5배를 가산합니다.',
                    value: _nightPay,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _nightPay = v),
                  ),
                  const Divider(height: 1),
                  AllowanceOptionTile(
                    title: '연장수당 포함',
                    subtitle: '1일 8시간 초과분에 시급의 0.5배를 가산합니다.',
                    value: _overtimePay,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _overtimePay = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.buttonFill,
                foregroundColor: AppColors.buttonOnFill,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final n = int.parse(digits);
    final formatted = NumberFormat('#,###').format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
