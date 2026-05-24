import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

enum ScheduleMode { afterMinutes, atTime }

typedef NowProvider = DateTime Function();

class ClockTime {
  const ClockTime({
    required this.hour,
    required this.minute,
    required this.second,
  });

  factory ClockTime.fromDateTime(DateTime value) {
    return ClockTime(
      hour: value.hour,
      minute: value.minute,
      second: value.second,
    );
  }

  final int hour;
  final int minute;
  final int second;

  DateTime nextOccurrence(DateTime now) {
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      second,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  String format() {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }
}

class ScheduledJobValidationMessages {
  const ScheduledJobValidationMessages({
    required this.descriptionRequired,
    required this.positiveMinutesRequired,
    required this.dateTimeRequired,
    required this.commandRequired,
  });

  final String descriptionRequired;
  final String positiveMinutesRequired;
  final String dateTimeRequired;
  final String commandRequired;
}

class ScheduledJobsViewModel extends ChangeNotifier {
  ScheduledJobsViewModel(
    this._repository, {
    NowProvider? nowProvider,
    ScheduledJobScheduler? scheduler,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _scheduler = scheduler ?? IsolateScheduledJobScheduler();

  final ScheduledJobRepository _repository;
  final NowProvider _nowProvider;
  final ScheduledJobScheduler _scheduler;
  StreamSubscription<int>? _completedJobSubscription;

  List<ScheduledJob> _jobs = const [];
  bool _isLoading = false;
  bool _isEditing = false;
  bool _schedulerStarted = false;
  ScheduledJob? _selectedJob;
  ScheduleMode _scheduleMode = ScheduleMode.afterMinutes;
  JobRunMode _runMode = JobRunMode.powershell;
  ClockTime? _selectedClockTime;
  String? _minutesError;
  String? _descriptionError;
  String? _timeError;
  String? _commandError;
  bool _isDisposed = false;

  List<ScheduledJob> get jobs => _jobs;
  bool get isLoading => _isLoading;
  bool get isCreating => _isEditing;
  bool get isEditingExistingJob => _selectedJob != null;
  ScheduledJob? get selectedJob => _selectedJob;
  ScheduleMode get scheduleMode => _scheduleMode;
  JobRunMode get runMode => _runMode;
  ClockTime? get selectedClockTime => _selectedClockTime;
  String? get minutesError => _minutesError;
  String? get descriptionError => _descriptionError;
  String? get timeError => _timeError;
  String? get commandError => _commandError;

  Future<void> loadJobs() async {
    await _ensureSchedulerStarted();
    _isLoading = true;
    notifyListeners();

    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    _isLoading = false;
    _scheduler.replaceJobs(_jobs);
    notifyListeners();
  }

  void startCreating() {
    _isEditing = true;
    _selectedJob = null;
    _resetForm();
    notifyListeners();
  }

  void cancelCreating() {
    _isEditing = false;
    _selectedJob = null;
    _resetForm();
    notifyListeners();
  }

  void startEditing(ScheduledJob job) {
    _isEditing = true;
    _selectedJob = job;
    _scheduleMode = ScheduleMode.afterMinutes;
    _runMode = job.runMode;
    _selectedClockTime = ClockTime.fromDateTime(job.scheduledAt);
    _minutesError = null;
    _descriptionError = null;
    _timeError = null;
    _commandError = null;
    notifyListeners();
  }

  void selectScheduleMode(ScheduleMode mode) {
    _scheduleMode = mode;
    if (mode == ScheduleMode.atTime && _selectedClockTime == null) {
      _selectedClockTime = ClockTime.fromDateTime(_nowProvider());
    }
    _minutesError = null;
    _timeError = null;
    notifyListeners();
  }

  void setSelectedClockTime(ClockTime value) {
    _selectedClockTime = value;
    _timeError = null;
    notifyListeners();
  }

  void setSelectedDateTime(DateTime value) {
    setSelectedClockTime(ClockTime.fromDateTime(value));
  }

  void selectRunMode(JobRunMode mode) {
    _runMode = mode;
    notifyListeners();
  }

  Future<void> saveJob({
    required String minutesText,
    required String descriptionText,
    required String commandText,
    required ScheduledJobValidationMessages validationMessages,
  }) async {
    final description = descriptionText.trim();
    final command = commandText.trim();
    final minutes = int.tryParse(minutesText.trim());
    final isAfterMinutes = _scheduleMode == ScheduleMode.afterMinutes;

    _descriptionError = description.isEmpty
        ? validationMessages.descriptionRequired
        : null;
    _minutesError = isAfterMinutes && (minutes == null || minutes <= 0)
        ? validationMessages.positiveMinutesRequired
        : null;
    _timeError = !isAfterMinutes && _selectedClockTime == null
        ? validationMessages.dateTimeRequired
        : null;
    _commandError = command.isEmpty ? validationMessages.commandRequired : null;
    notifyListeners();

    if (_descriptionError != null ||
        _minutesError != null ||
        _timeError != null ||
        _commandError != null) {
      return;
    }

    final scheduledAt = isAfterMinutes
        ? _nowProvider().add(Duration(minutes: minutes!))
        : _selectedClockTime!.nextOccurrence(_nowProvider());

    final selectedJob = _selectedJob;
    if (selectedJob == null) {
      await _repository.addJob(
        scheduledAt: scheduledAt,
        description: description,
        runMode: _runMode,
        command: command,
        isEnabled: false,
      );
    } else {
      await _repository.updateJob(
        id: selectedJob.id,
        scheduledAt: scheduledAt,
        description: description,
        runMode: _runMode,
        command: command,
        isEnabled: selectedJob.isEnabled,
      );
    }

    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    _isEditing = false;
    _selectedJob = null;
    _scheduler.replaceJobs(_jobs);
    _resetForm();
    notifyListeners();
  }

  Future<void> setJobEnabled(ScheduledJob job, bool isEnabled) async {
    final scheduledAt = isEnabled
        ? ClockTime.fromDateTime(job.scheduledAt).nextOccurrence(_nowProvider())
        : job.scheduledAt;

    await _repository.setJobEnabled(
      id: job.id,
      isEnabled: isEnabled,
      scheduledAt: scheduledAt,
    );
    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    final updatedJob = _jobs.firstWhere((item) => item.id == job.id);
    if (updatedJob.isEnabled) {
      _scheduler.upsertJob(updatedJob);
    } else {
      _scheduler.removeJob(updatedJob.id);
    }

    notifyListeners();
  }

  Future<void> deleteJob(ScheduledJob job) async {
    await _repository.deleteJob(job.id);
    _scheduler.removeJob(job.id);
    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    if (_selectedJob?.id == job.id) {
      _isEditing = false;
      _selectedJob = null;
      _resetForm();
    }

    notifyListeners();
  }

  void _resetForm() {
    _scheduleMode = ScheduleMode.afterMinutes;
    _runMode = JobRunMode.powershell;
    _selectedClockTime = null;
    _minutesError = null;
    _descriptionError = null;
    _timeError = null;
    _commandError = null;
  }

  Future<void> _ensureSchedulerStarted() async {
    if (_schedulerStarted) {
      return;
    }

    await _scheduler.start();
    if (_isDisposed) {
      return;
    }

    _completedJobSubscription = _scheduler.completedJobIds.listen(
      _handleScheduledJobCompleted,
    );
    _schedulerStarted = true;
  }

  Future<void> _handleScheduledJobCompleted(int jobId) async {
    final matchingJobs = _jobs.where((job) => job.id == jobId);
    if (matchingJobs.isEmpty) {
      return;
    }

    final job = matchingJobs.first;
    await _repository.setJobEnabled(
      id: job.id,
      isEnabled: false,
      scheduledAt: job.scheduledAt,
    );
    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _completedJobSubscription?.cancel();
    _scheduler.dispose();
    super.dispose();
  }
}
