import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 카카오 공식 디자인 가이드에 맞춘 로그인 버튼
///
/// - 배경: `#FEE500`
/// - 라벨: `#191919` (85% 불투명도에 해당하는 톤)
/// - 심볼: SDK 패키지 제공 SVG
class KakaoLoginButton extends StatelessWidget {
  const KakaoLoginButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = '카카오 로그인',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  static const Color _background = Color(0xFFFEE500);
  static const Color _label = Color(0xFF191919);

  static const String _symbolAsset =
      'packages/kakao_flutter_sdk_user/assets/images/icon_talk_login.svg';

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: _background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _label,
                    ),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SvgPicture.asset(
                      _symbolAsset,
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        _label,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _label,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
