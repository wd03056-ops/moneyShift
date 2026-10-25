import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_input_defaults.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../services/user_firestore_service.dart';
import '../data/auth_flow_exception.dart';
import '../data/auth_integration_service.dart';

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
  final _scrollController = ScrollController();
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();
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
    _nameFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChange);
    _nameFocus.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_nameFocus.hasFocus) return;
    // 키보드·IME 툴바가 올라온 뒤 입력란이 보이도록 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
      // Firestore rules: request.auth.uid == users/{uid}
      // 카카오 Custom Token 세션이 없으면 저장 토큰으로 재인증
      await AuthIntegrationService.instance.ensureFirebaseAuthUid(uid);
      await _users.saveRealName(uid: uid, realName: realName);
      if (!mounted) return;
      MockSession.instance.completeRealNameSetup(realName);
      debugPrint('[ProfileSetup] realName saved uid=$uid');
    } on AuthFlowException catch (e, st) {
      debugPrint('[ProfileSetup] AuthFlow FAIL ${e.code}: ${e.message}');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugPrint('[ProfileSetup] FAIL: $e');
      debugPrint('$st');
      if (!mounted) return;
      final msg = e.toString();
      final friendly = msg.contains('permission-denied')
          ? '저장 권한이 없습니다. 다시 로그인한 뒤 시도해 주세요.'
          : '저장 실패: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendly),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    MockSession.instance.logout();
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // 테마 titleSpacing:0 + leading 없음 → 본문(20)과 맞춤
          titleSpacing: 20,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: Column(
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
                            AppElevatedInputShell(
                              child: TextFormField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                enabled: !_saving,
                                autofocus: true,
                                textInputAction: TextInputAction.done,
                                textCapitalization: TextCapitalization.none,
                                keyboardType: TextInputType.text,
                                autocorrect: AppTextInputDefaults.autocorrect,
                                enableSuggestions:
                                    AppTextInputDefaults.enableSuggestions,
                                spellCheckConfiguration: AppTextInputDefaults
                                    .spellCheckConfiguration,
                                smartDashesType:
                                    AppTextInputDefaults.smartDashesType,
                                smartQuotesType:
                                    AppTextInputDefaults.smartQuotesType,
                                style: const TextStyle(
                                  decoration: TextDecoration.none,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                    RegExp(r'\n'),
                                  ),
                                  LengthLimitingTextInputFormatter(30),
                                ],
                                decoration: AppTextInputDefaults.decoration(
                                  labelText: '실명',
                                  hintText: '예: 홍길동',
                                ),
                                validator: _validate,
                                onFieldSubmitted: (_) => _submit(),
                              ),
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
                    );
                  },
                ),
              ),
              StickyActionBar(
                elevated: true,
                // 키보드·IME 툴바 위에서는 시스템 inset 만 사용 (이중 SafeArea 방지)
                safeAreaBottom: !keyboardOpen,
                children: [
                  StickyActionButton(
                    label: '확인',
                    variant: StickyActionVariant.filled,
                    isLoading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
