import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/app.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:scheduled_job/l10n/generated/app_localizations_zh.dart';

void main() {
  late _FakeScheduledJobRepository repository;
  late _FakeScheduledJobScheduler scheduler;

  setUp(() {
    repository = _FakeScheduledJobRepository();
    scheduler = _FakeScheduledJobScheduler();
  });

  testWidgets('shows two-page layout with an empty real job list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    expect(find.text('Scheduled Job'), findsOneWidget);
    expect(find.text('New Scheduled Job'), findsOneWidget);
    expect(find.text('Daily backup'), findsNothing);
    expect(find.text('Data cleanup'), findsNothing);
    expect(find.text('Report export'), findsNothing);
    expect(find.text('Health check'), findsNothing);
    expect(find.text('Notification sync'), findsNothing);
  });

  testWidgets('shows simplified Chinese shell text for zh locale', (
    tester,
  ) async {
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      MyApp(
        repository: repository,
        locale: const Locale('zh'),
        scheduler: scheduler,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.appTitle), findsOneWidget);
    expect(find.text(zh.newScheduledJobButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();

    expect(find.text(zh.newScheduledJobTitle), findsWidgets);
    expect(find.text(zh.atTime), findsOneWidget);
    expect(find.text(zh.description), findsOneWidget);
    expect(find.text(zh.recommendedCommands), findsOneWidget);
    expect(find.widgetWithText(TextField, zh.command), findsOneWidget);
  });

  testWidgets('creates a scheduled job after minutes', (tester) async {
    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();

    expect(find.text('New Scheduled Job'), findsWidgets);
    expect(find.text('After minutes'), findsOneWidget);
    expect(find.text('At time'), findsOneWidget);
    expect(find.text('PowerShell'), findsOneWidget);
    expect(find.text('Python'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Command'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('minutesField')), '20');
    await tester.enterText(find.byKey(const Key('commandField')), 'Get-Date');
    await tester.enterText(
      find.byKey(const Key('descriptionField')),
      'Write report',
    );
    await tester.ensureVisible(find.byKey(const Key('saveScheduledJobButton')));
    await tester.tap(find.byKey(const Key('saveScheduledJobButton')));
    await tester.pump();

    expect(find.text('Write report'), findsOneWidget);
    expect(find.byKey(const Key('minutesField')), findsNothing);

    final jobs = await repository.fetchJobs();
    expect(jobs, hasLength(1));
    expect(jobs.single.description, 'Write report');
    expect(jobs.single.runMode, JobRunMode.powershell);
    expect(jobs.single.command, 'Get-Date');
    expect(jobs.single.isEnabled, isFalse);
    expect(find.byKey(const Key('jobEnabledSwitch-1')), findsOneWidget);
  });

  testWidgets('loads a selected job into the form and updates it', (
    tester,
  ) async {
    repository.seed(
      ScheduledJob(
        id: 1,
        scheduledAt: DateTime(2026, 5, 24, 18, 30),
        description: 'Draft report',
        runMode: JobRunMode.python,
        command: 'print("draft")',
        isEnabled: false,
      ),
    );

    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.tap(find.text('Draft report'));
    await tester.pump();

    expect(find.text('New Scheduled Job'), findsWidgets);
    expect(find.byKey(const Key('minutesField')), findsOneWidget);
    expect(find.text('18:30:00'), findsOneWidget);
    expect(find.text('Next 2026-05-24'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Draft report'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'print("draft")'), findsOneWidget);
    expect(find.text('Python'), findsWidgets);

    await tester.tap(find.text('PowerShell'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('minutesField')), '20');
    await tester.enterText(find.byKey(const Key('commandField')), 'Get-Date');
    await tester.enterText(
      find.byKey(const Key('descriptionField')),
      'Final report',
    );
    await tester.ensureVisible(find.byKey(const Key('saveScheduledJobButton')));
    await tester.tap(find.byKey(const Key('saveScheduledJobButton')));
    await tester.pump();

    expect(find.text('Draft report'), findsNothing);
    expect(find.text('Final report'), findsOneWidget);

    final jobs = await repository.fetchJobs();
    expect(jobs, hasLength(1));
    expect(jobs.single.id, 1);
    expect(jobs.single.description, 'Final report');
    expect(jobs.single.runMode, JobRunMode.powershell);
    expect(jobs.single.command, 'Get-Date');
  });

  testWidgets('does not save a scheduled job without description', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('minutesField')), '20');
    await tester.enterText(find.byKey(const Key('commandField')), 'Get-Date');
    await tester.ensureVisible(find.byKey(const Key('saveScheduledJobButton')));
    await tester.tap(find.byKey(const Key('saveScheduledJobButton')));
    await tester.pump();

    expect(find.text('Description is required'), findsOneWidget);
    expect(find.byKey(const Key('minutesField')), findsOneWidget);
    expect(await repository.fetchJobs(), isEmpty);
  });

  testWidgets('recommended shutdown command fills command and description', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();
    await tester.tap(find.text('Python'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recommendedShutdownCommandChip')));
    await tester.pump();

    expect(
      find.widgetWithText(TextField, 'Stop-Computer -Force'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Shutdown this computer'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SegmentedButton<JobRunMode>>(
            find.byType(SegmentedButton<JobRunMode>).last,
          )
          .selected,
      {JobRunMode.powershell},
    );
  });

  testWidgets('recommended shutdown command can be saved', (tester) async {
    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('minutesField')), '20');
    await tester.tap(find.byKey(const Key('recommendedShutdownCommandChip')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('saveScheduledJobButton')));
    await tester.tap(find.byKey(const Key('saveScheduledJobButton')));
    await tester.pump();

    final jobs = await repository.fetchJobs();
    expect(jobs.single.runMode, JobRunMode.powershell);
    expect(jobs.single.command, 'Stop-Computer -Force');
    expect(jobs.single.description, 'Shutdown this computer');
  });

  testWidgets('switch enables a job without opening the editor', (
    tester,
  ) async {
    repository.seed(
      ScheduledJob(
        id: 1,
        scheduledAt: DateTime(2026, 5, 24, 18, 30),
        description: 'Draft report',
        runMode: JobRunMode.powershell,
        command: 'Get-Date',
        isEnabled: false,
      ),
    );

    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('jobEnabledSwitch-1')));
    await tester.pumpAndSettle();

    final jobs = await repository.fetchJobs();
    expect(jobs.single.isEnabled, isTrue);
    expect(scheduler.upsertedJobs.single.id, 1);
    expect(find.byKey(const Key('commandField')), findsNothing);
  });

  testWidgets('long press opens context menu and deletes a job', (
    tester,
  ) async {
    repository.seed(
      ScheduledJob(
        id: 1,
        scheduledAt: DateTime(2026, 5, 24, 18, 30),
        description: 'Draft report',
        runMode: JobRunMode.powershell,
        command: 'Get-Date',
        isEnabled: true,
      ),
    );

    await tester.pumpWidget(
      MyApp(repository: repository, scheduler: scheduler),
    );
    await tester.pump();

    await tester.longPress(find.text('Draft report'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Draft report'), findsNothing);
    expect(await repository.fetchJobs(), isEmpty);
    expect(scheduler.removedJobIds, contains(1));
  });
}

class _FakeScheduledJobRepository implements ScheduledJobRepository {
  final List<ScheduledJob> _jobs = [];

  void seed(ScheduledJob job) {
    _jobs.add(job);
  }

  @override
  Future<ScheduledJob> addJob({
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    bool isEnabled = false,
  }) async {
    final job = ScheduledJob(
      id: _jobs.length + 1,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      isEnabled: isEnabled,
    );
    _jobs.add(job);
    return job;
  }

  @override
  Future<List<ScheduledJob>> fetchJobs() async {
    return List.unmodifiable(_jobs);
  }

  @override
  Future<void> deleteJob(int id) async {
    _jobs.removeWhere((job) => job.id == id);
  }

  @override
  Future<ScheduledJob> updateJob({
    required int id,
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    required bool isEnabled,
  }) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    final job = ScheduledJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      isEnabled: isEnabled,
    );
    _jobs[index] = job;
    return job;
  }

  @override
  Future<void> setJobEnabled({
    required int id,
    required bool isEnabled,
    required DateTime scheduledAt,
  }) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    _jobs[index] = _jobs[index].copyWith(
      isEnabled: isEnabled,
      scheduledAt: scheduledAt,
    );
  }
}

class _FakeScheduledJobScheduler implements ScheduledJobScheduler {
  final StreamController<int> _completedJobIds =
      StreamController<int>.broadcast();
  final List<ScheduledJob> replacedJobs = [];
  final List<ScheduledJob> upsertedJobs = [];
  final List<int> removedJobIds = [];

  @override
  Stream<int> get completedJobIds => _completedJobIds.stream;

  @override
  Future<void> start() async {}

  @override
  void replaceJobs(List<ScheduledJob> jobs) {
    replacedJobs
      ..clear()
      ..addAll(jobs.where((job) => job.isEnabled));
  }

  @override
  void upsertJob(ScheduledJob job) {
    upsertedJobs.add(job);
  }

  @override
  void removeJob(int jobId) {
    removedJobIds.add(jobId);
  }

  @override
  void dispose() {
    _completedJobIds.close();
  }
}
