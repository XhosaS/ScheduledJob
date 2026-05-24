import 'package:flutter/foundation.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

enum ScheduleMode { afterMinutes, atTime }

typedef NowProvider = DateTime Function();

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
  ScheduledJobsViewModel(this._repository, {NowProvider? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  final ScheduledJobRepository _repository;
  final NowProvider _nowProvider;

  List<ScheduledJob> _jobs = const [];
  bool _isLoading = false;
  bool _isEditing = false;
  ScheduledJob? _selectedJob;
  ScheduleMode _scheduleMode = ScheduleMode.afterMinutes;
  JobRunMode _runMode = JobRunMode.powershell;
  DateTime? _selectedDateTime;
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
  DateTime? get selectedDateTime => _selectedDateTime;
  String? get minutesError => _minutesError;
  String? get descriptionError => _descriptionError;
  String? get timeError => _timeError;
  String? get commandError => _commandError;

  Future<void> loadJobs() async {
    _isLoading = true;
    notifyListeners();

    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    _isLoading = false;
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
    _scheduleMode = ScheduleMode.atTime;
    _runMode = job.runMode;
    _selectedDateTime = job.scheduledAt;
    _minutesError = null;
    _descriptionError = null;
    _timeError = null;
    _commandError = null;
    notifyListeners();
  }

  void selectScheduleMode(ScheduleMode mode) {
    _scheduleMode = mode;
    _minutesError = null;
    _timeError = null;
    notifyListeners();
  }

  void setSelectedDateTime(DateTime value) {
    _selectedDateTime = value;
    _timeError = null;
    notifyListeners();
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
    _timeError = !isAfterMinutes && _selectedDateTime == null
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
        : _selectedDateTime!;

    final selectedJob = _selectedJob;
    if (selectedJob == null) {
      await _repository.addJob(
        scheduledAt: scheduledAt,
        description: description,
        runMode: _runMode,
        command: command,
      );
    } else {
      await _repository.updateJob(
        id: selectedJob.id,
        scheduledAt: scheduledAt,
        description: description,
        runMode: _runMode,
        command: command,
      );
    }

    _jobs = await _repository.fetchJobs();
    if (_isDisposed) {
      return;
    }

    _isEditing = false;
    _selectedJob = null;
    _resetForm();
    notifyListeners();
  }

  void _resetForm() {
    _scheduleMode = ScheduleMode.afterMinutes;
    _runMode = JobRunMode.powershell;
    _selectedDateTime = null;
    _minutesError = null;
    _descriptionError = null;
    _timeError = null;
    _commandError = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
