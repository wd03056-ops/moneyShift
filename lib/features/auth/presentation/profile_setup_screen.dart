import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_input_defaults.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../services/user_firestore_service.dart';

/// 카카오 로그인 후 실명 온보딩
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.uid,
    this.initialName,
  });

  final String? uid;
  final String? initialName;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _users = UserFirestoreService();
  bool _saving = false;

  String get _uid =>
      widget.uid ?? MockSession.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final hint = widget.initialName?.trim().isNotEmpty == true
        ? widget.initialName!.trim()
        : (MockSession.instance.currentUser?.displayName ?? '');
    _nameController = TextEditingController(text: hint);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '실명을 입력해 주세요.';
    if (v.length < 2) return '실명은 2자 이상이어야 합니다.';
    if (v.length > 30) return '실명은 30자 이내로 입력해 주세요.';
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final uid = _uid;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 정보가 없습니다. 다시 로그인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final realName = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      await _users.saveRealName(uid: uid, realName: realName);
      if (!mounted) return;
      MockSession.instance.completeRealNameSetup(realName);
      debugPrint('[ProfileSetup] realName saved uid=$uid');
      // MockSession notify → main home 이 MainShell 로 전환
    } catch (e, st) {
      debugPrint('[ProfileSetup] FAIL: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    // 세션만 끊으면 AuthHomeGate → LoggedOutHome → 로그인 push (뒤로가기 가능)
    MockSession.instance.logout();
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('프로필 설정'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _logout,
              child: Text(
                '로그아웃',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: FixedBottomPage(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            bottom: StickyActionBar(
              children: [
                StickyActionButton(
                  label: '확인',
                  variant: StickyActionVariant.filled,
                  isLoading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '실명을 입력해 주세요',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '정확한 급여 정산 및 출퇴근 관리를 위해 실명을 입력해 주세요.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.text,
                  autocorrect: AppTextInputDefaults.autocorrect,
                  enableSuggestions: AppTextInputDefaults.enableSuggestions,
                  spellCheckConfiguration:
                      AppTextInputDefaults.spellCheckConfiguration,
                  smartDashesType: AppTextInputDefaults.smartDashesType,
                  smartQuotesType: AppTextInputDefaults.smartQuotesType,
                  style: const TextStyle(decoration: TextDecoration.none),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\n')),
                    LengthLimitingTextInputFormatter(30),
                  ],
                  decoration: const InputDecoration(
                    labelText: '실명',
                    hintText: '예: 홍길동',
                  ),
                  validator: _validate,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                Text(
                  '카카오 닉네임이 아닌, 급여·근로계약에 쓰는 이름을 입력해 주세요.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textCaption,
                    fontWeight: FontWeight.w400,
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
