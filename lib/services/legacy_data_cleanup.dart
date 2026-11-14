import 'dart:io';

/// Removes obsolete local OpenPhish artifacts left by earlier app versions.
/// This migration is intentionally isolated from app startup and scan logic.
class LegacyDataCleanup {
  LegacyDataCleanup._();

  static const List<String> _openPhishFiles = <String>[
    'cobra_openphish.txt',
    'cobra_openphish.txt.tmp',
    'cobra_openphish.meta.json',
    'cobra_openphish.meta.json.tmp',
  ];

  static Future<void> removeOpenPhishCache({
    required Future<Directory> Function() supportDirectoryProvider,
    required Directory temporaryDirectory,
  }) async {
    final directories = <Directory>[temporaryDirectory];
    try {
      directories.add(await supportDirectoryProvider());
    } catch (_) {
      // The support directory may be unavailable in some test/runtime setups.
    }

    for (final directory in directories) {
      for (final name in _openPhishFiles) {
        try {
          final file = File('${directory.path}/$name');
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Cleaning obsolete cache files must never block app startup.
        }
      }
    }
  }
}
