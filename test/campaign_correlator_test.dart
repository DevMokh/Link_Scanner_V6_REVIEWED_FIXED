import 'package:cobra_shield/core/models.dart';
import 'package:cobra_shield/services/campaign_correlator.dart';
import 'package:cobra_shield/services/history_store.dart';
import 'package:cobra_shield/services/url_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await HistoryStore.instance.clear();
  });

  test('correlates an exact host previously scored as high risk locally', () async {
    await HistoryStore.instance.add(HistoryItem(
      id: 1,
      kind: ScanKind.url,
      title: 'https://login.example.com/account',
      score: 72,
      time: DateTime.now(),
    ));
    final current = UrlAnalyzer.analyze('https://login.example.com/verify').parts!;
    final findings = CampaignCorrelator.analyze(current);
    expect(findings.any((f) => f.code == 'local_history_known_high_risk'), isTrue);
  });
}
