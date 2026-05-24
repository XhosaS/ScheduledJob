import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/app.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:scheduled_job/l10n/generated/app_localizations_zh.dart';

void main() {
  late _FakeScheduledJobRepository repository;

  setUp(() {
    repository = _FakeScheduledJobRepository();
  });

  testWidgets('shows two-page layout with an empty real job list', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(repository: repository));
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
      MyApp(repository: repository, locale: const Locale('zh')),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.appTitle), findsOneWidget);
    expect(find.text(zh.newScheduledJobButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();

    expect(find.text(zh.newScheduledJobTitle), findsWidgets);
    expect(find.text(zh.atTime), findsOneWidget);
    expect(find.text(zh.description), findsOneWidget);
  });

  testWidgets('creates a scheduled job after minutes', (tester) async {
    await tester.pumpWidget(MyApp(repository: repository));
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
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pump();

    await tester.tap(find.text('Draft report'));
    await tester.pump();

    expect(find.text('New Scheduled Job'), findsWidgets);
    expect(find.text('2026-05-24 18:30'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Draft report'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'print("draft")'), findsOneWidget);
    expect(find.text('Python'), findsWidgets);

    await tester.tap(find.text('PowerShell'));
    await tester.pump();
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
    await tester.pumpWidget(MyApp(repository: repository));
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
  }) async {
    final job = ScheduledJob(
      id: _jobs.length + 1,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
    );
    _jobs.add(job);
    return job;
  }

  @override
  Future<List<ScheduledJob>> fetchJobs() async {
    return List.unmodifiable(_jobs);
  }

  @override
  Future<ScheduledJob> updateJob({
    required int id,
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
  }) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    final job = ScheduledJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
    );
    _jobs[index] = job;
    return job;
  }
}
