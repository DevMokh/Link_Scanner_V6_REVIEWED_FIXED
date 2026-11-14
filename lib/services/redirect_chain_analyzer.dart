import '../core/models.dart';
import 'url_analyzer.dart';

/// Contextual analysis of the redirect path already collected by LinkExpander.
/// This class never performs network requests.
class RedirectChainAnalyzer {
  RedirectChainAnalyzer._();

  static List<Finding> analyze(List<String> chain) {
    if (chain.length < 2) return const <Finding>[];
    final uris = <Uri>[];
    for (final raw in chain) {
      final uri = Uri.tryParse(raw);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
        uris.add(uri);
      }
    }
    if (uris.length < 2) return const <Finding>[];

    final domains = <String>{};
    final hosts = <String>{};
    var originChanges = 0;
    var httpsDowngrades = 0;
    for (var i = 0; i < uris.length; i++) {
      final uri = uris[i];
      hosts.add(uri.host.toLowerCase());
      final domain = UrlAnalyzer.registrableDomain(uri.host);
      if (domain.isNotEmpty) domains.add(domain.toLowerCase());
      if (i == 0) continue;
      final previous = uris[i - 1];
      if (previous.host.toLowerCase() != uri.host.toLowerCase() ||
          previous.port != uri.port || previous.scheme != uri.scheme) {
        originChanges++;
      }
      if (previous.scheme == 'https' && uri.scheme == 'http') {
        httpsDowngrades++;
      }
    }

    final findings = <Finding>[];
    if (httpsDowngrades > 0) {
      findings.add(Finding(
        code: 'redirect_https_downgrade',
        severity: Severity.warn,
        title: 'التحويلات خفّضت الاتصال من HTTPS إلى HTTP',
        detail: 'حدث خفض للتشفير في $httpsDowngrades مرحلة من سلسلة التحويل. قد تكشف المرحلة غير المشفرة بيانات المسار أو تتيح التلاعب بالاستجابة؛ لا تدخل بيانات حساسة بعد هذا التحويل.',
        points: 10,
        family: kFamilyWeak,
      ));
    }
    if (domains.length >= 3 && originChanges >= 2) {
      findings.add(Finding(
        code: 'multi_domain_redirect_chain',
        severity: Severity.warn,
        title: 'سلسلة التحويل تمر عبر عدة نطاقات مسجلة',
        detail: 'السلسلة عبرت ${domains.length} نطاقات مسجلة وغيّرت المضيف/الأصل $originChanges مرة. قد تكون بنية تتبع شرعية أو سلسلة إخفاء؛ افحص كل محطة والوجهة النهائية.',
        points: 7,
        family: kFamilyWeak,
      ));
    }
    if (hosts.length >= 5) {
      findings.add(Finding(
        code: 'many_redirect_hosts',
        severity: Severity.info,
        title: 'عدد كبير من المضيفين في مسار التحويل',
        detail: 'تم رصد ${hosts.length} مضيفين مختلفين في السلسلة. هذا يزيد صعوبة التحقق من الناقلات والوجهة النهائية، لكنه لا يثبت الضرر وحده.',
        points: 4,
        family: kFamilyWeak,
      ));
    }
    return List<Finding>.unmodifiable(findings);
  }
}
