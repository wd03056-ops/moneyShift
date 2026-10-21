import 'package:flutter/material.dart';

/// 표준근로계약서 기준 참고용 면책 문구
class PayDisclaimerCaption extends StatelessWidget {
  const PayDisclaimerCaption({
    super.key,
    this.padding = const EdgeInsets.only(top: 8),
  });

  final EdgeInsetsGeometry padding;

  static const String message =
      '본 산정 내역은 입력된 소정근로시간을 바탕으로 작성된 참고용 예상 금액입니다. '
      '주 15시간 미만 근무, 지각·조퇴, 5인 미만 사업장 여부 등 '
      '실제 근로 조건 및 세액 공제에 따라 실제 지급액은 달라질 수 있습니다.';

  static const TextStyle style = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF8B95A1),
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(message, style: style),
    );
  }
}
