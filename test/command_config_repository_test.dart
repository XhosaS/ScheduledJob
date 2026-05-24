import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scheduled_job/features/scheduled_jobs/data/command_config_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/command_config.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('command_config_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loads recommended commands from localized template assets', () async {
    final repository = FileCommandConfigRepository(
      workspacePath: tempDir.path,
      assetBundle: _FakeAssetBundle({
        'assets/commands/templates/en/index.json': '[{"slug":"python_hello"}]',
        'assets/commands/templates/en/python_hello/command.json':
            '{"type":"python","command":"print(\\"hello\\")","description":"Hello"}',
        'assets/commands/templates/en/python_hello/libs/requirements.txt': '',
      }),
    );

    final commands = await repository.fetchRecommendedCommands(
      const Locale('en'),
    );

    expect(commands.single.slug, 'python_hello');
    expect(commands.single.config.type, JobRunMode.python);
    expect(commands.single.config.command, 'print("hello")');
  });

  test('creates a pending command folder and commits it', () async {
    final repository = FileCommandConfigRepository(
      workspacePath: tempDir.path,
      assetBundle: _FakeAssetBundle({
        'assets/commands/templates/en/python_hello/libs/requirements.txt':
            'requests==2.32.0',
      }),
    );

    final draft = await repository.createJobCommandFolderDraft(
      jobId: 7,
      config: const CommandConfig(
        type: JobRunMode.python,
        command: 'print("hello")',
        description: 'Hello',
      ),
      templateSlug: 'python_hello',
      locale: const Locale('en'),
    );

    expect(await File(draft.folder.absoluteConfigPath).exists(), isTrue);
    expect(
      await File(
        p.join(draft.folder.absoluteFolderPath, 'libs', 'requirements.txt'),
      ).readAsString(),
      'requests==2.32.0',
    );

    final committed = await draft.commit();

    expect(committed.relativeConfigPath, p.join('jobs', '7', 'command.json'));
    expect(await Directory(p.join(tempDir.path, 'jobs', '7')).exists(), isTrue);
    expect(
      await Directory(p.join(tempDir.path, 'jobs', '7', 'venv')).exists(),
      isFalse,
    );
    expect(
      jsonDecode(await File(committed.absoluteConfigPath).readAsString()),
      {'type': 'python', 'command': 'print("hello")', 'description': 'Hello'},
    );
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}
