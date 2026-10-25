import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/exceptions/room_exceptions.dart';
import '../../../core/navigation/room_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/async_action_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../services/room_invite_service.dart';

/// 초대 코드 1칸 → 코드에 묶인 직책(기본/커스텀)으로 자동 가입
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  final _joinGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _inviteService = RoomInviteService();
  bool _submitting = false;

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

    await _joinGuard.run(() async {
      if (!mounted) return;
      setState(() => _submitting = true);
      try {
        final member = await _inviteService.joinWithInviteCode(
          _codeController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.displayName} · ${member.roleLabel}으로 참여했습니다.',
            ),
          ),
        );
        final joinedRoomId = member.roomId;
        Navigator.of(context).pop();
        // 가입한 방만 열어 기존 방 화면/배정 상태와 섞이지 않게 함
        RoomNavigation.openRoom(roomId: joinedRoomId);
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
      } on RoomNotFoundException catch (e) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                '초대코드를 입력해주세요.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FormField<String>(
                validator: (_) {
                  final v = _codeController.text.trim();
                  if (v.isEmpty) return '초대코드를 입력해주세요.';
                  if (!RegExp(r'^\d+$').hasMatch(v)) {
                    return '초대 코드는 숫자만 입력할 수 있습니다';
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppBorderedField(
                        child: TextField(
                          controller: _codeController,
                          enabled: !_submitting,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          spellCheckConfiguration:
                              const SpellCheckConfiguration.disabled(),
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            decoration: TextDecoration.none,
                          ),
                          decoration: InputDecoration(
                            hintText: '초대코드',
                            hintStyle: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.none,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (value) {
                            field.didChange(value);
                            if (field.hasError) field.validate();
                          },
                          onSubmitted: (_) {
                            if (!_submitting) _join();
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _join,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '방 들어가기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
