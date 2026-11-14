import 'package:flutter_test/flutter_test.dart';
import 'package:github_webview_app/main.dart';

void main() {
  group('isAllowedWebViewUrl', () {
    test('accepts https github.com issue, pull request and project URLs', () {
      expect(isAllowedWebViewUrl('https://github.com/owner/repo/issues/1'), isTrue);
      expect(isAllowedWebViewUrl('https://github.com/owner/repo/pull/2'), isTrue);
      expect(
        isAllowedWebViewUrl('https://github.com/users/HiromiShikata/projects/48/views/16'),
        isTrue,
      );
    });

    test('accepts explicit default https port and mixed-case host', () {
      expect(isAllowedWebViewUrl('https://GitHub.com:443/owner/repo'), isTrue);
    });

    test('rejects plain http even for github.com', () {
      expect(isAllowedWebViewUrl('http://github.com/owner/repo/issues/1'), isFalse);
    });

    test('rejects other hosts, including look-alike suffixes and subdomains', () {
      expect(isAllowedWebViewUrl('https://evil.example/'), isFalse);
      expect(isAllowedWebViewUrl('https://github.com.evil.example/'), isFalse);
      expect(isAllowedWebViewUrl('https://evil-github.com/'), isFalse);
      expect(isAllowedWebViewUrl('https://api.github.com/'), isFalse);
      expect(isAllowedWebViewUrl('https://gist.github.com/owner/abc'), isFalse);
    });

    test('rejects userinfo that makes the real host a different one', () {
      expect(isAllowedWebViewUrl('https://github.com@evil.example/'), isFalse);
    });

    test('rejects non-default ports', () {
      expect(isAllowedWebViewUrl('https://github.com:8443/owner/repo'), isFalse);
    });

    test('rejects non-web schemes', () {
      expect(isAllowedWebViewUrl('javascript:alert(1)'), isFalse);
      expect(isAllowedWebViewUrl('file:///etc/passwd'), isFalse);
      expect(isAllowedWebViewUrl('intent://github.com/#Intent;scheme=https;end'), isFalse);
      expect(isAllowedWebViewUrl('data:text/html,<p>x</p>'), isFalse);
    });

    test('rejects null, empty and unparseable input', () {
      expect(isAllowedWebViewUrl(null), isFalse);
      expect(isAllowedWebViewUrl(''), isFalse);
      expect(isAllowedWebViewUrl('not a url'), isFalse);
    });
  });

  group('shouldHandleNativeAppMessage', () {
    test('handles messages only while the current page is on github.com', () {
      expect(
        shouldHandleNativeAppMessage('https://github.com/owner/repo/issues/1'),
        isTrue,
      );
    });

    test('ignores messages from a non-GitHub page or when no page is known', () {
      expect(shouldHandleNativeAppMessage('https://evil.example/page'), isFalse);
      expect(shouldHandleNativeAppMessage(null), isFalse);
    });
  });
}
