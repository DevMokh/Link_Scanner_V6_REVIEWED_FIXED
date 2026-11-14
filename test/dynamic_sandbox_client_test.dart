import 'package:cobra_shield/services/dynamic_sandbox_client.dart';
import 'package:cobra_shield/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses bounded dynamic Chromium report and strong findings', () {
    final report = DynamicSandboxReport.fromJson('https://start.example/', {
      'schema_version': '1',
      'analysis_status': 'completed',
      'final_url': 'https://login.example/',
      'page_title': 'Sign in',
      'http_status': 200,
      'duration_ms': 1400,
      'request_count': 12,
      'blocked_request_count': 3,
      'redirect_chain': ['https://start.example/', 'https://login.example/'],
      'signals': {
        'password_fields': 1,
        'hidden_iframes': 1,
        'challenge_detected': false,
      },
      'findings': [
        {
          'code': 'dynamic_external_credential_form',
          'severity': 'danger',
          'title': 'External password form',
          'detail': 'The password form points to another host.',
          'points': 28,
        }
      ],
    });
    expect(report.complete, isTrue);
    expect(report.finalUrl, 'https://login.example/');
    expect(report.requestCount, 12);
    expect(report.navigationChain, hasLength(2));
    expect(report.findings.single.severity, Severity.danger);
    expect(report.findings.single.family, isEmpty);
  });

  test('rejects unsupported schema and incomplete payload', () {
    expect(
      () => DynamicSandboxReport.fromJson('https://example.org/', {
        'schema_version': '999',
        'analysis_status': 'partial',
      }),
      throwsFormatException,
    );
  });
}
