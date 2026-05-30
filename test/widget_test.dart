import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:github_webview_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GitHub WebView app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  group('parseOpenAllUrls', () {
    test('preserves every url without dropping the last item', () {
      final List<String> input = <String>[
        'https://github.com/owner/repo/issues/1',
        'https://github.com/owner/repo/pull/2',
        'https://github.com/owner/repo/issues/3',
      ];

      final List<String> result = parseOpenAllUrls(json.encode(input));

      expect(result, equals(input));
      expect(result.length, 3);
    });

    test('returns a single flat list for a single bulk open call', () {
      final List<String> input = <String>[
        'https://github.com/owner/repo/issues/10',
        'https://github.com/owner/repo/issues/11',
      ];

      final List<String> result = parseOpenAllUrls(json.encode(input));

      expect(result, isA<List<String>>());
      expect(result, input);
    });

    test('handles an empty url list', () {
      final List<String> result = parseOpenAllUrls(json.encode(<String>[]));

      expect(result, isEmpty);
    });
  });

  group('openAllUrls native channel', () {
    const MethodChannel channel = MethodChannel(
      'com.example.github_webview_app/tasker',
    );
    final List<MethodCall> calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('invokes openAllUrls exactly once with all urls in order', () async {
      final List<String> urls = parseOpenAllUrls(
        json.encode(<String>[
          'https://github.com/owner/repo/issues/1',
          'https://github.com/owner/repo/pull/2',
          'https://github.com/owner/repo/issues/3',
        ]),
      );

      await channel.invokeMethod('openAllUrls', urls);

      expect(calls.length, 1);
      expect(calls.single.method, 'openAllUrls');
      expect((calls.single.arguments as List<dynamic>).cast<String>(), urls);
    });
  });
}
