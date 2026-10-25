import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_text_input_defaults.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_user.dart';

/// 내정보 — 프로필 수정
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;
  bool _saved = false;

  MockUser get _user => MockSession.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    final user = MockSession.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (MockSession.instance.currentUser == null) return;

    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      MockSession.instance.updateProfile(
        displayName: _nameController.text,
        email: _emailController.text,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '완료되었습니다',
        aboveStickyActions: true,
      );
      setState(() {
        _saving = false;
        _saved = true;
      });
      // 저장 후에도 수정 화면 유지
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '저장 실패: $e',
        aboveStickyActions: true,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = MockSession.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('정보 수정')),
        body: const Center(child: Text('로그인 정보가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('정보 수정')),
      body: Form(
        key: _formKey,
        child: FixedBottomPage(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          bottom: StickyActionBar(
            children: [
              StickyActionButton(
                label: '저장',
                variant: StickyActionVariant.filled,
                isLoading: _saving,
                isCompleted: _saved,
                completedLabel: '완료됨',
                onPressed: (_saving || _saved) ? null : _save,
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppElevatedInputShell(
                enabled: !_saving && !_saved,
                child: TextFormField(
                  controller: _nameController,
                  enabled: !_saving && !_saved,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: AppTextInputDefaults.autocorrect,
                  enableSuggestions: AppTextInputDefaults.enableSuggestions,
                  spellCheckConfiguration:
                      AppTextInputDefaults.spellCheckConfiguration,
                  smartDashesType: AppTextInputDefaults.smartDashesType,
                  smartQuotesType: AppTextInputDefaults.smartQuotesType,
                  style: const TextStyle(decoration: TextDecoration.none),
                  decoration: AppTextInputDefaults.decoration(
                    labelText: '이름',
                    hintText: '표시할 이름을 입력하세요',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '이름을 입력해주세요.';
                    }
                    if (v.trim().length < 2) {
                      return '이름은 2자 이상이어야 합니다.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              AppElevatedInputShell(
                enabled: !_saving && !_saved,
                child: TextFormField(
                  controller: _emailController,
                  enabled: !_saving && !_saved,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  style: const TextStyle(decoration: TextDecoration.none),
                  decoration: AppTextInputDefaults.decoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                  ),
                  onFieldSubmitted: (_) => _save(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '이메일을 입력해주세요.';
                    }
                    final email = v.trim();
                    if (!email.contains('@') || !email.contains('.')) {
                      return '올바른 이메일 형식이 아닙니다.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '사용자 ID는 테스트 계정 식별용으로 변경할 수 없습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID · ${_user.uid}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
