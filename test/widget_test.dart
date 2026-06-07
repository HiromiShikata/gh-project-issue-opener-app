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
    expect(find.byType(FloatingActionButton), findsNWidgets(2));
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.byIcon(Icons.filter_9_plus), findsOneWidget);
    expect(find.text('Open all'), findsOneWidget);
    expect(find.text('Open 10'), findsOneWidget);
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

    test('returns all urls in display order from object payload when limit is zero', () {
      final List<String> displayedUrls = <String>[
        'https://github.com/owner/repo/issues/top',
        'https://github.com/owner/repo/issues/middle',
        'https://github.com/owner/repo/issues/bottom',
      ];

      final String payload =
          json.encode(<String, dynamic>{'urls': displayedUrls, 'limit': 0});
      final List<String> result = parseOpenAllUrls(payload);

      expect(result, equals(displayedUrls));
    });

    test('applies limit to take only the first N urls from object payload', () {
      final List<String> displayedUrls = <String>[
        'https://github.com/owner/repo/issues/1',
        'https://github.com/owner/repo/issues/2',
        'https://github.com/owner/repo/issues/3',
        'https://github.com/owner/repo/issues/4',
        'https://github.com/owner/repo/issues/5',
      ];

      final String payload =
          json.encode(<String, dynamic>{'urls': displayedUrls, 'limit': 3});
      final List<String> result = parseOpenAllUrls(payload);

      expect(
        result,
        equals(<String>[
          displayedUrls[0],
          displayedUrls[1],
          displayedUrls[2],
        ]),
      );
    });

    test('keeps the topmost displayed url as the first element of the result', () {
      final List<String> displayedUrls = <String>[
        'https://github.com/owner/repo/issues/top',
        'https://github.com/owner/repo/issues/second',
        'https://github.com/owner/repo/issues/third',
      ];

      final String payload =
          json.encode(<String, dynamic>{'urls': displayedUrls, 'limit': 0});
      final List<String> result = parseOpenAllUrls(payload);

      expect(result.first, equals(displayedUrls.first));
      expect(result.last, equals(displayedUrls.last));
    });
  });

  group('selectUrlsForBulkOpen', () {
    final List<String> sample = <String>[
      'https://github.com/owner/repo/issues/1',
      'https://github.com/owner/repo/issues/2',
      'https://github.com/owner/repo/issues/3',
      'https://github.com/owner/repo/issues/4',
      'https://github.com/owner/repo/issues/5',
    ];

    test('returns every url in display order when limit is zero', () {
      final List<String> result = selectUrlsForBulkOpen(sample, limit: 0);

      expect(result, equals(sample));
    });

    test('returns first N urls in display order when limit is below length', () {
      final List<String> result = selectUrlsForBulkOpen(sample, limit: 3);

      expect(result, equals(<String>[sample[0], sample[1], sample[2]]));
    });

    test('returns every url when limit equals length', () {
      final List<String> result = selectUrlsForBulkOpen(sample, limit: 5);

      expect(result, equals(sample));
    });

    test('returns every url when limit exceeds length', () {
      final List<String> result = selectUrlsForBulkOpen(sample, limit: 10);

      expect(result, equals(sample));
    });

    test('returns empty list for empty input', () {
      final List<String> result = selectUrlsForBulkOpen(<String>[], limit: 0);

      expect(result, isEmpty);
    });

    test('returns empty list when input is empty and a positive limit is set', () {
      final List<String> result = selectUrlsForBulkOpen(<String>[], limit: 5);

      expect(result, isEmpty);
    });

    test('does not reverse the display order so the topmost url stays first', () {
      final List<String> result = selectUrlsForBulkOpen(sample, limit: 3);

      expect(result.first, equals(sample.first));
      expect(result, isNot(equals(sample.reversed.take(3).toList())));
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

    test(
      'sends exactly one url when a single issue link is clicked',
      () async {
        const String clickedUrl = 'https://github.com/owner/repo/issues/7';
        final List<String> urls = parseOpenAllUrls(
          json.encode(<String>[clickedUrl]),
        );

        await channel.invokeMethod('openAllUrls', urls);

        expect(urls, <String>[clickedUrl]);
        expect(calls.length, 1);
        expect(calls.single.method, 'openAllUrls');
        expect(
          (calls.single.arguments as List<dynamic>).cast<String>(),
          <String>[clickedUrl],
        );
      },
    );
  });
}
