import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../services/strings.dart';
import '../services/advanced_scanner.dart';
import '../services/dynamic_sandbox_client.dart';
import '../services/online_intel.dart';
import '../services/page_behavior_inspector.dart';
import '../services/network_intelligence.dart';
import 'intel_tiles.dart';
import 'common.dart';
import 'risk_gauge.dart';

/// بطاقة النتيجة: العدّاد + المستوى + النصيحة + زر نسخ التقرير
class ScanSummaryCard extends StatelessWidget {
  const ScanSummaryCard({super.key, required this.result, this.heading});

  final ScanResult result;
  final String? heading;

  @override
  Widget build(BuildContext context) {
    final verdict = result.verdict;
    final Color color;
    switch (verdict) {
      case Verdict.confirmedThreat:
        color = levelColor(RiskLevel.critical);
        break;
      case Verdict.insufficient:
      case Verdict.partialScan:
      case Verdict.invalidInput:
      case Verdict.analysisFailed:
        color = C.amber;
        break;
      case Verdict.suspicious:
      case Verdict.noIndicators:
        color = levelColor(result.displayLevel);
        break;
    }
    // الإدخال غير الصالح وفشل التحليل: مفيش درجة خطر أصلًا، فمش بنرسم عدّاد.
    final showGauge = result.hasScore;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      borderColor: alpha(color, 0.52),
      radius: 24,
      glowColor: color,
      child: Column(
        children: [
          if (heading != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                heading!,
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
            ),
          if (showGauge) ...[
            RiskGauge(score: result.effectiveScore, color: color),
            const SizedBox(height: 10),
          ] else ...[
            Icon(
              verdict == Verdict.invalidInput
                  ? Icons.link_off_rounded
                  : Icons.error_outline_rounded,
              color: color,
              size: 44,
            ),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: alpha(color, 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: alpha(color, 0.55)),
              boxShadow: glow(color, opacity: 0.25, blur: 14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الأيقونة الكبيرة فوق بتغطي حالات "مفيش درجة"، فمش بنكرّرها هنا.
                if (showGauge) ...[
                  Icon(_verdictIcon(verdict), color: color, size: 19),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    tr(verdictLabelKey(result)),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(verdictAdviceKey(result)),
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted, height: 1.5, fontSize: 13.5),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.toReport()));
              if (context.mounted) toast(context, 'تم نسخ التقرير');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(tr(S.copyReport)),
            style: TextButton.styleFrom(foregroundColor: C.accent),
          ),
        ],
      ),
    );
  }
}

/// أيقونة الحكم. "لا مؤشرات" مش علامة صح كاملة: ما لقيناش إشارات، مش ضمان أمان.
IconData _verdictIcon(Verdict v) {
  switch (v) {
    case Verdict.confirmedThreat:
      return Icons.gpp_bad_rounded;
    case Verdict.suspicious:
      return Icons.warning_amber_rounded;
    case Verdict.noIndicators:
      return Icons.shield_outlined;
    case Verdict.insufficient:
    case Verdict.partialScan:
      return Icons.rule_rounded;
    case Verdict.invalidInput:
      return Icons.link_off_rounded;
    case Verdict.analysisFailed:
      return Icons.error_outline_rounded;
  }
}

/// عنصر نتيجة واحد (سبب + شرح + نقاط)
class FindingTile extends StatelessWidget {
  const FindingTile({super.key, required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final c = severityColor(finding.severity);
    final pts = finding.points;
    final badge = pts > 0 ? '+$pts' : (pts < 0 ? '$pts' : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          color: alpha(C.surface2, 0.72),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: c),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(severityIcon(finding.severity), color: c, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                finding.title,
                                style: const TextStyle(
                                  color: C.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                finding.detail,
                                style: const TextStyle(
                                  color: C.muted,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (badge.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: alpha(c, 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FindingsList extends StatelessWidget {
  const FindingsList({super.key, required this.findings, this.title});

  final List<Finding> findings;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title ?? 'تفاصيل التحليل (${findings.length})'),
        ...findings.map((f) => FindingTile(finding: f)),
      ],
    );
  }
}

/// تفكيك الرابط إلى أجزاءه
class UrlBreakdown extends StatelessWidget {
  const UrlBreakdown({super.key, required this.parts});

  final UrlParts parts;

  Widget _row(String k, String v) {
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(k, style: const TextStyle(color: C.muted, fontSize: 12.5)),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                v,
                style: const TextStyle(
                  color: C.text,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تفكيك الرابط',
            style: TextStyle(color: C.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _row('البروتوكول', parts.scheme),
          // المضيف الكامل (Hostname) والدومين المسجّل (Registrable Domain) حقلين منفصلين.
          _row('المضيف الكامل', parts.host),
          if (parts.unicodeHost.isNotEmpty && parts.unicodeHost != parts.host)
            _row('المضيف (Unicode)', parts.unicodeHost),
          // الشكل اللي بيشوفه المتصفح فعلًا لو الاسم فيه حروف دولية (xn--).
          if (parts.asciiHost.isNotEmpty && parts.asciiHost != parts.host)
            _row('المضيف (Punycode)', parts.asciiHost),
          _row('الدومين المسجّل', parts.registrableDomain),
          _row('اللاحقة العامة', parts.publicSuffix),
          _row('المنفذ', parts.port),
          _row('المسار', parts.path),
          _row('الاستعلام', parts.query),
          // الرابط بعد فك التمويه (hxxp / %xx / hex): ده اللي هيتفتح فعلًا.
          if (parts.normalizedUrl.isNotEmpty)
            _row('الرابط الفعلي بعد التنظيف', parts.normalizedUrl),
        ],
      ),
    );
  }
}


/// تقرير استخبارات موسّع مبني حصرياً على مخرجات AdvancedScanner.
/// لا ينشئ نتائج افتراضية؛ غياب البيانات يظهر كحالة غير متاحة/غير مكتملة.
class AdvancedReportDossier extends StatelessWidget {
  const AdvancedReportDossier({super.key, required this.report, required this.localResult});

  final AdvancedReport report;
  final ScanResult localResult;

  @override
  Widget build(BuildContext context) {
    final page = report.pageBehavior;
    final network = report.network;
    final chain = report.expand.chain;
    final allFindings = report.toResult(localResult).findings;
    final pageFindings = <Finding>[
      ...?page?.findings,
    ];
    final networkFindings = <Finding>[...?network?.findings];
    final redirectFindings = <Finding>[
      ...report.redirectFindings,
      if (report.expand.blockedOnRedirect)
        const Finding(severity: Severity.danger, title: 'تحويل إلى وجهة محظورة', detail: 'أوقف NetGuard الاتصال قبل الوصول إلى الوجهة الداخلية أو غير العامة.'),
    ];
    final campaign = report.campaignFindings;
    final sections = <_ReportSection>[
      _ReportSection('مسار التحويلات', Icons.alt_route_rounded, chain.isEmpty ? 0 : chain.length,
          chain.isEmpty ? 'لم تتوفر بيانات مسار التحويل.' : '${chain.length - 1} تحويلة مرصودة',
          _redirectTimeline(chain, report.expand.statusCode), C.statusCyan),
      _ReportSection('سلوك الصفحة وJavaScript', Icons.code_rounded, pageFindings.length,
          page == null ? 'لم يتم تشغيل فحص الصفحة' : page.complete ? 'اكتمل التحليل الساكن' : 'تحليل جزئي',
          _pageDetails(page, pageFindings), C.accent),
      _ReportSection('Chromium المعزول — تحليل ديناميكي', Icons.web_asset_rounded, report.dynamicSandbox?.findings.length ?? 0,
          report.dynamicSandbox == null ? 'غير مضبوط في الإعدادات' : report.dynamicSandbox!.complete ? 'جلسة متصفح مؤقتة مكتملة' : 'التحليل غير مكتمل',
          _dynamicDetails(report.dynamicSandbox), C.statusCyan),
      _ReportSection('DNS وTLS وASN', Icons.lan_rounded, networkFindings.length,
          network == null ? 'غير متاح' : network.dnsComplete ? 'بيانات الشبكة جُمعت' : 'بيانات غير مكتملة',
          _networkDetails(network), C.statusCyan),
      _ReportSection('ارتباطات الحملة المحلية', Icons.hub_rounded, campaign.length,
          campaign.isEmpty ? 'لا توجد مطابقة في سجل الجهاز' : 'مطابقات محلية من سجل الفحص',
          _findingDetails(campaign), C.statusWarning),
      _ReportSection('مصادر السمعة', Icons.travel_explore_rounded, report.intel.length,
          '${report.intel.where((e) => e.status == IntelStatus.hit).length} تطابقات تهديد • ${report.intel.where((e) => e.status == IntelStatus.error || e.status == IntelStatus.notConfigured || e.status == IntelStatus.skipped).length} غير متاح/متخطى',
          Column(children: report.intel.map((r) => IntelTile(result: r)).toList()), C.statusSafe),
      _ReportSection('المؤشرات المجمّعة', Icons.manage_search_rounded, allFindings.length,
          '${allFindings.where((f) => f.severity == Severity.danger).length} حرجة/خطيرة • ${allFindings.where((f) => f.severity == Severity.warn).length} تحذيرات',
          _findingDetails(allFindings), C.statusWarning),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          borderColor: alpha(report.partial ? C.amber : C.green, .45),
          child: Row(children: [
            Icon(report.partial ? Icons.pending_actions_rounded : Icons.verified_user_rounded,
                color: report.partial ? C.amber : C.green),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(report.partial ? 'التقرير غير مكتمل' : 'اكتمل الفحص المتقدم',
                  style: const TextStyle(color: C.text, fontWeight: FontWeight.w800)),
              Text(report.partial
                  ? 'تعذر استكمال: ${report.failedSources.join('، ')}. لا تعتبر الأجزاء غير المفحوصة آمنة.'
                  : 'كل المصادر التي بدأ تشغيلها أعادت نتيجة. هذا لا يثبت خلو الرابط من كل تهديد.',
                  style: const TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
            ])),
          ]),
        ),
        const SizedBox(height: 10),
        for (final section in sections) _ExpandableReportSection(section: section),
      ],
    );
  }

  static Widget _redirectTimeline(List<String> chain, int? status) {
    if (chain.isEmpty) return _empty('لا توجد بيانات تحويلات.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < chain.length; i++) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 25, child: Column(children: [
          Icon(i == chain.length - 1 ? Icons.flag_rounded : Icons.circle,
              size: i == chain.length - 1 ? 18 : 10,
              color: i == chain.length - 1 ? C.green : C.statusCyan),
          if (i != chain.length - 1) Container(width: 2, height: 30, color: alpha(C.statusCyan, .5)),
        ])),
        const SizedBox(width: 8),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(chain[i], style: const TextStyle(color: C.text, fontFamily: 'monospace', fontSize: 11.5)),
        ))),
        if (i == chain.length - 1 && status != null)
          Text('HTTP $status', style: const TextStyle(color: C.muted, fontSize: 10)),
      ]),
    ]);
  }

  static Widget _pageDetails(PageBehaviorReport? page, List<Finding> findings) {
    if (page == null) return _empty('لم يتم تشغيل تحليل HTML/JavaScript.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _kv('الوجهة', page.url, mono: true),
      _kv('HTTP متصفح الهاتف', '${page.browserStatus ?? 'غير متاح'}'),
      _kv('HTTP أداة الفحص', '${page.automationStatus ?? 'غير متاح'}'),
      _kv('نوع المحتوى', page.contentType.isEmpty ? 'غير معروف' : page.contentType),
      _kv('حجم البيانات المقروءة', '${page.bytesRead} بايت${page.truncated ? ' (مقتطع)' : ''}'),
      _kv('اختلاف الاستجابة', page.behaviorDiffers ? 'مرصود — ليس دليلاً منفرداً على التمويه' : 'لم يُرصد'),
      if (page.error != null) _kv('حدود الفحص', page.error!),
      const SizedBox(height: 8),
      _findingDetails(findings),
      const Text('تم تحليل المحتوى كنص ثابت؛ لم يتم تنفيذ JavaScript أو إرسال نماذج.',
          style: TextStyle(color: C.muted, fontSize: 11, height: 1.4)),
    ]);
  }

  static Widget _dynamicDetails(DynamicSandboxReport? report) {
    if (report == null) {
      return _empty('لم يتم تشغيل تحليل Chromium في هذه الجلسة. اضبط خادم HTTPS ومفتاحه ووافق على إرسال الرابط من إعدادات الفحص المتقدم.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _kv('حالة الجلسة', report.complete ? 'اكتمل التحليل الديناميكي' : 'غير مكتمل'),
      _kv('عنوان الصفحة النهائي', report.finalUrl.isEmpty ? 'غير متاح' : report.finalUrl, mono: true),
      _kv('عنوان الصفحة', report.pageTitle.isEmpty ? 'غير متاح' : report.pageTitle),
      _kv('HTTP', '${report.httpStatus ?? 'غير متاح'}', mono: true),
      _kv('زمن التحليل', '${report.durationMs} ms', mono: true),
      _kv('الطلبات المرصودة', '${report.requestCount}', mono: true),
      _kv('الطلبات المحظورة', '${report.blockedRequestCount}', mono: true),
      _kv('حقول كلمة المرور', '${report.passwordFieldCount}', mono: true),
      _kv('إطارات خارجية مخفية', '${report.hiddenIframeCount}', mono: true),
      _kv('تحدي مكافحة الأتمتة', report.challengeDetected ? 'تم رصده — ليس دليلاً منفرداً على الضرر' : 'لم يتم رصده'),
      if (report.navigationChain.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('تنقلات Chromium', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 5),
        for (final url in report.navigationChain)
          Padding(padding: const EdgeInsets.only(bottom: 5), child: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(url, style: const TextStyle(color: C.statusCyan, fontFamily: 'monospace', fontSize: 10.5)),
          )),
      ],
      if (report.error != null) _kv('سبب عدم الاكتمال', report.error!),
      const SizedBox(height: 8),
      _findingDetails(report.findings),
      const Text('JavaScript نُفّذ داخل حاوية Chromium مؤقتة على الخادم. لم تُستورد جلسات أو Cookies، ولم تُرسل النماذج؛ طُبقت سياسة GET/HEAD فقط ومنع الوصول إلى العناوين الخاصة.',
          style: TextStyle(color: C.muted, fontSize: 10.8, height: 1.45)),
    ]);
  }

  static Widget _networkDetails(NetworkIntelligenceReport? n) {
    if (n == null) return _empty('لم تتوفر بيانات DNS/TLS/ASN.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _kv('Hostname', n.host, mono: true),
      _kv('DNS', n.addresses.isEmpty ? 'غير متاح' : n.addresses.join('\n'), mono: true),
      _kv('ASN', n.asn ?? 'غير متاح', mono: true),
      _kv('Prefix', n.prefix ?? 'غير متاح', mono: true),
      _kv('Network holder', n.networkHolder ?? 'غير متاح'),
      _kv('الدولة', n.country ?? 'غير متاحة'),
      _kv('TLS Subject', n.certificateSubject ?? 'غير متاح', mono: true),
      _kv('TLS Issuer', n.certificateIssuer ?? 'غير متاح', mono: true),
      _kv('بداية الشهادة', n.certificateStart?.toIso8601String() ?? 'غير متاحة', mono: true),
      _kv('انتهاء الشهادة', n.certificateEnd?.toIso8601String() ?? 'غير متاحة', mono: true),
      if (n.error != null) _kv('ملاحظة', n.error!),
    ]);
  }

  static Widget _findingDetails(List<Finding> findings) {
    if (findings.isEmpty) return _empty('لا توجد مؤشرات مسجلة في هذا القسم.');
    return Column(children: findings.map((f) => FindingTile(finding: f)).toList());
  }

  static Widget _kv(String label, String value, {bool mono = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 112, child: Text(label, style: const TextStyle(color: C.muted, fontSize: 11))),
      Expanded(child: Directionality(textDirection: mono ? TextDirection.ltr : TextDirection.rtl, child: SelectableText(value,
        textAlign: mono ? TextAlign.left : TextAlign.start,
        style: TextStyle(color: C.text, fontSize: 11.5, height: 1.35, fontFamily: mono ? 'monospace' : null)))),
    ]),
  );

  static Widget _empty(String text) => Text(text, style: const TextStyle(color: C.muted, fontSize: 12));
}

class _ReportSection {
  const _ReportSection(this.title, this.icon, this.count, this.subtitle, this.child, this.color);
  final String title;
  final IconData icon;
  final int count;
  final String subtitle;
  final Widget child;
  final Color color;
}

class _ExpandableReportSection extends StatelessWidget {
  const _ExpandableReportSection({required this.section});
  final _ReportSection section;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: alpha(C.surface2, .72), borderRadius: BorderRadius.circular(15),
      border: Border.all(color: alpha(section.color, .3))),
    child: Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      leading: Icon(section.icon, color: section.color),
      title: Text(section.title, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(section.subtitle, style: const TextStyle(color: C.muted, fontSize: 10.5)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: alpha(section.color, .13), borderRadius: BorderRadius.circular(20)),
        child: Text('${section.count}', style: TextStyle(color: section.color, fontWeight: FontWeight.w800))),
      children: [section.child],
    )),
  );
}
