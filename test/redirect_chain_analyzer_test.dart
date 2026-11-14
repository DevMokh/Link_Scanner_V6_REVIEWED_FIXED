import 'package:cobra_shield/services/redirect_chain_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects HTTPS downgrade and multi-domain redirect path', () {
    final findings = RedirectChainAnalyzer.analyze(const <String>[
      'https://short.example.com/a',
      'https://relay.example.net/b',
      'http://landing.example.org/login',
    ]);
    expect(findings.any((f) => f.code == 'redirect_https_downgrade'), isTrue);
    expect(findings.any((f) => f.code == 'multi_domain_redirect_chain'), isTrue);
  });

  test('does not add findings for a single-host path', () {
    final findings = RedirectChainAnalyzer.analyze(const <String>[
      'https://www.example.com/a',
      'https://www.example.com/b',
    ]);
    expect(findings, isEmpty);
  });
}
