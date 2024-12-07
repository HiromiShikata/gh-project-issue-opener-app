import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io' show Platform;
import 'dart:convert';

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
  static const platform = MethodChannel('com.example.github_webview_app/tasker');

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    String initialUrl = await _getInitialUrl();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message.startsWith('OPEN_URL:')) {
            final String url = message.message.substring(9);
            _launchURL(url);
          } else if (message.message.startsWith('OPEN_ALL_URLS:')) {
            final String urlsJson = message.message.substring(14);
            _handleOpenAllUrls(urlsJson);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
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
      return 'https://github.com/users/HiromiShikata/projects/48/views/16';
    } on PlatformException catch (e) {
      print("Failed to get initial URL: '${e.message}'.");
      return 'https://github.com/users/HiromiShikata/projects/48/views/16';
    }
  }

  void _injectCustomJS() {
    _controller?.runJavaScript('''
      document.addEventListener('click', function(e) {
        var target = e.target;
        var container = target.closest('[data-testid="table-scroll-container"]');
        if (container) {
          e.preventDefault();
          e.stopPropagation();
          var link = target.closest('a');
          if (link) {
            Flutter.postMessage('OPEN_URL:' + link.href);
          }
        }
      }, true);

      window.openAllLinks = function() {
        var container = document.querySelector('[data-testid="table-scroll-container"]');
        if (container) {
          var links = container.querySelectorAll('a');
          var uniqueUrls = new Set();
          links.forEach(function(link) {
            if (link.href) {
              uniqueUrls.add(link.href);
            }
          });
          var urlsArray = Array.from(uniqueUrls);
          Flutter.postMessage('OPEN_ALL_URLS:' + JSON.stringify(urlsArray));
        }
      };

      document.body.style.fontSize = '80%';
      var styleElement = document.createElement('style');
      styleElement.textContent = `
        body, table, .markdown-body { font-size: 12px !important; }
        .actionlistitem-leadingcontent, .user-status-container, .js-profile-editable-edit-button { display: none !important; }
        div[data-testid="slicer-panel"] { width: 100px !important; }
      `;
      document.head.appendChild(styleElement);
    ''');
  }

  void _handleOpenAllUrls(String urlsJson) {
    try {
      final List<dynamic> urls = json.decode(urlsJson);
      for (final String url in urls) {
        _launchURL(url);
      }
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
              child: FloatingActionButton(
                onPressed: () {
                  _controller?.runJavaScript('window.openAllLinks()');
                },
                child: const Icon(Icons.link),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (Platform.isAndroid) {
      final AndroidIntent intent = AndroidIntent(
        action: 'action_view',
        data: url,
        package: 'com.android.chrome',
      );
      try {
        await intent.launch();
      } catch (e) {
        print('Error launching URL with Android Intent: $e');
      }
    } else {
      print('URL launching is only supported on Android');
    }
  }
}