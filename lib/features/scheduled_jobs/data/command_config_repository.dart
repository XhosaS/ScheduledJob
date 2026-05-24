// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:scheduled_job/features/scheduled_jobs/domain/command_config.dart';

abstract class CommandConfigRepository {
  Future<List<RecommendedCommand>> fetchRecommendedCommands(Locale locale);

  Future<CommandFolderDraft> createJobCommandFolderDraft({
    required int jobId,
    required CommandConfig config,
    String? templateSlug,
    String? sourceConfigPath,
    Locale? locale,
  });

  String resolveConfigPath(String relativeConfigPath);

  Future<void> deleteJobCommandFolder(String relativeConfigPath);
}

class CommandFolder {
  const CommandFolder({
    required this.relativeConfigPath,
    required this.absoluteFolderPath,
    required this.absoluteConfigPath,
  });

  final String relativeConfigPath;
  final String absoluteFolderPath;
  final String absoluteConfigPath;
}

class CommandFolderDraft {
  CommandFolderDraft({
    required this.folder,
    required this.commit,
    required this.discard,
  });

  final CommandFolder folder;
  final Future<CommandFolder> Function() commit;
  final Future<void> Function() discard;
}

class FileCommandConfigRepository implements CommandConfigRepository {
  FileCommandConfigRepository({
    required String workspacePath,
    AssetBundle? assetBundle,
  }) : _workspacePath = workspacePath,
       _assetBundle = assetBundle ?? rootBundle;

  static const _templatesRoot = 'assets/commands/templates';
  static const _requirementsPath = 'libs/requirements.txt';

  final String _workspacePath;
  final AssetBundle _assetBundle;

  @override
  Future<List<RecommendedCommand>> fetchRecommendedCommands(
    Locale locale,
  ) async {
    final localeName = locale.languageCode == 'zh' ? 'zh' : 'en';
    final indexPath = '$_templatesRoot/$localeName/index.json';
    final rawIndex = await _assetBundle.loadString(indexPath);
    final index = jsonDecode(rawIndex);
    if (index is! List) {
      throw const FormatException('Invalid recommended command index');
    }

    final commands = <RecommendedCommand>[];
    for (final item in index) {
      if (item is! Map || item['slug'] is! String) {
        continue;
      }
      final slug = item['slug']! as String;
      final config = await _loadTemplateConfig(localeName, slug);
      commands.add(RecommendedCommand(slug: slug, config: config));
    }
    return commands;
  }

  @override
  Future<CommandFolderDraft> createJobCommandFolderDraft({
    required int jobId,
    required CommandConfig config,
    String? templateSlug,
    String? sourceConfigPath,
    Locale? locale,
  }) async {
    final pendingFolder = Directory(
      p.join(_workspacePath, 'jobs', '$jobId.pending'),
    );
    final finalFolder = Directory(p.join(_workspacePath, 'jobs', '$jobId'));
    final legacyVenv = Directory(p.join(finalFolder.path, 'venv'));
    if (await legacyVenv.exists()) {
      await legacyVenv.delete(recursive: true);
    }
    if (await pendingFolder.exists()) {
      await pendingFolder.delete(recursive: true);
    }
    await Directory(p.join(pendingFolder.path, 'libs')).create(recursive: true);

    if (templateSlug != null && locale != null) {
      await _copyTemplateRequirements(
        locale.languageCode == 'zh' ? 'zh' : 'en',
        templateSlug,
        pendingFolder.path,
      );
    } else if (sourceConfigPath != null && sourceConfigPath.isNotEmpty) {
      await _copyExistingRequirements(sourceConfigPath, pendingFolder.path);
    } else {
      await File(
        p.join(pendingFolder.path, _requirementsPath),
      ).writeAsString('', flush: true);
    }

    final configFile = File(p.join(pendingFolder.path, 'command.json'));
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
      flush: true,
    );

    final pending = CommandFolder(
      relativeConfigPath: p.join('jobs', '$jobId.pending', 'command.json'),
      absoluteFolderPath: pendingFolder.path,
      absoluteConfigPath: configFile.path,
    );

    return CommandFolderDraft(
      folder: pending,
      commit: () async {
        if (await finalFolder.exists()) {
          await finalFolder.delete(recursive: true);
        }
        await pendingFolder.rename(finalFolder.path);
        return CommandFolder(
          relativeConfigPath: p.join('jobs', '$jobId', 'command.json'),
          absoluteFolderPath: finalFolder.path,
          absoluteConfigPath: p.join(finalFolder.path, 'command.json'),
        );
      },
      discard: () async {
        if (await pendingFolder.exists()) {
          await pendingFolder.delete(recursive: true);
        }
      },
    );
  }

  @override
  String resolveConfigPath(String relativeConfigPath) {
    return p.join(_workspacePath, relativeConfigPath);
  }

  @override
  Future<void> deleteJobCommandFolder(String relativeConfigPath) async {
    if (relativeConfigPath.isEmpty) {
      return;
    }
    final folder = Directory(p.dirname(resolveConfigPath(relativeConfigPath)));
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  Future<CommandConfig> _loadTemplateConfig(
    String localeName,
    String slug,
  ) async {
    final rawConfig = await _assetBundle.loadString(
      '$_templatesRoot/$localeName/$slug/command.json',
    );
    final json = jsonDecode(rawConfig);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Invalid command config');
    }
    return CommandConfig.fromJson(json);
  }

  Future<void> _copyTemplateRequirements(
    String localeName,
    String slug,
    String targetFolder,
  ) async {
    final requirements = await _loadTemplateRequirements(localeName, slug);
    await File(
      p.join(targetFolder, _requirementsPath),
    ).writeAsString(requirements, flush: true);
  }

  Future<void> _copyExistingRequirements(
    String sourceConfigPath,
    String targetFolder,
  ) async {
    final sourceRequirements = File(
      p.join(p.dirname(resolveConfigPath(sourceConfigPath)), _requirementsPath),
    );
    if (!await sourceRequirements.exists()) {
      await File(
        p.join(targetFolder, _requirementsPath),
      ).writeAsString('', flush: true);
      return;
    }
    await sourceRequirements.copy(p.join(targetFolder, _requirementsPath));
  }

  Future<String> _loadTemplateRequirements(
    String localeName,
    String slug,
  ) async {
    try {
      return await _assetBundle.loadString(
        '$_templatesRoot/$localeName/$slug/$_requirementsPath',
      );
    } on FlutterError {
      return '';
    }
  }
}
