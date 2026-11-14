import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/models.dart';
import 'net_guard.dart';

/// Static-only page inspection. The response is never rendered and JavaScript is
/// never executed. Every request is DNS-pinned by NetGuard and bounded by time
/// and bytes; redirects are deliberately not followed here (LinkExpander owns
/// redirect tracing).
class PageBehaviorReport {
  const PageBehaviorReport({
    required this.url,
    required this.findings,
    this.browserStatus,
    this.automationStatus,
    this.contentType = '',
    this.bytesRead = 0,
    this.truncated = false,
    this.supported = false,
    this.complete = false,
    this.error,
    this.behaviorDiffers = false,
  });

  final String url;
  final List<Finding> findings;
  final int? browserStatus;
  final int? automationStatus;
  final String contentType;
  final int bytesRead;
  final bool truncated;
  final bool supported;
  final bool complete;
  final String? error;
  final bool behaviorDiffers;
}

class _PageResponse {
  const _PageResponse({
    required this.status,
    required this.body,
    required this.contentType,
    required this.truncated,
  });

  final int status;
  final String body;
  final String contentType;
  final bool truncated;
}

class PageBehaviorInspector {
  PageBehaviorInspector._();

  static const int _maxBytes = 512 * 1024;
  static const int _maxExternalScripts = 3;
  static const int _maxExternalScriptBytes = 128 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 7);
  static const Duration _totalTimeout = Duration(seconds: 20);
  static const String _browserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';
  static const String _automationAgent = 'LinkScanner/6.0 (+static-security-inspection)';

  static final RegExp _scriptTag = RegExp(
    r'<script\b([^>]*)>([\s\S]*?)</script\s*>',
    caseSensitive: false,
  );
  static final RegExp _formTag = RegExp(
    r'<form\b([^>]*)>([\s\S]*?)</form\s*>',
    caseSensitive: false,
  );
  static final RegExp _iframeTag = RegExp(r'<iframe\b([^>]*)>', caseSensitive: false);
  static final RegExp _metaTag = RegExp(r'<meta\b([^>]*)>', caseSensitive: false);
  static final RegExp _attr = RegExp(r'''([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''');
  static final RegExp _credentialField = RegExp(
    r"""<input\b[^>]*\btype\s*=\s*["']?password""",
    caseSensitive: false,
  );
  static final RegExp _challenge = RegExp(
    r'(captcha|verify\s+you\s+are\s+human|just\s+a\s+moment|cf-chl-|challenge-platform|bot\s+check|automated\s+access|access\s+denied|datadome|imperva|perimeterx)',
    caseSensitive: false,
  );

  static Future<PageBehaviorReport> inspect(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return PageBehaviorReport(
        url: rawUrl,
        findings: const <Finding>[],
        complete: false,
        error: 'عنوان الصفحة غير صالح للفحص السلوكي.',
      );
    }
    final blocked = NetGuard.blockReason(uri);
    if (blocked != null) {
      return PageBehaviorReport(
        url: rawUrl,
        findings: const <Finding>[],
        complete: false,
        error: 'لم يتم تحميل الصفحة: $blocked',
      );
    }

    final clock = Stopwatch()..start();
    Duration slice() {
      final left = _totalTimeout - clock.elapsed;
      if (left <= Duration.zero) return const Duration(milliseconds: 1);
      return left < _requestTimeout ? left : _requestTimeout;
    }

    final client = NetGuard.pinnedClient(
      connectTimeout: _requestTimeout,
      userAgent: _browserAgent,
      lookupTimeout: slice,
    );
    try {
      final browser = await _fetch(client, uri, _browserAgent, slice);
      if (!_isHtml(browser)) {
        return PageBehaviorReport(
          url: uri.toString(),
          findings: const <Finding>[
            Finding(
              code: 'page_not_html',
              severity: Severity.info,
              title: 'الوجهة ليست صفحة HTML قابلة للتحليل',
              detail: 'تم فحص استجابة HTTP، لكن نوع المحتوى لا يسمح بتحليل سلوك صفحة ويب. لم يتم تنفيذ أي محتوى.',
            ),
          ],
          browserStatus: browser.status,
          contentType: browser.contentType,
          bytesRead: utf8.encode(browser.body).length,
          truncated: browser.truncated,
          supported: false,
          complete: true,
        );
      }

      final externalScriptCode = await _fetchExternalScripts(
        client,
        uri,
        browser.body,
        slice,
      );
      final findings = _analyzeHtml(
        browser.body,
        uri,
        additionalJavaScript: externalScriptCode,
      );
      var automationStatus = browser.status;
      var differs = false;
      var challengeMismatch = false;
      String? differentialError;
      var secondTruncated = false;
      var secondBytes = 0;
      String secondType = browser.contentType;

      // A second, low-volume request checks whether the server behaves differently
      // for a scanner user-agent. Differences are evidence of variability only,
      // not proof of malicious cloaking (many CDNs and WAFs do this legitimately).
      if (clock.elapsed < _totalTimeout - const Duration(seconds: 2)) {
        try {
          final automated = await _fetch(client, uri, _automationAgent, slice);
          automationStatus = automated.status;
          secondTruncated = automated.truncated;
          secondBytes = utf8.encode(automated.body).length;
          secondType = automated.contentType;
          final browserChallenge = _challenge.hasMatch(browser.body);
          final automationChallenge = _challenge.hasMatch(automated.body);
          challengeMismatch = browserChallenge != automationChallenge ||
              (browser.status >= 200 && browser.status < 300 &&
                  (automated.status == 403 || automated.status == 429));
          final anyChallenge = browserChallenge || automationChallenge;
          final larger = mathRatio(browser.body.length, automated.body.length) >= 3.0 &&
              (browser.body.length - automated.body.length).abs() >= 1800;
          differs = browser.status != automated.status || larger ||
              browser.contentType != automated.contentType || challengeMismatch;
          if (challengeMismatch || anyChallenge) {
            findings.add(const Finding(
              code: 'anti_automation_challenge',
              severity: Severity.info,
              title: 'تم رصد تحدي أو آلية مكافحة فحص آلي',
              detail: 'ظهرت علامات تحدي أو منع وصول في إحدى الاستجابتين أو كلتيهما. قد تكون حماية CDN/WAF طبيعية أو إخفاءً للمحتوى؛ لا يمكن اعتبارها تصيّدًا بمفردها.',
              points: 4,
              family: kFamilyWeak,
            ));
          } else if (differs) {
            findings.add(const Finding(
              code: 'browser_behavior_variance',
              severity: Severity.info,
              title: 'استجابة الصفحة تختلف حسب بيئة الطلب',
              detail: 'اختلفت حالة HTTP أو نوع المحتوى أو حجم الاستجابة بين متصفح هاتف وعميل الفحص. هذا يستحق مراجعة، لكنه لا يثبت وجود Cloaking لأن التصميم المتجاوب وأنظمة الحماية قد تسبب اختلافًا طبيعيًا.',
              points: 2,
              family: kFamilyWeak,
            ));
          }
        } catch (_) {
          differentialError = 'تم تحليل محتوى الصفحة، لكن تعذرت مقارنة استجابة المتصفح بطلب أداة الفحص.';
        }
      } else {
        differentialError = 'تم تحليل محتوى الصفحة، لكن لم يتبق وقت كافٍ لاختبار اختلاف الاستجابة حسب User-Agent.';
      }
      if (differentialError != null) {
        findings.add(const Finding(
          code: 'user_agent_comparison_incomplete',
          severity: Severity.info,
          title: 'مقارنة سلوك User-Agent غير مكتملة',
          detail: 'تعذر استكمال اختبار اختلاف استجابة الخادم بين متصفح الهاتف وأداة الفحص. لم يتم اعتبار ذلك علامة خطر.',
        ));
      }

      if (browser.truncated || secondTruncated) {
        findings.add(const Finding(
          code: 'page_content_truncated',
          severity: Severity.info,
          title: 'تحليل محتوى الصفحة محدود بالحجم',
          detail: 'تجاوزت الاستجابة حد القراءة الآمن. تم تحليل الجزء الأول فقط، لذلك قد تكون بعض السكربتات أو النماذج غير مرئية.',
        ));
      }

      return PageBehaviorReport(
        url: uri.toString(),
        findings: List<Finding>.unmodifiable(findings),
        browserStatus: browser.status,
        automationStatus: automationStatus,
        contentType: browser.contentType.isNotEmpty ? browser.contentType : secondType,
        bytesRead: utf8.encode(browser.body).length + secondBytes,
        truncated: browser.truncated || secondTruncated,
        supported: true,
        complete: differentialError == null,
        error: differentialError,
        behaviorDiffers: differs,
      );
    } on BlockedTargetException catch (e) {
      return PageBehaviorReport(
        url: uri.toString(), findings: const <Finding>[], complete: false,
        error: 'منع NetGuard تحميل الصفحة: ${e.reason}',
      );
    } on TimeoutException {
      return PageBehaviorReport(
        url: uri.toString(), findings: const <Finding>[], complete: false,
        error: 'انتهت مهلة تحليل الصفحة. لا يعني ذلك أنها آمنة أو ضارة.',
      );
    } on SocketException catch (e) {
      return PageBehaviorReport(
        url: uri.toString(), findings: const <Finding>[], complete: false,
        error: 'تعذر تحميل الصفحة بسبب DNS أو الاتصال: ${e.message}',
      );
    } catch (_) {
      return PageBehaviorReport(
        url: uri.toString(), findings: const <Finding>[], complete: false,
        error: 'تعذر تحليل استجابة الصفحة بشكل آمن.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _fetchExternalScripts(
    HttpClient client,
    Uri pageUri,
    String html,
    Duration Function() timeout,
  ) async {
    final sources = <Uri>{};
    for (final match in _scriptTag.allMatches(html)) {
      final attrs = _attributes(match.group(1) ?? '');
      final src = attrs['src'];
      if (src == null || src.isEmpty) continue;
      final parsed = Uri.tryParse(src);
      if (parsed == null) continue;
      final resolved = pageUri.resolveUri(parsed);
      // Fetch external source text only over TLS, never follow script redirects,
      // and never evaluate the returned content.
      if (resolved.scheme != 'https' || resolved.host.isEmpty ||
          resolved.toString().length > NetGuard.maxUrlLength) continue;
      if (NetGuard.blockReason(resolved) != null) continue;
      sources.add(resolved);
      if (sources.length >= _maxExternalScripts) break;
    }

    final collected = <String>[];
    for (final source in sources) {
      if (timeout() <= const Duration(milliseconds: 100)) break;
      try {
        final request = await client.getUrl(source).timeout(timeout());
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, _automationAgent);
        request.headers.set(HttpHeaders.acceptHeader, 'application/javascript,text/javascript,*/*;q=0.2');
        final response = await request.close().timeout(timeout());
        if (response.statusCode != 200) {
          await response.drain<void>();
          continue;
        }
        final mime = response.headers.contentType?.mimeType.toLowerCase() ?? '';
        if (mime.contains('text/html') || mime.contains('application/xhtml')) {
          await response.drain<void>();
          continue;
        }
        final bytes = <int>[];
        await for (final chunk in response.timeout(timeout())) {
          final remaining = _maxExternalScriptBytes - bytes.length;
          if (chunk.length > remaining) {
            if (remaining > 0) bytes.addAll(chunk.take(remaining));
            break;
          }
          bytes.addAll(chunk);
          if (bytes.length >= _maxExternalScriptBytes) break;
        }
        collected.add(utf8.decode(bytes, allowMalformed: true));
      } catch (_) {
        // One failed third-party script must not stop inspection of the page.
      }
    }
    return collected.join('\n');
  }

  static Future<_PageResponse> _fetch(
    HttpClient client,
    Uri uri,
    String userAgent,
    Duration Function() timeout,
  ) async {
    final req = await client.getUrl(uri).timeout(timeout());
    req.followRedirects = false;
    req.headers.set(HttpHeaders.userAgentHeader, userAgent);
    req.headers.set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.5');
    req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    // No cookies, credentials, referer, body, or JavaScript execution.
    final res = await req.close().timeout(timeout());
    final chunks = <int>[];
    var truncated = false;
    await for (final chunk in res.timeout(timeout())) {
      final remaining = _maxBytes - chunks.length;
      if (chunk.length > remaining) {
        if (remaining > 0) chunks.addAll(chunk.take(remaining));
        truncated = true;
        break;
      }
      chunks.addAll(chunk);
      if (chunks.length >= _maxBytes) {
        truncated = true;
        break;
      }
    }
    return _PageResponse(
      status: res.statusCode,
      body: utf8.decode(chunks, allowMalformed: true),
      contentType: res.headers.contentType?.mimeType ?? '',
      truncated: truncated,
    );
  }

  static bool _isHtml(_PageResponse response) {
    final type = response.contentType.toLowerCase();
    if (type.contains('text/html') || type.contains('application/xhtml')) return true;
    final body = response.body.toLowerCase();
    return body.contains('<html') || body.contains('<!doctype html');
  }

  static List<Finding> _analyzeHtml(
    String html,
    Uri pageUri, {
    String additionalJavaScript = '',
  }) {
    final findings = <Finding>[];
    final scripts = _scriptTag.allMatches(html).toList(growable: false);
    final inlineCode = <String>[
      ...scripts.map((m) => m.group(2) ?? ''),
      additionalJavaScript,
    ].join('\n');
    final scriptSources = <String>{};
    final externalActions = <String>{};
    var suspiciousCredentialForms = 0;
    var hiddenExternalFrames = 0;
    var externalMetaRedirects = 0;

    for (final form in _formTag.allMatches(html)) {
      final attrs = _attributes(form.group(1) ?? '');
      final body = form.group(2) ?? '';
      if (!_credentialField.hasMatch(body)) continue;
      final actionText = attrs['action'] ?? '';
      if (actionText.isEmpty) continue;
      final action = Uri.tryParse(actionText);
      if (action == null) continue;
      final resolved = pageUri.resolveUri(action);
      if (resolved.host.isNotEmpty && resolved.host.toLowerCase() != pageUri.host.toLowerCase()) {
        suspiciousCredentialForms++;
        externalActions.add(resolved.host);
        findings.add(Finding(
          code: 'credential_form_external',
          severity: Severity.danger,
          title: 'نموذج كلمة مرور يرسل البيانات لمضيف آخر',
          detail: 'الصفحة تحتوي حقل كلمة مرور، لكن وجهة إرسال النموذج هي ${resolved.host} وليس ${pageUri.host}. افحص العلاقة بين الموقعين قبل إدخال أي بيانات.',
          points: 32,
        ));
      } else if (pageUri.scheme == 'https' && resolved.scheme == 'http') {
        findings.add(const Finding(
          code: 'credential_form_downgrade',
          severity: Severity.danger,
          title: 'نموذج بيانات اعتماد يرسل عبر HTTP',
          detail: 'الصفحة مشفرة لكن نموذج كلمة المرور يرسل البيانات إلى اتصال غير مشفر.',
          points: 30,
        ));
      }
    }

    for (final script in scripts) {
      final attrs = _attributes(script.group(1) ?? '');
      final src = attrs['src'];
      if (src != null && src.isNotEmpty) {
        final parsed = Uri.tryParse(src);
        if (parsed != null) {
          final resolved = pageUri.resolveUri(parsed);
          if (resolved.host.isNotEmpty && resolved.host != pageUri.host) {
            scriptSources.add(resolved.host.toLowerCase());
          }
        }
      }
    }

    for (final frame in _iframeTag.allMatches(html)) {
      final attrs = _attributes(frame.group(1) ?? '');
      final src = attrs['src'] ?? '';
      if (src.isEmpty) continue;
      final parsed = Uri.tryParse(src);
      if (parsed == null) continue;
      final resolved = pageUri.resolveUri(parsed);
      final style = (attrs['style'] ?? '').toLowerCase().replaceAll(' ', '');
      final isHidden = attrs['hidden'] != null ||
          attrs['aria-hidden'] == 'true' ||
          style.contains('display:none') ||
          style.contains('visibility:hidden') ||
          attrs['width'] == '0' || attrs['height'] == '0';
      if (isHidden && resolved.host.isNotEmpty && resolved.host != pageUri.host) {
        hiddenExternalFrames++;
      }
    }
    if (hiddenExternalFrames > 0) {
      findings.add(Finding(
        code: 'hidden_external_iframe',
        severity: Severity.warn,
        title: 'إطار خارجي مخفي داخل الصفحة',
        detail: 'تم العثور على $hiddenExternalFrames إطار مخفي يشير إلى مضيف خارجي. قد يكون تتبعًا شرعيًا أو محتوى مضمنًا، لكنه يحتاج مراجعة مع بقية المؤشرات.',
        points: 10,
      ));
    }

    for (final meta in _metaTag.allMatches(html)) {
      final attrs = _attributes(meta.group(1) ?? '');
      if ((attrs['http-equiv'] ?? '').toLowerCase() != 'refresh') continue;
      final content = attrs['content'] ?? '';
      final match = RegExp(r"""url\s*=\s*["']?([^"']+)""", caseSensitive: false).firstMatch(content);
      if (match == null) continue;
      final target = Uri.tryParse(match.group(1)!.trim());
      if (target == null) continue;
      final resolved = pageUri.resolveUri(target);
      if (resolved.host.isNotEmpty && resolved.host != pageUri.host) externalMetaRedirects++;
    }
    if (externalMetaRedirects > 0) {
      findings.add(const Finding(
        code: 'external_meta_redirect',
        severity: Severity.warn,
        title: 'تحويل تلقائي إلى مضيف آخر داخل HTML',
        detail: 'تحتوي الصفحة على meta refresh ينقل المتصفح إلى مضيف مختلف. تمت ملاحظة التحويل دون تنفيذه.',
        points: 12,
      ));
    }

    final hasEval = RegExp(r'\beval\s*\(', caseSensitive: false).hasMatch(inlineCode);
    final hasFunctionCtor = RegExp(r'new\s+Function\s*\(', caseSensitive: false).hasMatch(inlineCode);
    final hasDecoder = RegExp(r'\b(atob|unescape|decodeURIComponent)\s*\(', caseSensitive: false).hasMatch(inlineCode) ||
        RegExp(r'fromCharCode\s*\(', caseSensitive: false).hasMatch(inlineCode);
    final hasDocumentWrite = RegExp(r'\bdocument\s*\.\s*write\s*\(', caseSensitive: false).hasMatch(inlineCode);
    final hasDynamicNavigation = RegExp(
      r'(?:window\s*\.\s*location(?:\s*\.\s*href)?|location\s*\.(?:href|assign|replace)|window\s*\.\s*open)\s*(?:=|\()',
      caseSensitive: false,
    ).hasMatch(inlineCode);
    final longEncodedToken = RegExp(r'[A-Za-z0-9+/=_-]{240,}').hasMatch(inlineCode);
    final obfuscated = (hasEval || hasFunctionCtor) && (hasDecoder || longEncodedToken);
    if (obfuscated) {
      findings.add(const Finding(
        code: 'obfuscated_inline_javascript',
        severity: Severity.warn,
        title: 'JavaScript مموّه أو مفكوك وقت التشغيل',
        detail: 'السكربت يجمع بين تنفيذ ديناميكي أو منشئ Function وبين فك ترميز/سلاسل طويلة. لم يتم تنفيذ الكود؛ هذه إشارة تستحق تحليلًا يدويًا.',
        points: 18,
      ));
    }
    if (hasDocumentWrite && hasDecoder && scripts.isNotEmpty) {
      findings.add(const Finding(
        code: 'runtime_html_injection_pattern',
        severity: Severity.warn,
        title: 'نمط إنشاء HTML وقت التشغيل',
        detail: 'تم العثور على document.write مع فك ترميز نصوص داخل JavaScript. قد يُستخدم لتوليد محتوى ديناميكي أو لإخفاء صفحة تصيّد.',
        points: 10,
      ));
    }
    if (hasDynamicNavigation) {
      findings.add(const Finding(
        code: 'javascript_dynamic_navigation',
        severity: Severity.info,
        title: 'تنقّل ديناميكي عبر JavaScript',
        detail: 'الصفحة تحتوي أوامر تغير موقع المتصفح أو تفتح نافذة برمجيًا. هذا شائع في التطبيقات الشرعية أيضًا؛ نربطه بمسار التحويلات قبل الحكم.',
        points: 2,
        family: kFamilyWeak,
      ));
    }
    if (scriptSources.length >= 5) {
      findings.add(Finding(
        code: 'many_external_script_hosts',
        severity: Severity.info,
        title: 'مصادر JavaScript خارجية متعددة (${scriptSources.length})',
        detail: 'تم تحميل سكربتات من عدة مضيفين خارجيين: ${scriptSources.take(5).join(', ')}. العدد وحده ليس دليلًا على الضرر.',
        points: 3,
        family: kFamilyWeak,
      ));
    }
    if (suspiciousCredentialForms > 0 &&
        (obfuscated || hiddenExternalFrames > 0 || externalMetaRedirects > 0)) {
      findings.add(const Finding(
        code: 'credential_collection_behavior_combo',
        severity: Severity.danger,
        title: 'تجميع بيانات اعتماد مع سلوك إخفاء/تحويل',
        detail: 'اجتمع نموذج كلمة مرور يرسل لمضيف خارجي مع JavaScript مموّه أو إطار مخفي أو تحويل خارجي. هذا التجمع أقوى من أي إشارة منفردة.',
        points: 24,
      ));
    }
    final fingerprintPatterns = <RegExp>[
      RegExp(r'navigator\s*\.\s*webdriver', caseSensitive: false),
      RegExp(r'navigator\s*\.\s*plugins', caseSensitive: false),
      RegExp(r'canvas.{0,80}toDataURL|toDataURL.{0,80}canvas', caseSensitive: false),
      RegExp(r'webgl|getParameter\s*\(', caseSensitive: false),
      RegExp(r'hardwareConcurrency|deviceMemory|screen\s*\.\s*(width|height)', caseSensitive: false),
      RegExp(r'Intl\s*\.\s*DateTimeFormat', caseSensitive: false),
    ];
    final fingerprintSignals = fingerprintPatterns.where((p) => p.hasMatch(inlineCode)).length;
    if (fingerprintSignals >= 2) {
      findings.add(Finding(
        code: 'browser_fingerprinting',
        severity: Severity.info,
        title: 'استخدام عدة خصائص لبصمة المتصفح',
        detail: 'السكربت يقرأ $fingerprintSignals فئات من خصائص الجهاز/المتصفح. قد تستخدمها أنظمة مكافحة الاحتيال أو التحليلات، لكنها قد تفسر اختلاف المحتوى بين الزوار.',
        points: 3,
        family: kFamilyWeak,
      ));
    }
    if (inlineCode.length > 0 && scripts.length >= 12) {
      findings.add(Finding(
        code: 'script_heavy_page',
        severity: Severity.info,
        title: 'صفحة كثيفة السكربتات (${scripts.length})',
        detail: 'كثرة السكربتات وحدها لا تعني الخطر، لكن تم تضمينها في التقرير لتسهيل مراجعة السلوك.',
      ));
    }
    return findings;
  }

  /// Deterministic parser entry point for unit tests; never performs network I/O.
  static List<Finding> analyzeDocumentForTesting(
    String html,
    String pageUrl, {
    String additionalJavaScript = '',
  }) {
    final uri = Uri.parse(pageUrl);
    return _analyzeHtml(html, uri, additionalJavaScript: additionalJavaScript);
  }

  static Map<String, String> _attributes(String raw) {
    final result = <String, String>{};
    for (final match in _attr.allMatches(raw)) {
      result[match.group(1)!.toLowerCase()] =
          match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    }
    return result;
  }

  static double mathRatio(int a, int b) {
    if (a == 0 && b == 0) return 1;
    final high = a > b ? a : b;
    final low = a < b ? a : b;
    if (low == 0) return high.toDouble();
    return high / low;
  }
}
