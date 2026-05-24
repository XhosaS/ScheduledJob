// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_job/features/scheduled_jobs/application/command_environment_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/command_config_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

enum TerminalEventSource { scheduledJob, userCommand, system }

class TerminalEvent {
  const TerminalEvent({
    required this.timestamp,
    required this.text,
    required this.isError,
    required this.source,
    this.jobId,
  });

  final DateTime timestamp;
  final String text;
  final bool isError;
  final TerminalEventSource source;
  final int? jobId;
}

abstract class BackgroundCommandTerminalService {
  Stream<TerminalEvent> get events;

  Future<void> start();

  Future<void> enqueueScheduledJob(ScheduledJob job);

  Future<void> enqueueUserCommand(String command);

  void dispose();
}

class PowerShellBackgroundCommandTerminalService
    implements BackgroundCommandTerminalService {
  PowerShellBackgroundCommandTerminalService({
    required CommandConfigRepository commandConfigRepository,
    required PythonRuntimeService pythonRuntime,
  }) : _commandConfigRepository = commandConfigRepository,
       _pythonRuntime = pythonRuntime;

  final CommandConfigRepository _commandConfigRepository;
  final PythonRuntimeService _pythonRuntime;
  final StreamController<TerminalEvent> _events =
      StreamController<TerminalEvent>.broadcast();
  final List<_QueuedTerminalCommand> _queue = [];

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<void>? _activeCompleter;
  _QueuedTerminalCommand? _activeCommand;
  bool _isDisposed = false;
  int _sequence = 0;

  @override
  Stream<TerminalEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    if (_process != null) {
      return;
    }

    _process = await Process.start('powershell.exe', const [
      '-NoLogo',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
    ]);
    _stdoutSubscription = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _handleOutputLine(line, isError: false));
    _stderrSubscription = _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _handleOutputLine(line, isError: true));
    _process!.exitCode.then((exitCode) {
      if (_isDisposed) {
        return;
      }
      _emit(
        'Terminal process exited with code $exitCode',
        isError: exitCode != 0,
        source: TerminalEventSource.system,
      );
      _process = null;
    });
    unawaited(_enqueueSharedPythonEnvironmentInitialization());
  }

  @override
  Future<void> enqueueScheduledJob(ScheduledJob job) async {
    final command = await _commandForJob(job);
    return _enqueue(
      command,
      source: TerminalEventSource.scheduledJob,
      jobId: job.id,
      label: job.description,
    );
  }

  @override
  Future<void> enqueueUserCommand(String command) {
    return _enqueue(
      command,
      source: TerminalEventSource.userCommand,
      label: command,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _process?.stdin.writeln('exit');
    _process?.kill();
    _events.close();
  }

  Future<void> _enqueue(
    String command, {
    required TerminalEventSource source,
    required String label,
    int? jobId,
  }) async {
    await start();
    final completer = Completer<void>();
    _queue.add(
      _QueuedTerminalCommand(
        id: ++_sequence,
        command: command,
        label: label,
        source: source,
        jobId: jobId,
        completer: completer,
      ),
    );
    _pumpQueue();
    return completer.future;
  }

  void _pumpQueue() {
    if (_activeCommand != null || _queue.isEmpty || _process == null) {
      return;
    }

    final command = _queue.removeAt(0);
    _activeCommand = command;
    _activeCompleter = command.completer;
    if (command.source != TerminalEventSource.system) {
      _emit('> ${command.label}', source: command.source, jobId: command.jobId);
    }
    _process!.stdin.writeln(_wrapCommand(command));
  }

  String _wrapCommand(_QueuedTerminalCommand command) {
    final marker = _markerFor(command.id);
    final encodedCommand = base64Encode(utf8.encode(command.command));
    final markerLiteral = _quotePowerShell(marker);
    return [
      '\$global:LASTEXITCODE = 0',
      '\$scheduledJobCommand = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('
          '${_quotePowerShell(encodedCommand)}))',
      'try { Invoke-Expression \$scheduledJobCommand } catch { Write-Error \$_; \$global:LASTEXITCODE = 1 }',
      '\$scheduledJobExitCode = if (\$null -eq \$global:LASTEXITCODE) { 0 } else { \$global:LASTEXITCODE }',
      'Write-Output ($markerLiteral + \$scheduledJobExitCode)',
    ].join('; ');
  }

  void _handleOutputLine(String line, {required bool isError}) {
    final active = _activeCommand;
    if (!isError && _isPowerShellEcho(line)) {
      return;
    }

    if (!isError && active != null) {
      final marker = _markerFor(active.id);
      if (line.startsWith(marker)) {
        final exitCodeText = line.substring(marker.length).trim();
        final exitCode = int.tryParse(exitCodeText) ?? 1;
        if (exitCode != 0) {
          _emit(
            'Command finished with exit code $exitCode',
            isError: true,
            source: active.source,
            jobId: active.jobId,
          );
        }
        _activeCompleter?.complete();
        _activeCompleter = null;
        _activeCommand = null;
        _pumpQueue();
        return;
      }
    }

    _emit(
      line,
      isError: isError,
      source: active?.source ?? TerminalEventSource.system,
      jobId: active?.jobId,
    );
  }

  bool _isPowerShellEcho(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('>>')) {
      return true;
    }
    if (RegExp(r'^(\([^)]+\)\s*)?PS\b.*>').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  Future<String> _commandForJob(ScheduledJob job) async {
    switch (job.runMode) {
      case JobRunMode.powershell:
        return job.command;
      case JobRunMode.python:
        final commandFolder = p.dirname(
          _commandConfigRepository.resolveConfigPath(job.commandConfigPath),
        );
        await Directory(commandFolder).create(recursive: true);
        final scriptPath = p.join(commandFolder, 'run.py');
        await File(scriptPath).writeAsString(job.command, flush: true);
        final pythonPath = _pythonRuntime.sharedVenvPythonPath;
        final requirementsPath = await _pythonRuntime
            .requirementsPathForCommandFolder(commandFolder);
        final installCommand = requirementsPath == null
            ? ''
            : '& ${_quotePowerShell(pythonPath)} -m pip install -r '
                  '${_quotePowerShell(requirementsPath)}; ';
        return '$installCommand& ${_quotePowerShell(pythonPath)} '
            '${_quotePowerShell(scriptPath)}';
    }
  }

  Future<void> _enqueueSharedPythonEnvironmentInitialization() {
    final pythonPath = _pythonRuntime.pythonExecutablePath;
    final venvPath = _pythonRuntime.sharedVenvPath;
    final activatePath = p.join(venvPath, 'Scripts', 'Activate.ps1');
    final command = [
      'if (-not (Test-Path ${_quotePowerShell(_pythonRuntime.sharedVenvPythonPath)})) {',
      '& ${_quotePowerShell(pythonPath)} -m venv ${_quotePowerShell(venvPath)}',
      '}',
      'if (Test-Path ${_quotePowerShell(activatePath)}) {',
      '. ${_quotePowerShell(activatePath)}',
      '}',
    ].join(' ');
    return _enqueue(
      command,
      source: TerminalEventSource.system,
      label: 'Prepare shared Python venv',
    );
  }

  String _markerFor(int id) {
    return '__SCHEDULED_JOB_COMMAND_DONE_$id:';
  }

  String _quotePowerShell(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  void _emit(
    String text, {
    bool isError = false,
    required TerminalEventSource source,
    int? jobId,
  }) {
    if (_events.isClosed) {
      return;
    }
    _events.add(
      TerminalEvent(
        timestamp: DateTime.now(),
        text: text,
        isError: isError,
        source: source,
        jobId: jobId,
      ),
    );
  }
}

class _QueuedTerminalCommand {
  const _QueuedTerminalCommand({
    required this.id,
    required this.command,
    required this.label,
    required this.source,
    required this.completer,
    this.jobId,
  });

  final int id;
  final String command;
  final String label;
  final TerminalEventSource source;
  final int? jobId;
  final Completer<void> completer;
}
