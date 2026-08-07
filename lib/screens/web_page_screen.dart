import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_palette.dart';
import '../widgets/glass.dart';

/// In-app browser used for the Privacy Policy and Support pages. Those two are
/// the only parts of the app that need a connection, so the offline state is
/// handled explicitly instead of showing a dead white page.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  WebViewController? _controller;
  int _progress = 0;
  bool _failed = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // The pages are light documents: a white canvas avoids a dark flash
        // and unreadable text while they load.
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            },
            onPageStarted: (_) {
              if (mounted) setState(() => _failed = false);
            },
            onPageFinished: (_) {
              // Page finished successfully — clear any stale error state that
              // may have been set by an out-of-order resource callback.
              if (mounted) setState(() { _progress = 100; _failed = false; });
            },
            onHttpError: (error) {
              final status = error.response?.statusCode ?? 0;
              if (mounted && status >= 400) {
                setState(() {
                  _failed = true;
                  _error = 'The server answered with $status.';
                });
              }
            },
            onWebResourceError: (error) {
              if (!mounted) return;
              // isForMainFrame == null  → sub-resource, not our problem.
              // isForMainFrame == false → sub-resource, not our problem.
              if (error.isForMainFrame != true) return;
              // ERR_ABORTED fires when a previous load is cancelled by a
              // reload, JS redirect, or back/forward navigation; it does
              // NOT mean the new page failed to load — ignore it.
              final desc = error.description.toLowerCase();
              if (desc.contains('err_aborted')) return;
              setState(() {
                _failed = true;
                _error = error.description;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
      _controller = controller;
    } catch (error) {
      setState(() {
        _failed = true;
        _error = error.toString();
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _failed = false;
      _progress = 0;
      _error = '';
    });
    try {
      await _controller?.loadRequest(Uri.parse(widget.url));
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _error = error.toString();
        });
      }
    }
  }

  /// Back walks the page history first, then leaves the screen.
  Future<void> _handleBack() async {
    final controller = _controller;
    if (!_failed && controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _progress < 100 && !_failed;
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AetherColors.deep,
          foregroundColor: AetherColors.ivory,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 2,
                    backgroundColor: AetherColors.deep,
                    valueColor: const AlwaysStoppedAnimation(AetherColors.electric),
                  ),
                )
              : null,
        ),
        body: _failed || controller == null
            ? _OfflineState(url: widget.url, error: _error, onRetry: _reload)
            : SafeArea(child: WebViewWidget(controller: controller)),
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.url, required this.error, required this.onRetry});

  final String url;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AetherColors.backdrop),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: GlassPanel(
            radius: 26,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44, color: AetherColors.goldLight),
                const SizedBox(height: 14),
                const Text(
                  'This page needs a connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Everything else in Bolt of Aether keeps working offline. '
                  'Reconnect and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.4, color: AetherColors.muted),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: AetherColors.electric),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    maxLines: 3,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AetherColors.muted),
                  ),
                ],
                const SizedBox(height: 18),
                BoltButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  expand: false,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
