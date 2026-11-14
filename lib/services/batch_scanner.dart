import 'package:flutter/foundation.dart' show compute;

import '../core/models.dart';
import 'url_analyzer.dart';

/// ينفّذ تحليل مجموعة روابط في isolate منفصل حتى لا تتوقف الرسوم والتفاعلات
/// أثناء فحص القوائم الكبيرة. لا يوجد اتصال بالإنترنت في هذا المسار.
List<ScanResult> _scanUrlsWorker(List<String> urls) =>
    urls.map(UrlAnalyzer.analyze).toList(growable: false);

/// نسخة خلفية من التحليل المجمّع. النتيجة بنفس ترتيب المدخلات.
Future<List<ScanResult>> scanUrlsInBackground(List<String> urls) {
  if (urls.isEmpty) return Future<List<ScanResult>>.value(const <ScanResult>[]);
  return compute<List<String>, List<ScanResult>>(
    _scanUrlsWorker,
    List<String>.of(urls, growable: false),
    debugLabel: 'link-scanner-batch-analysis',
  );
}
