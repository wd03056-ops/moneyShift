import 'package:flutter/material.dart';

import '../../../core/exceptions/room_exceptions.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';

/// 초대 코드로 방 참여 → 지정 직책으로 멤버십 합류
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  MemberRole _demoRole = MemberRole.parttime;
  bool _submitting = false; // 연타 시 중복 가입 요청 차단

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final member =
          MockStore.instance.joinWithInviteCode(_codeController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${member.displayName} · ${member.role.labelKo}으로 참여했습니다. (목업)',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on InviteInvalidException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on AlreadyRoomMemberException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on NotAuthenticatedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('참여 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _seedAndJoin() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final invite = MockStore.instance.seedInviteFromOtherOwner(
        role: _demoRole,
      );
      final member = MockStore.instance.joinWithInviteCode(invite.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '데모 초대(${invite.code})로 ${member.role.labelKo} 참여 완료',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데모 참여 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final active = MockStore.instance.joinableInvites();

        return Scaffold(
          appBar: AppBar(title: const Text('초대 코드로 들어가기')),
          body: Form(
            key: _formKey,
            child: ScrollablePageBody(
              top: false,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '초대코드를 입력하세요.\n'
                    '초대에 지정된 직책으로 자동 등록됩니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FormField<String>(
                    validator: (_) {
                      final v = _codeController.text;
                      return v.trim().isEmpty ? '초대 코드를 입력하세요' : null;
                    },
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppBorderedField(
                            child: TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                              enableSuggestions: false,
                              spellCheckConfiguration:
                                  const SpellCheckConfiguration.disabled(),
                              style: const TextStyle(
                                decoration: TextDecoration.none,
                              ),
                              decoration: const InputDecoration(
                                labelText: '초대 코드',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (value) {
                                field.didChange(value);
                                if (field.hasError) field.validate();
                              },
                            ),
                          ),
                          if (field.hasError && field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                field.errorText!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: AppDecorations.borderedSurface(radius: 12),
                    child: FilledButton(
                      style: const ButtonStyle(
                        backgroundColor:
                            WidgetStatePropertyAll(Colors.transparent),
                        foregroundColor:
                            WidgetStatePropertyAll(Color(0xFF212529)),
                        elevation: WidgetStatePropertyAll(0),
                        side: WidgetStatePropertyAll(BorderSide.none),
                      ),
                      onPressed: _submitting ? null : _join,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('방 들어가기'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  Text(
                    '단일 계정 멀티역할 테스트',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '다른 사장이 초대한 것처럼 데모 매장을 만들고,\n'
                    '선택한 직책으로 바로 참여합니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '데모 초대 직책',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  AppOptionPickerField<MemberRole>(
                    title: '데모 초대 직책 선택',
                    enabled: !_submitting,
                    selected: _demoRole,
                    options: [
                      for (final role in [
                        MemberRole.parttime,
                        MemberRole.staff,
                        MemberRole.manager,
                      ])
                        AppPickerOption(
                          value: role,
                          label: '${role.labelKo} (${role.firestoreValue})',
                        ),
                    ],
                    onSelected: (v) => setState(() => _demoRole = v),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: AppDecorations.borderedSurface(radius: 12),
                    child: OutlinedButton(
                      style: const ButtonStyle(
                        backgroundColor:
                            WidgetStatePropertyAll(Colors.transparent),
                        elevation: WidgetStatePropertyAll(0),
                        side: WidgetStatePropertyAll(BorderSide.none),
                      ),
                      onPressed: _submitting ? null : _seedAndJoin,
                      child: const Text('데모 초대로 직원 참여 시뮬레이션'),
                    ),
                  ),
                  if (active.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '참여 가능한 초대',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final invite in active)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(invite.code),
                        subtitle: Text('직책 ${invite.role.labelKo}'),
                        trailing: TextButton(
                          onPressed: () {
                            _codeController.text = invite.code;
                          },
                          child: const Text('선택'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
