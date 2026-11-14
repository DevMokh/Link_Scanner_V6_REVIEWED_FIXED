import '../core/knowledge.dart';
import '../core/models.dart';
import 'link_expander.dart';
import 'page_behavior_inspector.dart';
import 'network_intelligence.dart';
import 'campaign_correlator.dart';
import 'history_store.dart';
import 'redirect_chain_analyzer.dart';
import 'online_intel.dart';
import 'settings_store.dart';
import 'url_analyzer.dart';
import 'dynamic_sandbox_client.dart';

class AdvancedReport {
  const AdvancedReport({
    required this.expand,
    required this.finalLocal,
    required this.intel,
    required this.combinedScore,
    this.pageBehavior,
    this.network,
    this.campaignFindings = const <Finding>[],
    this.redirectFindings = const <Finding>[],
    this.dynamicSandbox,
  });

  final ExpandResult expand;
  final ScanResult? finalLocal; // تحليل الوجهة النهائية لو اختلفت عن الأصل
  final List<IntelResult> intel;
  final int combinedScore;
  final PageBehaviorReport? pageBehavior;
  final NetworkIntelligenceReport? network;
  final List<Finding> campaignFindings;
  final List<Finding> redirectFindings;
  final DynamicSandboxReport? dynamicSandbox;

  /// مصادر فشلت (مش اللي اتخطت لعدم وجود مفتاح): يعني الفحص ناقص.
  /// تتبع التحويلات بيتحسب هنا لو ما اتممش (خطأ شبكة، أو الحارس منع الاتصال).
  List<String> get failedSources => <String>[
        if (expand.error != null) 'تتبع التحويلات',
        if (pageBehavior != null && !pageBehavior!.complete) 'تحليل سلوك الصفحة',
        if (network != null && !network!.dnsComplete) 'تحليل DNS والشبكة',
        if (dynamicSandbox != null && !dynamicSandbox!.complete) 'تحليل Chromium المعزول',
        for (final r in intel)
          if (r.status == IntelStatus.error) r.source,
      ];

  /// الفحص المتقدم ما اكتملش: النتيجة مبنية على اللي اشتغل بس.
  bool get partial => failedSources.isNotEmpty;

  /// نتيجة موحدة: درجة مجمّعة + كل المؤشرات بدون تكرار
  ScanResult toResult(ScanResult local) {
    final seen = <String>{};
    final all = <Finding>[];
    void add(Iterable<Finding> list) {
      for (final f in list) {
        if (seen.add(f.title)) all.add(f);
      }
    }

    if (expand.blockedOnRedirect) {
      add(<Finding>[
        Finding(
          code: 'redirect_to_internal',
          severity: Severity.danger,
          title: 'الرابط بيحوّل لوجهة داخلية أو غير آمنة',
          detail: '${expand.error ?? ''}\nرابط خارجي بيوجّه لعنوان محلي/داخلي أسلوب هجوم معروف.',
          points: AdvancedScanner.blockedRedirectPoints,
        ),
      ]);
    }
    if (expand.hostUnreachable) {
      // الموقع غير متاح (DNS/مهلة/اتصال): حالة مستقلة، مش دليل تصيّد ومالهاش نقاط.
      add(<Finding>[
        Finding(
          code: 'host_unreachable',
          severity: Severity.info,
          title: 'تعذّر الوصول للموقع',
          detail:
              '${expand.error ?? ''}\nعدم الوصول للموقع ليس دليلًا على التصيّد (قد يكون الموقع متوقفًا أو الإنترنت ضعيفًا)، وليس دليلًا على الأمان أيضًا: الوجهة النهائية للرابط غير معروفة.',
        ),
      ]);
    } else if (expand.failure == ExpandFailure.tls) {
      add(<Finding>[
        Finding(
          code: 'tls_invalid',
          severity: Severity.info,
          title: 'شهادة الأمان (SSL) غير صالحة',
          detail:
              '${expand.error ?? ''}\nمواقع حقيقية كتير عندها شهادة منتهية أو غلط إعداد، فمش بنعتبره تصيّد لوحده، لكن لا تدخل أي بيانات في موقع شهادته غير صالحة.',
        ),
      ]);
    } else if (AdvancedScanner.isRedirectAnomaly(expand)) {
      add(<Finding>[
        Finding(
          code: 'redirect_anomaly',
          severity: Severity.warn,
          title: 'تحويلات غير طبيعية',
          detail: '${expand.error ?? ''}',
          points: AdvancedScanner.redirectAnomalyPoints,
          family: kFamilyWeak,
        ),
      ]);
    }
    add(pageBehavior?.findings ?? const <Finding>[]);
    add(network?.findings ?? const <Finding>[]);
    add(campaignFindings);
    add(redirectFindings);
    add(dynamicSandbox?.findings ?? const <Finding>[]);
    if (dynamicSandbox != null && !dynamicSandbox!.complete) {
      add(<Finding>[
        Finding(
          code: 'dynamic_sandbox_incomplete',
          severity: Severity.info,
          title: 'التحليل الديناميكي غير مكتمل',
          detail: dynamicSandbox!.error ?? 'لم تكتمل جلسة Chromium المعزولة. غياب التحليل الديناميكي لا يعني أن الرابط آمن.',
        ),
      ]);
    }
    if (pageBehavior?.error != null) {
      add(<Finding>[
        Finding(
          code: 'page_behavior_incomplete',
          severity: Severity.info,
          title: 'تحليل سلوك الصفحة غير مكتمل',
          detail: pageBehavior!.error!,
        ),
      ]);
    }
    if (network?.error != null) {
      add(<Finding>[
        Finding(
          code: 'network_intelligence_incomplete',
          severity: Severity.info,
          title: 'معلومات الشبكة غير مكتملة',
          detail: network!.error!,
        ),
      ]);
    }
    if (partial) {
      add(<Finding>[
        Finding(
          severity: Severity.warn,
          title: 'الفحص المتقدم غير مكتمل',
          detail:
              'تعذر: ${failedSources.join('، ')}. النتيجة مبنية على المصادر اللي اشتغلت بس، وفشل مصدر لا يعني إن الرابط آمن.',
        ),
      ]);
    }
    for (final r in intel) {
      add(r.findings);
    }
    final baseFindings = finalLocal != null && finalLocal!.score > local.score
        ? finalLocal!.findings
        : local.findings;
    add(baseFindings);
    all.sort((a, b) => b.points.compareTo(a.points));
    return ScanResult(
      kind: ScanKind.url,
      score: aggregateScore(all),
      findings: all,
      parts: finalLocal?.parts ?? local.parts,
      title: local.title,
      partial: partial,
    );
  }
}

/// الفحص المتقدم: تتبع التحويلات ثم الاستعلام من مصادر الفحص الخارجية عن الوجهة النهائية.
class AdvancedScanner {
  AdvancedScanner._();

  static final RegExp _ipLike = RegExp(r'^[\d.]+$');

  /// نقاط الخطر لو رابط خارجي حوّل لوجهة داخلية/غير آمنة.
  static const int blockedRedirectPoints = 30;

  /// حلقة تحويلات / تحويلات أكتر من الحد / عنوان تحويلة غير صالح: إشارة ضعيفة.
  static const int redirectAnomalyPoints = 6;

  static bool isRedirectAnomaly(ExpandResult r) =>
      r.failure == ExpandFailure.loop ||
      r.failure == ExpandFailure.tooManyHops ||
      r.failure == ExpandFailure.badRedirect;

  static Future<AdvancedReport> run(
    ScanResult local, {
    void Function(String step)? onStep,
  }) async {
    final parts = local.parts;
    if (parts == null) {
      throw StateError('no parts');
    }

    onStep?.call('تتبع التحويلات مع حماية DNS وNetGuard...');
    final expand = await LinkExpander.expand(parts.normalizedUrl);

    ScanResult? fin;
    var targetUrl = parts.normalizedUrl;
    var target = parts;
    if (expand.error == null && expand.redirected) {
      final analyzed = UrlAnalyzer.analyze(expand.finalUrl);
      if (analyzed.hasScore && analyzed.parts != null) {
        fin = analyzed;
        targetUrl = expand.finalUrl;
        target = analyzed.parts!;
      }
    }

    onStep?.call('تحليل HTML وJavaScript دون تنفيذ الكود...');
    final pageFuture = PageBehaviorInspector.inspect(targetUrl);

    onStep?.call('فحص DNS وTLS وبيانات ASN...');
    final networkFuture = NetworkIntelligence.inspect(targetUrl);

    onStep?.call('ربط المؤشرات مع سجل الفحوصات المحلي...');
    await HistoryStore.instance.load();
    final campaignFindings = CampaignCorrelator.analyze(target);
    final redirectFindings = RedirectChainAnalyzer.analyze(expand.chain);

    onStep?.call('الاستعلام من مصادر السمعة المتاحة...');
    final s = SettingsStore.instance;
    Future<DynamicSandboxReport?> dynamicFuture = Future<DynamicSandboxReport?>.value(null);
    if (s.dynamicSandboxConfigured && s.dynamicSandboxConsent) {
      onStep?.call('تشغيل الصفحة داخل Chromium معزول (بدون جلسات أو إرسال نماذج)...');
      dynamicFuture = DynamicSandboxClient.inspect(
        targetUrl: targetUrl,
        endpoint: s.dynamicSandboxEndpoint,
        token: s.dynamicSandboxToken,
      );
    }
    final host = target.host;
    final isIp = _ipLike.hasMatch(host) || host.contains(':');
    final skipAge = isIp || kShorteners.contains(host);
    final reputationFutures = <Future<IntelResult>>[
      if (!skipAge)
        OnlineIntel.rdap(target.domain)
      else
        Future<IntelResult>.value(const IntelResult(
          source: 'عمر الدومين (RDAP)',
          status: IntelStatus.skipped,
          message: 'لا ينطبق على عنوان IP أو رابط مختصر.',
        )),
      OnlineIntel.safeBrowsing(targetUrl, s.gsbKey),
      OnlineIntel.virusTotal(targetUrl, s.vtKey),
    ];

    final page = await pageFuture;
    final network = await networkFuture;
    final dynamicSandbox = await dynamicFuture;
    final intel = await Future.wait<IntelResult>(reputationFutures);

    final extra = <Finding>[
      if (expand.blockedOnRedirect)
        const Finding(
          code: 'redirect_to_internal',
          severity: Severity.danger,
          title: 'redirect_to_internal',
          detail: '',
          points: blockedRedirectPoints,
        ),
      if (isRedirectAnomaly(expand))
        const Finding(
          code: 'redirect_anomaly',
          severity: Severity.warn,
          title: 'redirect_anomaly',
          detail: '',
          points: redirectAnomalyPoints,
          family: kFamilyWeak,
        ),
      ...page.findings,
      ...network.findings,
      ...campaignFindings,
      ...redirectFindings,
      ...?dynamicSandbox?.findings,
      for (final r in intel) ...r.findings,
    ];
    final baseFindings = fin != null && fin.score > local.score
        ? fin.findings
        : local.findings;
    final combined = aggregateScore(<Finding>[...baseFindings, ...extra]);

    return AdvancedReport(
      expand: expand,
      finalLocal: fin,
      intel: intel,
      combinedScore: combined,
      pageBehavior: page,
      network: network,
      campaignFindings: campaignFindings,
      redirectFindings: redirectFindings,
      dynamicSandbox: dynamicSandbox,
    );
  }
}
