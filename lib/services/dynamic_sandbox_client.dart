import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/models.dart';

/// Result returned by the user's own isolated Chromium sandbox service.
/// The client never opens the target URL on the Android device.
class DynamicSandboxReport {
  const DynamicSandboxReport({
    required this.requestedUrl,
    required this.complete,
    this.finalUrl = '',
    this.pageTitle = '',
    this.httpStatus,
    this.durationMs = 0,
    this.requestCount = 0,
    this.blockedRequestCount = 0,
    this.passwordFieldCount = 0,
    this.hiddenIframeCount = 0,
    this.challengeDetected = false,
    this.findings = const <Finding>[],
    this.navigationChain = const <String>[],
    this.error,
    this.sandboxVersion = '',
  });

  final String requestedUrl;
  final bool complete;
  final String finalUrl;
  final String pageTitle;
  final int? httpStatus;
  final int durationMs;
  final int requestCount;
  final int blockedRequestCount;
  final int passwordFieldCount;
  final int hiddenIframeCount;
  final bool challengeDetected;
  final List<Finding> findings;
  final List<String> navigationChain;
  final String? error;
  final String sandboxVersion;

  factory DynamicSandboxReport.failure(String url, String message) =>
      DynamicSandboxReport(requestedUrl: url, complete: false, error: message);

  factory DynamicSandboxReport.fromJson(String url, Map<String, dynamic> json) {
    final analysisStatus = json['analysis_status'];
    if (json['schema_version'] != '1' ||
        (analysisStatus != 'completed' && analysisStatus != 'partial')) {
      throw const FormatException('Unsupported or incomplete sandbox response.');
    }
    final rawFindings = json['findings'];
    final findings = <Finding>[];
    if (rawFindings is List) {
      for (final item in rawFindings.take(40)) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final title = _bounded(map['title'], 180);
        final detail = _bounded(map['detail'], 900);
        if (title.isEmpty) continue;
        findings.add(Finding(
          code: _bounded(map['code'], 80),
          severity: _severity(map['severity']),
          title: title,
          detail: detail,
          points: _intInRange(map['points'], 0, 35),
        ));
      }
    }
    final rawChain = json['redirect_chain'];
    final chain = rawChain is List
        ? rawChain.whereType<String>().take(12).map((v) => _bounded(v, 2048)).toList(growable: false)
        : const <String>[];
    final signals = json['signals'] is Map
        ? Map<String, dynamic>.from(json['signals'] as Map)
        : <String, dynamic>{};
    return DynamicSandboxReport(
      requestedUrl: url,
      complete: analysisStatus == 'completed',
      finalUrl: _bounded(json['final_url'], 2048),
      pageTitle: _bounded(json['page_title'], 180),
      httpStatus: _nullableInt(json['http_status'], 100, 599),
      durationMs: _intInRange(json['duration_ms'], 0, 120000),
      requestCount: _intInRange(json['request_count'], 0, 200),
      blockedRequestCount: _intInRange(json['blocked_request_count'], 0, 200),
      passwordFieldCount: _intInRange(signals['password_fields'], 0, 100),
      hiddenIframeCount: _intInRange(signals['hidden_iframes'], 0, 100),
      challengeDetected: signals['challenge_detected'] == true,
      findings: List<Finding>.unmodifiable(findings),
      navigationChain: chain,
      error: json['error'] is String ? _bounded(json['error'], 400) : null,
      sandboxVersion: _bounded(json['sandbox_version'], 40),
    );
  }

  static Severity _severity(Object? value) {
    switch (value) {
      case 'danger':
        return Severity.danger;
      case 'warn':
        return Severity.warn;
      case 'good':
        return Severity.good;
      default:
        return Severity.info;
    }
  }

  static int _intInRange(Object? value, int min, int max) {
    final n = value is num ? value.toInt() : int.tryParse('$value') ?? min;
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  static int? _nullableInt(Object? value, int min, int max) =>
      value == null ? null : _intInRange(value, min, max);

  static String _bounded(Object? value, int max) {
    if (value is! String) return '';
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '')
        .trim();
    return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
  }
}

class DynamicSandboxClient {
  DynamicSandboxClient._();

  static const int _maxResponseBytes = 256 * 1024;
  static const Duration _timeout = Duration(seconds: 28);

  /// URL is sent only to the explicitly configured HTTPS endpoint. The target
  /// itself is loaded by the remote isolated browser, never by this device.
  static Future<DynamicSandboxReport> inspect({
    required String targetUrl,
    required String endpoint,
    required String token,
  }) async {
    HttpClient? client;
    try {
      final endpointUri = Uri.parse(endpoint.trim());
      if (endpointUri.scheme != 'https' ||
          endpointUri.host.isEmpty ||
          endpointUri.userInfo.isNotEmpty ||
          endpointUri.hasQuery ||
          endpointUri.hasFragment) {
        return DynamicSandboxReport.failure(
          targetUrl,
          'عنوان خدمة Chromium يجب أن يكون HTTPS صالحًا وبدون بيانات دخول أو معاملات إضافية.',
        );
      }
      if (token.trim().length < 32) {
        return DynamicSandboxReport.failure(targetUrl, 'مفتاح خدمة Chromium غير مضبوط أو قصير.');
      }

      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 5)
        ..maxConnectionsPerHost = 2
        ..userAgent = 'LinkScanner/6 DynamicSandboxClient'
        ..findProxy = (Uri _) => 'DIRECT';

      final request = await client.postUrl(endpointUri).timeout(_timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token.trim()}');
      request.write(jsonEncode(<String, Object>{'url': targetUrl}));

      final response = await request.close().timeout(_timeout);
      final bytes = <int>[];
      await for (final chunk in response.timeout(_timeout)) {
        if (bytes.length + chunk.length > _maxResponseBytes) {
          throw const FormatException('Sandbox response exceeded the 256 KB limit.');
        }
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes, allowMalformed: true);
      if (response.statusCode != HttpStatus.ok) {
        return DynamicSandboxReport.failure(
          targetUrl,
          'خدمة Chromium أعادت HTTP ${response.statusCode}: ${body.length <= 240 ? body : body.substring(0, 240)}',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const FormatException('Invalid sandbox response.');
      return DynamicSandboxReport.fromJson(targetUrl, Map<String, dynamic>.from(decoded));
    } on TimeoutException {
      return DynamicSandboxReport.failure(targetUrl, 'انتهت مهلة الاتصال بخدمة Chromium المعزولة.');
    } on SocketException {
      return DynamicSandboxReport.failure(targetUrl, 'تعذر الاتصال بخدمة Chromium المعزولة.');
    } on FormatException catch (e) {
      return DynamicSandboxReport.failure(targetUrl, 'استجابة خدمة Chromium غير صالحة: ${e.message}');
    } catch (_) {
      return DynamicSandboxReport.failure(targetUrl, 'تعذر تنفيذ التحليل الديناميكي في الخدمة المعزولة.');
    } finally {
      client?.close(force: true);
    }
  }
}
