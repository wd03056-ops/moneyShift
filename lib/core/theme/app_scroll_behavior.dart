import 'package:flutter/material.dart';

/// Android Material 3 오버스크롤 stretch로 카드·콘텐츠가
/// 끝없이 늘어나 보이는 현상을 막습니다.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
