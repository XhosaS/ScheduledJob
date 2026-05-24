import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart';

void main() {
  const messages = ScheduledJobValidationMessages(
    descriptionRequired: 'Description is required',
    positiveMinutesRequired: 'Enter a positive number of minutes',
    dateTimeRequired: 'Select a date and time',
    commandRequired: 'Command is required',
  );

  test('loadJobs updates jobs and notifies listeners', () async {
    final repository = _FakeScheduledJobRepository([
      ScheduledJob(
        id: 1,
        scheduledAt: DateTime(2026, 5, 24, 18),
        description: 'Existing job',
        runMode: JobRunMode.powershell,
        command: 'Get-Date',
      ),
    ]);
    final viewModel = ScheduledJobsViewModel(repository);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.loadJobs();

    expect(viewModel.jobs.single.description, 'Existing job');
    expect(viewModel.isLoading, isFalse);
    expect(notifications, 2);
  });

  test('saveJob validates missing description and positive minutes', () async {
    final repository = _FakeScheduledJobRepository();
    final viewModel = ScheduledJobsViewModel(repository);

    await viewModel.saveJob(
      minutesText: '0',
      descriptionText: '',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(viewModel.descriptionError, 'Description is required');
    expect(viewModel.minutesError, 'Enter a positive number of minutes');
    expect(repository.addedJobs, isEmpty);
  });

  test('saveJob validates selected date time in atTime mode', () async {
    final repository = _FakeScheduledJobRepository();
    final viewModel = ScheduledJobsViewModel(repository)
      ..selectScheduleMode(ScheduleMode.atTime);

    await viewModel.saveJob(
      minutesText: '',
      descriptionText: 'Write report',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(viewModel.timeError, 'Select a date and time');
    expect(repository.addedJobs, isEmpty);
  });

  test('saveJob stores after-minutes job and exits creating state', () async {
    final repository = _FakeScheduledJobRepository();
    final now = DateTime(2026, 5, 24, 18);
    final viewModel = ScheduledJobsViewModel(repository, nowProvider: () => now)
      ..startCreating();

    await viewModel.saveJob(
      minutesText: '20',
      descriptionText: 'Write report',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(
      repository.addedJobs.single.scheduledAt,
      now.add(const Duration(minutes: 20)),
    );
    expect(repository.addedJobs.single.description, 'Write report');
    expect(repository.addedJobs.single.runMode, JobRunMode.powershell);
    expect(repository.addedJobs.single.command, 'Get-Date');
    expect(viewModel.jobs.single.description, 'Write report');
    expect(viewModel.isCreating, isFalse);
  });

  test('saveJob validates missing command', () async {
    final repository = _FakeScheduledJobRepository();
    final viewModel = ScheduledJobsViewModel(repository);

    await viewModel.saveJob(
      minutesText: '20',
      descriptionText: 'Write report',
      commandText: '',
      validationMessages: messages,
    );

    expect(viewModel.commandError, 'Command is required');
    expect(repository.addedJobs, isEmpty);
  });

  test('startEditing loads job and saveJob updates it', () async {
    final existingJob = ScheduledJob(
      id: 1,
      scheduledAt: DateTime(2026, 5, 24, 18),
      description: 'Draft report',
      runMode: JobRunMode.python,
      command: 'print("draft")',
    );
    final repository = _FakeScheduledJobRepository([existingJob]);
    final viewModel = ScheduledJobsViewModel(repository)
      ..startEditing(existingJob)
      ..selectRunMode(JobRunMode.powershell)
      ..setSelectedDateTime(DateTime(2026, 5, 24, 19, 30));

    await viewModel.saveJob(
      minutesText: '',
      descriptionText: 'Final report',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(repository.updatedJobs.single.id, 1);
    expect(
      repository.updatedJobs.single.scheduledAt,
      DateTime(2026, 5, 24, 19, 30),
    );
    expect(repository.updatedJobs.single.description, 'Final report');
    expect(repository.updatedJobs.single.runMode, JobRunMode.powershell);
    expect(repository.updatedJobs.single.command, 'Get-Date');
    expect(viewModel.jobs.single.description, 'Final report');
    expect(viewModel.isCreating, isFalse);
    expect(viewModel.selectedJob, isNull);
  });
}

class _FakeScheduledJobRepository implements ScheduledJobRepository {
  _FakeScheduledJobRepository([List<ScheduledJob>? initialJobs])
    : _jobs = [...?initialJobs];

  final List<ScheduledJob> _jobs;
  final List<ScheduledJob> addedJobs = [];
  final List<ScheduledJob> updatedJobs = [];

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
    addedJobs.add(job);
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
    updatedJobs.add(job);
    return job;
  }
}
