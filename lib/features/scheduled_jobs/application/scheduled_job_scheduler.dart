// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:scheduled_job/features/scheduled_jobs/application/background_command_terminal_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

abstract class ScheduledJobScheduler {
  Stream<int> get completedJobIds;

  Future<void> start();

  void replaceJobs(List<ScheduledJob> jobs);

  void upsertJob(ScheduledJob job);

  void removeJob(int jobId);

  void dispose();
}

class IsolateScheduledJobScheduler implements ScheduledJobScheduler {
  IsolateScheduledJobScheduler({
    BackgroundCommandTerminalService? terminalService,
    String? commandWorkspacePath,
    String? pythonExecutablePath,
  }) : _terminalService = terminalService;

  final BackgroundCommandTerminalService? _terminalService;
  final StreamController<int> _completedJobIds =
      StreamController<int>.broadcast();
  final Map<int, ScheduledJob> _jobs = {};
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<int> get completedJobIds => _completedJobIds.stream;

  @override
  Future<void> start() async {
    if (_started) {
      return;
    }
    await _terminalService?.start();
    _started = true;
  }

  @override
  void replaceJobs(List<ScheduledJob> jobs) {
    _jobs
      ..clear()
      ..addEntries(
        jobs.where((job) => job.isEnabled).map((job) => MapEntry(job.id, job)),
      );
    _scheduleNext();
  }

  @override
  void upsertJob(ScheduledJob job) {
    if (!job.isEnabled) {
      removeJob(job.id);
      return;
    }

    _jobs[job.id] = job;
    _scheduleNext();
  }

  @override
  void removeJob(int jobId) {
    _jobs.remove(jobId);
    _scheduleNext();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _terminalService?.dispose();
    _completedJobIds.close();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = null;
    if (_jobs.isEmpty || _disposed) {
      return;
    }

    final next = _jobs.values.reduce((a, b) {
      return a.scheduledAt.isBefore(b.scheduledAt) ? a : b;
    });
    final delay = next.scheduledAt.difference(DateTime.now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      final dueJob = _jobs.remove(next.id);
      _scheduleNext();
      if (dueJob != null) {
        unawaited(_runJob(dueJob));
      }
    });
  }

  Future<void> _runJob(ScheduledJob job) async {
    try {
      await _terminalService?.enqueueScheduledJob(job);
    } on Object {
      // Failure still consumes this one-shot job.
    }
    if (!_disposed) {
      _completedJobIds.add(job.id);
    }
  }
}
