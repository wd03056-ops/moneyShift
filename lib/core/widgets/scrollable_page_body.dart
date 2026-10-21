import 'package:flutter/material.dart';

/// 스크롤 가능한 본문.
///
/// - [Scaffold.body]에 직접 두거나
/// - [FixedBottomPage]의 스크롤 영역으로만 사용하세요.
/// - **이 위젯 안(자식)에 [Expanded]/[Flexible]을 넣지 마세요.**
class AppScrollView extends StatelessWidget {
  const AppScrollView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.top = true,
    this.bottom = true,
    this.physics,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool top;
  final bool bottom;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          return SingleChildScrollView(
            physics: physics ??
                const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: maxW.isFinite
                ? SizedBox(width: maxW, child: child)
                : child,
          );
        },
      ),
    );
  }
}

/// 하위 호환 별칭
typedef ScrollablePageBody = AppScrollView;

/// 상단/중앙은 스크롤, 하단 액션은 고정.
///
/// ```
/// Column
///   Expanded → AppScrollView(content)   // 스크롤
///   bottom                              // 고정 (StickyActionBar 등)
/// ```
class FixedBottomPage extends StatelessWidget {
  const FixedBottomPage({
    super.key,
    required this.body,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.safeTop = false,
  });

  /// 스크롤 영역 콘텐츠 ([Expanded]/[Flexible] 금지)
  final Widget body;

  /// 화면 하단 고정 영역 (버튼 바 등). null이면 스크롤만.
  final Widget? bottom;

  final EdgeInsetsGeometry padding;

  /// AppBar가 없을 때 true
  final bool safeTop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AppScrollView(
            top: safeTop,
            bottom: false,
            padding: padding,
            child: body,
          ),
        ),
        ?bottom,
      ],
    );
  }
}

/// 하위 호환 — [FixedBottomPage]와 동일
class ScrollableTabScaffold extends StatelessWidget {
  const ScrollableTabScaffold({
    super.key,
    required this.child,
    this.bottomBar,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final Widget child;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return FixedBottomPage(
      body: child,
      bottom: bottomBar,
      padding: padding,
    );
  }
}
