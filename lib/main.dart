import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/theme.dart';
import 'services/history_store.dart';
import 'services/legacy_data_cleanup.dart';
import 'services/progress_store.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // تحميل الإعدادات والسجل فقط؛ لا توجد قاعدة تهديدات محلية في هذا الإصدار.
  await Future.wait<void>(<Future<void>>[
    HistoryStore.instance.load(),
    SettingsStore.instance.load(),
    ProgressStore.instance.load(),
  ]);
  runApp(const LinkScannerApp());
  // إزالة ملفات القاعدة القديمة بعد ظهور الواجهة، دون تعطيل بدء التشغيل.
  unawaited(LegacyDataCleanup.removeOpenPhishCache(
    supportDirectoryProvider: getApplicationSupportDirectory,
    temporaryDirectory: Directory.systemTemp,
  ));
}