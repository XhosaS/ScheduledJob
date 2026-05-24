import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart';

void main() {
  const messages = ScheduledJobValidationMessages(
    descriptionRequired: 'Description is required',
    positiveMinutesRequired: 'Enter a positive number of minutes',
    dateTimeRequired: 'Select a time',
    commandRequired: 'Command is required',
  );

  test(
    'loadJobs updates jobs, notifies listeners, and syncs scheduler',
    () async {
      final repository = _FakeScheduledJobRepository([
        ScheduledJob(
          id: 1,
          scheduledAt: DateTime(2026, 5, 24, 18),
          description: 'Existing job',
          runMode: JobRunMode.powershell,
          command: 'Get-Date',
          isEnabled: true,
        ),
      ]);
      final scheduler = _FakeScheduledJobScheduler();
      final viewModel = ScheduledJobsViewModel(
        repository,
        scheduler: scheduler,
      );
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.loadJobs();

      expect(viewModel.jobs.single.description, 'Existing job');
      expect(viewModel.isLoading, isFalse);
      expect(notifications, 2);
      expect(scheduler.started, isTrue);
      expect(scheduler.replacedJobs.single.id, 1);
    },
  );

  test('saveJob validates missing description and positive minutes', () async {
    final repository = _FakeScheduledJobRepository();
    final viewModel = ScheduledJobsViewModel(
      repository,
      scheduler: _FakeScheduledJobScheduler(),
    );

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

  test(
    'saveJob stores after-minutes job disabled and exits creating state',
    () async {
      final repository = _FakeScheduledJobRepository();
      final now = DateTime(2026, 5, 24, 18);
      final viewModel = ScheduledJobsViewModel(
        repository,
        nowProvider: () => now,
        scheduler: _FakeScheduledJobScheduler(),
      )..startCreating();

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
      expect(repository.addedJobs.single.isEnabled, isFalse);
      expect(viewModel.jobs.single.description, 'Write report');
      expect(viewModel.isCreating, isFalse);
    },
  );

  test('saveJob stores future clock time for today', () async {
    final repository = _FakeScheduledJobRepository();
    final now = DateTime(2026, 5, 24, 18);
    final viewModel =
        ScheduledJobsViewModel(
            repository,
            nowProvider: () => now,
            scheduler: _FakeScheduledJobScheduler(),
          )
          ..selectScheduleMode(ScheduleMode.atTime)
          ..setSelectedClockTime(
            const ClockTime(hour: 18, minute: 30, second: 15),
          );

    await viewModel.saveJob(
      minutesText: '',
      descriptionText: 'Write report',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(
      repository.addedJobs.single.scheduledAt,
      DateTime(2026, 5, 24, 18, 30, 15),
    );
  });

  test('saveJob stores past clock time for tomorrow', () async {
    final repository = _FakeScheduledJobRepository();
    final now = DateTime(2026, 5, 24, 18);
    final viewModel =
        ScheduledJobsViewModel(
            repository,
            nowProvider: () => now,
            scheduler: _FakeScheduledJobScheduler(),
          )
          ..selectScheduleMode(ScheduleMode.atTime)
          ..setSelectedClockTime(
            const ClockTime(hour: 17, minute: 30, second: 15),
          );

    await viewModel.saveJob(
      minutesText: '',
      descriptionText: 'Write report',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(
      repository.addedJobs.single.scheduledAt,
      DateTime(2026, 5, 25, 17, 30, 15),
    );
  });

  test('saveJob validates missing command', () async {
    final repository = _FakeScheduledJobRepository();
    final viewModel = ScheduledJobsViewModel(
      repository,
      scheduler: _FakeScheduledJobScheduler(),
    );

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
      isEnabled: true,
    );
    final repository = _FakeScheduledJobRepository([existingJob]);
    final now = DateTime(2026, 5, 24, 18);
    final viewModel =
        ScheduledJobsViewModel(
            repository,
            nowProvider: () => now,
            scheduler: _FakeScheduledJobScheduler(),
          )
          ..startEditing(existingJob)
          ..selectRunMode(JobRunMode.powershell)
          ..selectScheduleMode(ScheduleMode.atTime)
          ..setSelectedClockTime(
            const ClockTime(hour: 19, minute: 30, second: 5),
          );

    expect(viewModel.scheduleMode, ScheduleMode.atTime);

    await viewModel.saveJob(
      minutesText: '',
      descriptionText: 'Final report',
      commandText: 'Get-Date',
      validationMessages: messages,
    );

    expect(repository.updatedJobs.single.id, 1);
    expect(
      repository.updatedJobs.single.scheduledAt,
      DateTime(2026, 5, 24, 19, 30, 5),
    );
    expect(repository.updatedJobs.single.description, 'Final report');
    expect(repository.updatedJobs.single.runMode, JobRunMode.powershell);
    expect(repository.updatedJobs.single.command, 'Get-Date');
    expect(repository.updatedJobs.single.isEnabled, isTrue);
    expect(viewModel.jobs.single.description, 'Final report');
    expect(viewModel.isCreating, isFalse);
    expect(viewModel.selectedJob, isNull);
  });

  test('startEditing defaults schedule mode to after minutes', () {
    final existingJob = ScheduledJob(
      id: 1,
      scheduledAt: DateTime(2026, 5, 24, 18),
      description: 'Draft report',
      runMode: JobRunMode.python,
      command: 'print("draft")',
      isEnabled: false,
    );
    final repository = _FakeScheduledJobRepository([existingJob]);
    final viewModel = ScheduledJobsViewModel(
      repository,
      scheduler: _FakeScheduledJobScheduler(),
    )..startEditing(existingJob);

    expect(viewModel.scheduleMode, ScheduleMode.afterMinutes);
    expect(viewModel.selectedClockTime?.format(), '18:00:00');
  });

  test(
    'setJobEnabled recalculates next occurrence and syncs scheduler',
    () async {
      final repository = _FakeScheduledJobRepository([
        ScheduledJob(
          id: 1,
          scheduledAt: DateTime(2026, 5, 24, 17, 30, 15),
          description: 'Draft report',
          runMode: JobRunMode.powershell,
          command: 'Get-Date',
          isEnabled: false,
        ),
      ]);
      final scheduler = _FakeScheduledJobScheduler();
      final now = DateTime(2026, 5, 24, 18);
      final viewModel = ScheduledJobsViewModel(
        repository,
        nowProvider: () => now,
        scheduler: scheduler,
      );
      await viewModel.loadJobs();

      await viewModel.setJobEnabled(viewModel.jobs.single, true);

      expect(viewModel.jobs.single.isEnabled, isTrue);
      expect(
        viewModel.jobs.single.scheduledAt,
        DateTime(2026, 5, 25, 17, 30, 15),
      );
      expect(scheduler.upsertedJobs.single.id, 1);
    },
  );

  test('completed scheduler job is disabled once', () async {
    final repository = _FakeScheduledJobRepository([
      ScheduledJob(
        id: 1,
        scheduledAt: DateTime(2026, 5, 24, 18),
        description: 'Draft report',
        runMode: JobRunMode.powershell,
        command: 'Get-Date',
        isEnabled: true,
      ),
    ]);
    final scheduler = _FakeScheduledJobScheduler();
    final viewModel = ScheduledJobsViewModel(repository, scheduler: scheduler);
    await viewModel.loadJobs();

    scheduler.complete(1);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.jobs.single.isEnabled, isFalse);
    expect(repository.enabledUpdates.single.$1, 1);
    expect(repository.enabledUpdates.single.$2, isFalse);
  });

  test('deleteJob removes job, scheduler entry, and active editor', () async {
    final job = ScheduledJob(
      id: 1,
      scheduledAt: DateTime(2026, 5, 24, 18),
      description: 'Draft report',
      runMode: JobRunMode.powershell,
      command: 'Get-Date',
      isEnabled: true,
    );
    final repository = _FakeScheduledJobRepository([job]);
    final scheduler = _FakeScheduledJobScheduler();
    final viewModel = ScheduledJobsViewModel(repository, scheduler: scheduler);
    await viewModel.loadJobs();
    viewModel.startEditing(job);

    await viewModel.deleteJob(job);

    expect(viewModel.jobs, isEmpty);
    expect(viewModel.isCreating, isFalse);
    expect(viewModel.selectedJob, isNull);
    expect(repository.deletedIds, [1]);
    expect(scheduler.removedJobIds, contains(1));
  });
}

class _FakeScheduledJobRepository implements ScheduledJobRepository {
  _FakeScheduledJobRepository([List<ScheduledJob>? initialJobs])
    : _jobs = [...?initialJobs];

  final List<ScheduledJob> _jobs;
  final List<ScheduledJob> addedJobs = [];
  final List<ScheduledJob> updatedJobs = [];
  final List<(int, bool, DateTime)> enabledUpdates = [];
  final List<int> deletedIds = [];

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
    addedJobs.add(job);
    return job;
  }

  @override
  Future<List<ScheduledJob>> fetchJobs() async {
    return List.unmodifiable(_jobs);
  }

  @override
  Future<void> deleteJob(int id) async {
    _jobs.removeWhere((job) => job.id == id);
    deletedIds.add(id);
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
    enabledUpdates.add((id, isEnabled, scheduledAt));
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
    updatedJobs.add(job);
    return job;
  }
}

class _FakeScheduledJobScheduler implements ScheduledJobScheduler {
  final StreamController<int> _completedJobIds =
      StreamController<int>.broadcast();
  final List<ScheduledJob> replacedJobs = [];
  final List<ScheduledJob> upsertedJobs = [];
  final List<int> removedJobIds = [];
  bool started = false;
  bool disposed = false;

  @override
  Stream<int> get completedJobIds => _completedJobIds.stream;

  @override
  Future<void> start() async {
    started = true;
  }

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

  void complete(int jobId) {
    _completedJobIds.add(jobId);
  }

  @override
  void dispose() {
    disposed = true;
    _completedJobIds.close();
  }
}
