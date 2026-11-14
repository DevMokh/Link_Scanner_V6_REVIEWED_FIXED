import 'package:flutter_test/flutter_test.dart';

import 'package:cobra_shield/services/batch_scanner.dart';
import 'package:cobra_shield/services/url_analyzer.dart';

void main() {
  test('background batch scan preserves order and local analyzer results', () async {
    const urls = <String>[
      'https://www.google.com/',
      'https://paypa1.com/signin',
      'javascript:alert(1)',
      'https://example.com/path',
    ];

    final actual = await scanUrlsInBackground(urls);
    expect(actual, hasLength(urls.length));

    for (var i = 0; i < urls.length; i++) {
      final expected = UrlAnalyzer.analyze(urls[i]);
      expect(actual[i].score, expected.score, reason: urls[i]);
      expect(actual[i].state, expected.state, reason: urls[i]);
      expect(
        actual[i].findings.map((finding) => finding.code).toList(),
        expected.findings.map((finding) => finding.code).toList(),
        reason: urls[i],
      );
    }
  });
}
