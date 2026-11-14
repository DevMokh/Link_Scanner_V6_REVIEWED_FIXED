import 'dart:io';

import 'package:cobra_shield/services/legacy_data_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('link-scanner-cleanup-');
    support = Directory('${root.path}/support');
    temporary = Directory('${root.path}/temporary');
    await support.create();
    await temporary.create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('removes only legacy feed files from both old storage locations', () async {
    const names = <String>[
      'cobra_openphish.txt',
      'cobra_openphish.txt.tmp',
      'cobra_openphish.meta.json',
      'cobra_openphish.meta.json.tmp',
    ];
    for (final directory in <Directory>[support, temporary]) {
      for (final name in names) {
        await File('${directory.path}/$name').writeAsString('legacy');
      }
      await File('${directory.path}/keep-this-file.txt').writeAsString('keep');
    }

    await LegacyDataCleanup.removeOpenPhishCache(
      supportDirectoryProvider: () async => support,
      temporaryDirectory: temporary,
    );

    for (final directory in <Directory>[support, temporary]) {
      for (final name in names) {
        expect(await File('${directory.path}/$name').exists(), isFalse);
      }
      expect(
        await File('${directory.path}/keep-this-file.txt').readAsString(),
        'keep',
      );
    }
  });

  test('continues when support storage cannot be resolved', () async {
    final stale = File('${temporary.path}/cobra_openphish.txt');
    await stale.writeAsString('legacy');

    await LegacyDataCleanup.removeOpenPhishCache(
      supportDirectoryProvider: () async => throw FileSystemException('unavailable'),
      temporaryDirectory: temporary,
    );

    expect(await stale.exists(), isFalse);
  });
}
