import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/models.dart';
import 'http_util.dart';
import 'net_guard.dart';

/// DNS, TLS and network registration context for a public destination.
/// This service never connects to an address unless every DNS answer has passed
/// NetGuard's private/reserved-address checks. TLS uses the validated IP socket
/// while retaining the hostname for SNI and certificate verification.
class NetworkIntelligenceReport {
  const NetworkIntelligenceReport({
    required this.host,
    required this.addresses,
    required this.findings,
    this.asn,
    this.prefix,
    this.networkHolder,
    this.country,
    this.certificateSubject,
    this.certificateIssuer,
    this.certificateStart,
    this.certificateEnd,
    this.tlsChecked = false,
    this.dnsComplete = false,
    this.registrationMessage,
    this.error,
  });

  final String host;
  final List<String> addresses;
  final List<Finding> findings;
  final String? asn;
  final String? prefix;
  final String? networkHolder;
  final String? country;
  final String? certificateSubject;
  final String? certificateIssuer;
  final DateTime? certificateStart;
  final DateTime? certificateEnd;
  final bool tlsChecked;
  final bool dnsComplete;
  final String? registrationMessage;
  final String? error;
}

class NetworkIntelligence {
  NetworkIntelligence._();

  static const Duration _timeout = Duration(seconds: 6);
  static const Duration _totalBudget = Duration(seconds: 18);

  static Future<NetworkIntelligenceReport> inspect(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return NetworkIntelligenceReport(
        host: '', addresses: const <String>[], findings: const <Finding>[],
        error: 'عنوان الوجهة غير صالح.',
      );
    }
    final blocked = NetGuard.blockReason(uri);
    if (blocked != null) {
      return NetworkIntelligenceReport(
        host: uri.host, addresses: const <String>[], findings: const <Finding>[],
        error: 'منع NetGuard فحص الشبكة: $blocked',
      );
    }

    final findings = <Finding>[];
    final clock = Stopwatch()..start();
    Duration slice() {
      final left = _totalBudget - clock.elapsed;
      if (left <= Duration.zero) return const Duration(milliseconds: 1);
      return left < _timeout ? left : _timeout;
    }
    List<InternetAddress> resolved;
    try {
      resolved = await InternetAddress.lookup(uri.host).timeout(slice());
      // Reject the whole set if any A/AAAA answer is private or reserved.
      NetGuard.pickSafeAddress(resolved);
    } on BlockedTargetException catch (e) {
      return NetworkIntelligenceReport(
        host: uri.host, addresses: const <String>[], findings: const <Finding>[],
        error: 'منع NetGuard عنوان DNS: ${e.reason}',
      );
    } catch (_) {
      return NetworkIntelligenceReport(
        host: uri.host, addresses: const <String>[], findings: const <Finding>[],
        error: 'تعذر حل اسم الموقع عبر DNS. لا يعني ذلك أنه آمن أو ضار.',
      );
    }

    final safeAddress = NetGuard.pickSafeAddress(resolved);
    final addresses = resolved.map((a) => a.address).toSet().toList(growable: false);
    final network = await _lookupRipe(safeAddress.address, slice);
    String? certSubject;
    String? certIssuer;
    DateTime? certStart;
    DateTime? certEnd;
    var tlsChecked = false;

    if (uri.scheme == 'https' && slice() > const Duration(milliseconds: 100)) {
      tlsChecked = true;
      Socket? raw;
      SecureSocket? secure;
      try {
        // Connect to the exact address validated above; preserve hostname as SNI.
        raw = await Socket.connect(safeAddress, uri.port, timeout: slice());
        secure = await SecureSocket.secure(
          raw,
          host: uri.host,
          supportedProtocols: const <String>['http/1.1'],
        ).timeout(slice());
        final certificate = secure.peerCertificate;
        if (certificate != null) {
          certSubject = certificate.subject;
          certIssuer = certificate.issuer;
          certStart = certificate.startValidity;
          certEnd = certificate.endValidity;
          final now = DateTime.now().toUtc();
          if (certEnd.isBefore(now) || certStart.isAfter(now)) {
            findings.add(Finding(
              code: 'tls_certificate_validity',
              severity: Severity.warn,
              title: 'شهادة TLS خارج فترة الصلاحية',
              detail: 'فترة الشهادة من ${certStart.toIso8601String()} إلى ${certEnd.toIso8601String()}. تحقق من إعداد الموقع قبل إدخال بيانات.',
            ));
          } else {
            findings.add(const Finding(
              code: 'tls_certificate_present',
              severity: Severity.info,
              title: 'تم التحقق من مصافحة TLS',
              detail: 'اكتملت مصافحة TLS وتحقق النظام من الشهادة. وجود شهادة صالحة لا يثبت أن محتوى الموقع آمن.',
            ));
          }
        }
      } on TlsException catch (e) {
        findings.add(Finding(
          code: 'tls_handshake_failed',
          severity: Severity.warn,
          title: 'تعذر التحقق من شهادة TLS',
          detail: 'فشلت مصافحة TLS أو مطابقة الشهادة: ${e.message}. هذا يحتاج حذرًا لكنه ليس دليل تصيّد بمفرده.',
        ));
      } on SocketException catch (e) {
        findings.add(Finding(
          code: 'tls_connection_unavailable',
          severity: Severity.info,
          title: 'تعذر إكمال فحص TLS',
          detail: 'تعذر فتح اتصال TLS: ${e.message}. قد يكون المنفذ مغلقًا أو الموقع غير متاح.',
        ));
      } on TimeoutException {
        findings.add(const Finding(
          code: 'tls_probe_timeout',
          severity: Severity.info,
          title: 'انتهت مهلة فحص TLS',
          detail: 'لم تكتمل مصافحة TLS ضمن المهلة. لا يمكن استنتاج الأمان أو الضرر من ذلك.',
        ));
      } catch (_) {
        findings.add(const Finding(
          code: 'tls_probe_unknown',
          severity: Severity.info,
          title: 'تعذر قراءة تفاصيل TLS',
          detail: 'اكتمل حل DNS لكن تعذر جمع تفاصيل الشهادة في هذه المحاولة.',
        ));
      } finally {
        try { secure?.destroy(); } catch (_) {}
        try { raw?.destroy(); } catch (_) {}
      }
    }

    if (network.asn != null || network.prefix != null || network.holder != null) {
      findings.add(Finding(
        code: 'network_registration_context',
        severity: Severity.info,
        title: 'تم جمع بيانات شبكة الوجهة',
        detail: <String>[
          if (network.asn != null) 'ASN ${network.asn}',
          if (network.prefix != null) 'Prefix ${network.prefix}',
          if (network.holder != null) network.holder!,
          if (network.country != null) 'الدولة ${network.country}',
        ].join(' • '),
      ));
    }

    return NetworkIntelligenceReport(
      host: uri.host,
      addresses: List<String>.unmodifiable(addresses),
      findings: List<Finding>.unmodifiable(findings),
      asn: network.asn,
      prefix: network.prefix,
      networkHolder: network.holder,
      country: network.country,
      certificateSubject: certSubject,
      certificateIssuer: certIssuer,
      certificateStart: certStart,
      certificateEnd: certEnd,
      tlsChecked: tlsChecked,
      dnsComplete: true,
      registrationMessage: network.message,
      error: network.error,
    );
  }

  static Future<_RipeNetwork> _lookupRipe(
    String ip,
    Duration Function() timeout,
  ) async {
    try {
      final response = await httpRequest(
        'GET',
        Uri.https('stat.ripe.net', '/data/network-info/data.json', <String, String>{'resource': ip}),
        headers: const <String, String>{'accept': 'application/json'},
        timeout: timeout(),
        totalTimeout: timeout(),
        maxBytes: 256 * 1024,
      );
      if (response.status != 200 || response.truncated) {
        return const _RipeNetwork(message: 'بيانات ASN غير متاحة حاليًا.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! Map) {
        return const _RipeNetwork(message: 'رد RIPEstat غير متوقع.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final asns = data['asns'];
      final asn = asns is List && asns.isNotEmpty ? '${asns.first}' : null;
      final prefix = data['prefix']?.toString();
      if (asn == null || asn.isEmpty) {
        return _RipeNetwork(prefix: prefix, message: 'لم يتم العثور على ASN معلن للعنوان.');
      }

      String? holder;
      String? country;
      try {
        final overview = await httpRequest(
          'GET',
          Uri.https('stat.ripe.net', '/data/as-overview/data.json', <String, String>{'resource': 'AS$asn'}),
          headers: const <String, String>{'accept': 'application/json'},
          timeout: timeout(),
          totalTimeout: timeout(),
          maxBytes: 256 * 1024,
        );
        if (overview.status == 200 && !overview.truncated) {
          final json = jsonDecode(overview.body);
          if (json is Map && json['data'] is Map) {
            final d = Map<String, dynamic>.from(json['data'] as Map);
            holder = (d['holder'] ?? d['name'])?.toString();
            country = d['country']?.toString();
          }
        }
      } catch (_) {
        // ASN/prefix remain useful if holder metadata is unavailable.
      }
      return _RipeNetwork(
        asn: asn, prefix: prefix, holder: holder, country: country,
        message: 'بيانات الشبكة من RIPEstat؛ لا تمثل تقييمًا لسمعة الموقع.',
      );
    } catch (_) {
      return const _RipeNetwork(message: 'تعذر الاستعلام عن ASN/الشبكة.');
    }
  }
}

class _RipeNetwork {
  const _RipeNetwork({this.asn, this.prefix, this.holder, this.country, this.message, this.error});
  final String? asn;
  final String? prefix;
  final String? holder;
  final String? country;
  final String? message;
  final String? error;
}
