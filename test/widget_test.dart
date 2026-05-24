import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/app.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/background_command_terminal_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/command_environment_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/command_config_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/command_config.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:scheduled_job/l10n/generated/app_localizations_zh.dart';

void main() {
  late _FakeScheduledJobRepository repository;
  late _FakeScheduledJobScheduler scheduler;
  late _FakeCommandConfigRepository commandConfigRepository;
  late _FakeCommandEnvironmentService commandEnvironmentService;
  late _FakeTerminalService terminalService;

  setUp(() {
    repository = _FakeScheduledJobRepository();
    scheduler = _FakeScheduledJobScheduler();
    commandConfigRepository = _FakeCommandConfigRepository();
    commandEnvironmentService = _FakeCommandEnvironmentService();
    terminalService = _FakeTerminalService();
  });

  Widget buildApp({Locale? locale}) {
    return MyApp(
      repository: repository,
      locale: locale,
      scheduler: scheduler,
      commandConfigRepository: commandConfigRepository,
      commandEnvironmentService: commandEnvironmentService,
      terminalService: terminalService,
    );
  }

  testWidgets('shows two-page layout with an empty real job list', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
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

    await tester.pumpWidget(buildApp(locale: const Locale('zh')));
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
    await tester.pumpWidget(buildApp());
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
        commandConfigPath: 'jobs/1/command.json',
        isEnabled: false,
      ),
    );

    await tester.pumpWidget(buildApp());
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
    await tester.pumpWidget(buildApp());
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
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();
    await tester.tap(find.text('Python'));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recommendedCommandChip-powershell_shutdown')),
    );
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
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('newScheduledJobButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('minutesField')), '20');
    await tester.tap(
      find.byKey(const Key('recommendedCommandChip-powershell_shutdown')),
    );
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
        commandConfigPath: 'jobs/1/command.json',
        isEnabled: false,
      ),
    );

    await tester.pumpWidget(buildApp());
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
        commandConfigPath: 'jobs/1/command.json',
        isEnabled: true,
      ),
    );

    await tester.pumpWidget(buildApp());
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

  testWidgets('terminal pane is collapsed by default and accepts commands', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byKey(const Key('terminalCollapsedToggle')), findsOneWidget);
    expect(find.byKey(const Key('terminalCommandField')), findsNothing);

    await tester.tap(find.byKey(const Key('terminalCollapsedToggle')));
    await tester.pump();

    expect(find.byKey(const Key('terminalCommandField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('terminalCommandField')),
      'Get-Date',
    );
    await tester.tap(find.byKey(const Key('terminalSendButton')));
    await tester.pump();

    expect(terminalService.userCommands, ['Get-Date']);
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
    required String commandConfigPath,
    bool isEnabled = false,
  }) async {
    final job = ScheduledJob(
      id: _jobs.length + 1,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      commandConfigPath: commandConfigPath,
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
    required String commandConfigPath,
    required bool isEnabled,
  }) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    final job = ScheduledJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      commandConfigPath: commandConfigPath,
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

class _FakeCommandConfigRepository implements CommandConfigRepository {
  final List<RecommendedCommand> commands = const [
    RecommendedCommand(
      slug: 'powershell_shutdown',
      config: CommandConfig(
        type: JobRunMode.powershell,
        command: 'Stop-Computer -Force',
        description: 'Shutdown this computer',
      ),
    ),
  ];
  final List<String> deletedPaths = [];

  @override
  Future<CommandFolderDraft> createJobCommandFolderDraft({
    required int jobId,
    required CommandConfig config,
    String? templateSlug,
    String? sourceConfigPath,
    Locale? locale,
  }) async {
    final folder = CommandFolder(
      relativeConfigPath: 'jobs/$jobId.pending/command.json',
      absoluteFolderPath: 'jobs/$jobId.pending',
      absoluteConfigPath: 'jobs/$jobId.pending/command.json',
    );
    return CommandFolderDraft(
      folder: folder,
      commit: () async => CommandFolder(
        relativeConfigPath: 'jobs/$jobId/command.json',
        absoluteFolderPath: 'jobs/$jobId',
        absoluteConfigPath: 'jobs/$jobId/command.json',
      ),
      discard: () async {},
    );
  }

  @override
  Future<void> deleteJobCommandFolder(String relativeConfigPath) async {
    deletedPaths.add(relativeConfigPath);
  }

  @override
  Future<List<RecommendedCommand>> fetchRecommendedCommands(
    Locale locale,
  ) async {
    return commands;
  }

  @override
  String resolveConfigPath(String relativeConfigPath) {
    return relativeConfigPath;
  }
}

class _FakeCommandEnvironmentService implements CommandEnvironmentService {
  final List<CommandFolder> preparedFolders = [];

  @override
  Future<void> prepare(CommandFolder folder, CommandConfig config) async {
    preparedFolders.add(folder);
  }
}

class _FakeTerminalService implements BackgroundCommandTerminalService {
  final StreamController<TerminalEvent> _events =
      StreamController<TerminalEvent>.broadcast();
  final List<String> userCommands = [];

  @override
  Stream<TerminalEvent> get events => _events.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> enqueueScheduledJob(ScheduledJob job) async {}

  @override
  Future<void> enqueueUserCommand(String command) async {
    userCommands.add(command);
  }

  @override
  void dispose() {
    _events.close();
  }
}
