import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/background_command_terminal_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

void main() {
  test(
    'scheduler runs due jobs through terminal queue and completes them',
    () async {
      final terminalService = _FakeTerminalService();
      final scheduler = IsolateScheduledJobScheduler(
        terminalService: terminalService,
      );
      final completed = <int>[];
      final subscription = scheduler.completedJobIds.listen(completed.add);
      addTearDown(() async {
        await subscription.cancel();
        scheduler.dispose();
      });

      await scheduler.start();
      scheduler.replaceJobs([
        ScheduledJob(
          id: 1,
          scheduledAt: DateTime.now().subtract(const Duration(seconds: 1)),
          description: 'Due job',
          runMode: JobRunMode.powershell,
          command: 'Get-Date',
          commandConfigPath: 'jobs/1/command.json',
          isEnabled: true,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(terminalService.started, isTrue);
      expect(terminalService.scheduledJobs.single.id, 1);
      expect(completed, [1]);
    },
  );
}

class _FakeTerminalService implements BackgroundCommandTerminalService {
  final StreamController<TerminalEvent> _events =
      StreamController<TerminalEvent>.broadcast();
  final List<ScheduledJob> scheduledJobs = [];
  bool started = false;

  @override
  Stream<TerminalEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> enqueueScheduledJob(ScheduledJob job) async {
    scheduledJobs.add(job);
  }

  @override
  Future<void> enqueueUserCommand(String command) async {}

  @override
  void dispose() {
    _events.close();
  }
}
