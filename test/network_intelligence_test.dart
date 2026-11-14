import 'package:cobra_shield/services/network_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkIntelligence safety guards', () {
    test('does not resolve or connect to loopback destinations', () async {
      final report = await NetworkIntelligence.inspect('http://127.0.0.1/');
      expect(report.dnsComplete, isFalse);
      expect(report.error, isNotNull);
      expect(report.addresses, isEmpty);
    });

    test('rejects non-web schemes before network activity', () async {
      final report = await NetworkIntelligence.inspect('javascript:alert(1)');
      expect(report.dnsComplete, isFalse);
      expect(report.error, contains('غير صالح'));
    });
  });
}
