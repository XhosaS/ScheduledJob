// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_job/features/scheduled_jobs/data/command_config_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/command_config.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

abstract class CommandEnvironmentService {
  Future<void> prepare(CommandFolder folder, CommandConfig config);
}

class LocalCommandEnvironmentService implements CommandEnvironmentService {
  const LocalCommandEnvironmentService({PythonRuntimeService? pythonRuntime});

  @override
  Future<void> prepare(CommandFolder folder, CommandConfig config) async {
    switch (config.type) {
      case JobRunMode.powershell:
        return;
      case JobRunMode.python:
        return;
    }
  }
}

class PythonRuntimeService {
  const PythonRuntimeService({
    String? pythonExecutablePath,
    String? commandWorkspacePath,
  }) : _pythonExecutablePath = pythonExecutablePath,
       _commandWorkspacePath = commandWorkspacePath;

  final String? _pythonExecutablePath;
  final String? _commandWorkspacePath;

  String get pythonExecutablePath {
    final configured = _pythonExecutablePath;
    if (configured != null) {
      return configured;
    }
    final bundled = p.join(
      File(Platform.resolvedExecutable).parent.path,
      'runtime',
      'python',
      'python.exe',
    );
    if (File(bundled).existsSync()) {
      return bundled;
    }
    final workspacePython = p.join(
      Directory.current.path,
      'third_party',
      'python',
      'windows-x64',
      'python.exe',
    );
    if (File(workspacePython).existsSync()) {
      return workspacePython;
    }
    return bundled;
  }

  String get sharedVenvPath {
    final workspacePath = _commandWorkspacePath;
    if (workspacePath != null) {
      return p.join(workspacePath, 'python_venv');
    }
    return p.join(
      File(Platform.resolvedExecutable).parent.path,
      'commands',
      'python_venv',
    );
  }

  String get sharedVenvPythonPath {
    return p.join(sharedVenvPath, 'Scripts', 'python.exe');
  }

  Future<void> prepare(String commandFolderPath) async {
    final python = File(pythonExecutablePath);
    if (!await python.exists()) {
      throw StateError('Bundled Python was not found: ${python.path}');
    }

    final venvPath = sharedVenvPath;
    await Directory(venvPath).parent.create(recursive: true);
    await _run(python.path, [
      '-m',
      'venv',
      venvPath,
    ], workingDirectory: commandFolderPath);

    final venvPython = sharedVenvPythonPath;
    await _run(venvPython, [
      '-m',
      'pip',
      '--version',
    ], workingDirectory: commandFolderPath);

    final requirements = File(
      p.join(commandFolderPath, 'libs', 'requirements.txt'),
    );
    if (!await requirements.exists()) {
      return;
    }

    final requirementsText = await requirements.readAsString();
    if (requirementsText.trim().isEmpty) {
      return;
    }

    await _run(venvPython, [
      '-m',
      'pip',
      'install',
      '-r',
      requirements.path,
    ], workingDirectory: commandFolderPath);
  }

  Future<String?> requirementsPathForCommandFolder(
    String commandFolderPath,
  ) async {
    final requirements = File(
      p.join(commandFolderPath, 'libs', 'requirements.txt'),
    );
    if (!await requirements.exists()) {
      return null;
    }
    if ((await requirements.readAsString()).trim().isEmpty) {
      return null;
    }
    return requirements.path;
  }

  Future<void> _run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        '${result.stderr}\n${result.stdout}'.trim(),
        result.exitCode,
      );
    }
  }
}
