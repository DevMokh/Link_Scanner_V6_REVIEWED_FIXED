import 'package:flutter_test/flutter_test.dart';

import 'package:cobra_shield/core/brands.dart';

void main() {
  test('official domain index keeps exact and subdomain matches', () {
    expect(officialBrandOf('paypal.com')?.name, 'PayPal');
    expect(officialBrandOf('accounts.google.com')?.name, 'Google');
    expect(officialBrandOf('www.noon.com')?.name, 'Noon');
  });

  test('official domain index rejects lookalike suffixes', () {
    expect(officialBrandOf('paypal.com.evil.example'), isNull);
    expect(officialBrandOf('notgoogle.com'), isNull);
  });
}
