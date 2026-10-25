import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';

/// 호스팅된 약관·개인정보 문서를 인앱 WebView로 표시
class LegalWebScreen extends StatefulWidget {
  const LegalWebScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<LegalWebScreen> createState() => _LegalWebScreenState();
}

class _LegalWebScreenState extends State<LegalWebScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '문서를 불러오지 못했습니다.\n네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textCaption,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _failed = false;
                          _loading = true;
                        });
                        _controller.loadRequest(Uri.parse(widget.url));
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_loading && !_failed)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
