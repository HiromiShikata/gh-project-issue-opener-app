import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

List<String> parseOpenAllUrls(String payloadJson) {
  final dynamic decoded = json.decode(payloadJson);
  if (decoded is List<dynamic>) {
    return decoded.cast<String>();
  }
  if (decoded is Map<String, dynamic>) {
    final List<String> urls =
        (decoded['urls'] as List<dynamic>).cast<String>();
    final int limit = (decoded['limit'] as num?)?.toInt() ?? 0;
    return selectUrlsForBulkOpen(urls, limit: limit);
  }
  return <String>[];
}

List<String> selectUrlsForBulkOpen(
  List<String> displayedUrls, {
  required int limit,
}) {
  if (limit <= 0 || limit >= displayedUrls.length) {
    return List<String>.from(displayedUrls);
  }
  return displayedUrls.take(limit).toList();
}

const String _fallbackUrl = 'https://github.com/users/HiromiShikata/projects/48/views/16';

bool isAllowedWebViewUrl(String? url) {
  if (url == null || url.isEmpty) {
    return false;
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return uri.scheme.toLowerCase() == 'https' &&
      uri.host.toLowerCase() == 'github.com' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);
}

bool shouldHandleNativeAppMessage(String? currentUrl) {
  return isAllowedWebViewUrl(currentUrl);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub WebView App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  String? _currentUrl;
  static const platform = MethodChannel('com.example.github_webview_app/tasker');

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final String requestedUrl = await _getInitialUrl();
    final String initialUrl =
        isAllowedWebViewUrl(requestedUrl) ? requestedUrl : _fallbackUrl;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'NativeApp',
        onMessageReceived: (JavaScriptMessage message) async {
          if (!shouldHandleNativeAppMessage(_currentUrl)) {
            return;
          }
          if (message.message.startsWith('OPEN_ALL_URLS:')) {
            final String urlsJson = message.message.substring(14);
            await _handleOpenAllUrls(urlsJson);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return isAllowedWebViewUrl(request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onUrlChange: (UrlChange change) {
            _currentUrl = change.url;
          },
          onPageStarted: (String url) {
            _currentUrl = url;
            _controller?.runJavaScript('''
              var viewport = document.querySelector('meta[name="viewport"]');
              if (viewport) {
                viewport.content = 'width=device-width, initial-scale=0.4, maximum-scale=2.0, user-scalable=yes';
              }
            ''');
          },
          onPageFinished: (String url) {
            _injectCustomJS();
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));

    setState(() {
      _controller = controller;
    });
  }

  Future<String> _getInitialUrl() async {
    try {
      final String result = await platform.invokeMethod('getInitialUrl');
      if (result.isNotEmpty) {
        return result;
      }
      return _fallbackUrl;
    } on PlatformException catch (e) {
      print("Failed to get initial URL: '${e.message}'.");
      return _fallbackUrl;
    }
  }

  void _injectCustomJS() {
    _controller?.runJavaScript('''
      // Set viewport
      var viewport = document.querySelector('meta[name="viewport"]');
      if (viewport) {
        viewport.content = 'width=device-width, initial-scale=0.4, maximum-scale=2.0, user-scalable=yes';
      } else {
        viewport = document.createElement('meta');
        viewport.name = 'viewport';
        viewport.content = 'width=device-width, initial-scale=0.4, maximum-scale=2.0, user-scalable=yes';
        document.head.appendChild(viewport);
      }

      // Force desktop mode
      document.body.style.minWidth = 'auto';
      document.documentElement.style.minWidth = 'auto';

      document.addEventListener('click', function(e) {
        var target = e.target;
        var link = target.closest('a');
        if (link && link.href && link.href.match(/github\\.com\\/[^\\/]+\\/[^\\/]+\\/(issues|pull)\\/\\d+/)) {
          e.preventDefault();
          e.stopPropagation();
          NativeApp.postMessage('OPEN_ALL_URLS:' + JSON.stringify([link.href]));
        }
      }, true);

      window.collectDisplayedTaskUrls = function() {
        var links = document.getElementsByTagName('a');
        var uniqueUrls = new Set();
        Array.from(links).forEach(function(link) {
          if (link.href && link.href.match(/github\\.com\\/[^\\/]+\\/[^\\/]+\\/(issues|pull)\\/\\d+/)) {
            uniqueUrls.add(link.href);
          }
        });
        return Array.from(uniqueUrls);
      };

      window.openAllLinks = function() {
        var urlsArray = window.collectDisplayedTaskUrls();
        NativeApp.postMessage('OPEN_ALL_URLS:' + JSON.stringify({urls: urlsArray, limit: 0}));
      };

      window.openFirstNLinks = function(limit) {
        var urlsArray = window.collectDisplayedTaskUrls();
        NativeApp.postMessage('OPEN_ALL_URLS:' + JSON.stringify({urls: urlsArray, limit: limit}));
      };

      document.body.style.fontSize = '100%';
      var styleElement = document.createElement('style');
      styleElement.textContent = `
        body, table, .markdown-body { font-size: 12px !important; }
        .actionlistitem-leadingcontent, .user-status-container, .js-profile-editable-edit-button { display: none !important; }
        div[data-testid="slicer-panel"] { width: 100px !important; }
      `;
      document.head.appendChild(styleElement);
    ''');
  }

  Future<void> _handleOpenAllUrls(String urlsJson) async {
    try {
      final List<String> urls = parseOpenAllUrls(urlsJson);
      await platform.invokeMethod('openAllUrls', urls);
    } catch (e) {
      print('Error handling open all URLs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_controller != null)
              WebViewWidget(controller: _controller!)
            else
              const Center(child: CircularProgressIndicator()),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'openFirst10Tasks',
                    onPressed: () {
                      _controller?.runJavaScript('window.openFirstNLinks(10)');
                    },
                    icon: const Icon(Icons.filter_9_plus),
                    label: const Text('Open 10'),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'openAllTasks',
                    onPressed: () {
                      _controller?.runJavaScript('window.openAllLinks()');
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Open all'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
