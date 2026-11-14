import '../core/models.dart';
import 'history_store.dart';
import 'url_analyzer.dart';

/// Correlates a candidate URL with previously scanned URLs stored locally on
/// this device. No history is uploaded and no message body is retained here.
class CampaignCorrelator {
  CampaignCorrelator._();

  static List<Finding> analyze(UrlParts current) {
    final host = current.host.toLowerCase();
    final exactHighRisk = <HistoryItemRef>[];
    final siblingHighRisk = <HistoryItemRef>[];
    final currentDomain = current.registrableDomain.isNotEmpty
        ? current.registrableDomain.toLowerCase()
        : current.domain.toLowerCase();

    for (final item in HistoryStore.instance.items) {
      if (item.kind != ScanKind.url || item.score < kBandHigh) continue;
      // Keep the correlation window bounded; old history remains visible but is
      // not treated as current campaign evidence.
      if (DateTime.now().difference(item.time).inDays > 45) continue;
      var candidateText = item.title.trim();
      if (candidateText.isEmpty) continue;
      if (!candidateText.contains('://')) candidateText = 'https://$candidateText';
      final uri = Uri.tryParse(candidateText);
      final previousHost = uri?.host.toLowerCase() ?? '';
      if (previousHost.isEmpty) continue;
      if (previousHost == host) {
        exactHighRisk.add(HistoryItemRef(item.title, item.score, previousHost));
        continue;
      }
      final previousDomain = UrlAnalyzer.registrableDomain(previousHost).toLowerCase();
      if (currentDomain.isNotEmpty && previousDomain == currentDomain) {
        siblingHighRisk.add(HistoryItemRef(item.title, item.score, previousHost));
      }
    }

    final findings = <Finding>[];
    if (exactHighRisk.isNotEmpty) {
      final highest = exactHighRisk.map((e) => e.score).reduce((a, b) => a > b ? a : b);
      findings.add(Finding(
        code: 'local_history_known_high_risk',
        severity: Severity.warn,
        title: 'هذا العنوان ظهر سابقًا بنتيجة خطورة مرتفعة على جهازك',
        detail: 'السجل المحلي يحتوي ${exactHighRisk.length} فحصًا سابقًا لهذا المضيف بدرجات وصلت إلى $highest/100 خلال آخر 45 يومًا. هذه قرينة من سجل جهازك وليست تأكيدًا من جهة خارجية.',
        points: 14,
      ));
    }
    final distinctSiblings = siblingHighRisk.map((e) => e.host).toSet();
    if (distinctSiblings.length >= 2) {
      findings.add(Finding(
        code: 'local_campaign_sibling_hosts',
        severity: Severity.info,
        title: 'نطاقات فرعية مرتبطة ظهرت في سجل عالي الخطورة',
        detail: 'تم العثور على ${distinctSiblings.length} مضيفات أخرى تحت نفس الدومين المسجل في فحوصات سابقة عالية الخطورة. قد تكون مواقع منفصلة أو حملة واحدة؛ راجعها مع بقية الأدلة.',
        points: 5,
        family: kFamilyWeak,
      ));
    }
    return List<Finding>.unmodifiable(findings);
  }
}

class HistoryItemRef {
  const HistoryItemRef(this.title, this.score, this.host);
  final String title;
  final int score;
  final String host;
}
