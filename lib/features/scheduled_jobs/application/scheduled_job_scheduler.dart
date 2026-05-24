import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _commandPort;
  final StreamController<int> _completedJobIds =
      StreamController<int>.broadcast();

  @override
  Stream<int> get completedJobIds => _completedJobIds.stream;

  @override
  Future<void> start() async {
    if (_isolate != null) {
      return;
    }

    final receivePort = ReceivePort();
    _receivePort = receivePort;
    _isolate = await Isolate.spawn(_schedulerEntryPoint, receivePort.sendPort);

    final completer = Completer<void>();
    receivePort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }

      if (message is Map && message['type'] == 'completed') {
        final id = message['id'];
        if (id is int) {
          _completedJobIds.add(id);
        }
      }
    });

    await completer.future;
  }

  @override
  void replaceJobs(List<ScheduledJob> jobs) {
    _commandPort?.send({
      'type': 'replace',
      'jobs': jobs
          .where((job) => job.isEnabled)
          .map(_ScheduledJobPayload.fromJob)
          .map((payload) => payload.toMap())
          .toList(growable: false),
    });
  }

  @override
  void upsertJob(ScheduledJob job) {
    if (!job.isEnabled) {
      removeJob(job.id);
      return;
    }

    _commandPort?.send({
      'type': 'upsert',
      'job': _ScheduledJobPayload.fromJob(job).toMap(),
    });
  }

  @override
  void removeJob(int jobId) {
    _commandPort?.send({'type': 'remove', 'id': jobId});
  }

  @override
  void dispose() {
    _commandPort?.send({'type': 'dispose'});
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _completedJobIds.close();
    _commandPort = null;
    _receivePort = null;
    _isolate = null;
  }
}

class _ScheduledJobPayload {
  const _ScheduledJobPayload({
    required this.id,
    required this.scheduledAt,
    required this.runMode,
    required this.command,
  });

  factory _ScheduledJobPayload.fromJob(ScheduledJob job) {
    return _ScheduledJobPayload(
      id: job.id,
      scheduledAt: job.scheduledAt,
      runMode: job.runMode.storageValue,
      command: job.command,
    );
  }

  factory _ScheduledJobPayload.fromMap(Map<Object?, Object?> map) {
    return _ScheduledJobPayload(
      id: map['id']! as int,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        map['scheduledAt']! as int,
      ),
      runMode: map['runMode']! as String,
      command: map['command']! as String,
    );
  }

  final int id;
  final DateTime scheduledAt;
  final String runMode;
  final String command;

  Map<String, Object> toMap() {
    return {
      'id': id,
      'scheduledAt': scheduledAt.millisecondsSinceEpoch,
      'runMode': runMode,
      'command': command,
    };
  }
}

void _schedulerEntryPoint(SendPort mainSendPort) {
  final commandPort = ReceivePort();
  final jobs = <int, _ScheduledJobPayload>{};
  Timer? timer;

  void scheduleNext() {
    timer?.cancel();
    timer = null;
    if (jobs.isEmpty) {
      return;
    }

    final next = jobs.values.reduce((a, b) {
      return a.scheduledAt.isBefore(b.scheduledAt) ? a : b;
    });
    final delay = next.scheduledAt.difference(DateTime.now());
    timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      final dueJob = jobs.remove(next.id);
      scheduleNext();
      if (dueJob == null) {
        return;
      }

      await _runJob(dueJob);
      mainSendPort.send({'type': 'completed', 'id': dueJob.id});
    });
  }

  commandPort.listen((message) {
    if (message is! Map) {
      return;
    }

    switch (message['type']) {
      case 'replace':
        jobs
          ..clear()
          ..addEntries(
            (message['jobs'] as List)
                .map((item) => Map<Object?, Object?>.from(item as Map))
                .map(_ScheduledJobPayload.fromMap)
                .map((job) => MapEntry(job.id, job)),
          );
        scheduleNext();
      case 'upsert':
        final job = _ScheduledJobPayload.fromMap(
          Map<Object?, Object?>.from(message['job']! as Map),
        );
        jobs[job.id] = job;
        scheduleNext();
      case 'remove':
        jobs.remove(message['id']);
        scheduleNext();
      case 'dispose':
        timer?.cancel();
        commandPort.close();
    }
  });

  mainSendPort.send(commandPort.sendPort);
}

Future<void> _runJob(_ScheduledJobPayload job) async {
  try {
    switch (JobRunMode.fromStorageValue(job.runMode)) {
      case JobRunMode.powershell:
        await Process.run('powershell.exe', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          job.command,
        ]);
      case JobRunMode.python:
        await Process.run('python', ['-c', job.command]);
    }
  } on Object {
    // Failure still consumes this one-shot job.
  }
}
