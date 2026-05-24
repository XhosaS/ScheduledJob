// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/background_command_terminal_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/command_environment_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/command_config_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/command_config.dart';
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
    required this.commandEnvironmentFailed,
  });

  final String descriptionRequired;
  final String positiveMinutesRequired;
  final String dateTimeRequired;
  final String commandRequired;
  final String commandEnvironmentFailed;
}

class TerminalLine {
  const TerminalLine({
    required this.timestamp,
    required this.text,
    required this.isError,
    required this.source,
    this.jobId,
  });

  factory TerminalLine.fromEvent(TerminalEvent event) {
    return TerminalLine(
      timestamp: event.timestamp,
      text: event.text,
      isError: event.isError,
      source: event.source,
      jobId: event.jobId,
    );
  }

  final DateTime timestamp;
  final String text;
  final bool isError;
  final TerminalEventSource source;
  final int? jobId;
}

class ScheduledJobsViewModel extends ChangeNotifier {
  ScheduledJobsViewModel(
    this._repository, {
    NowProvider? nowProvider,
    ScheduledJobScheduler? scheduler,
    CommandConfigRepository? commandConfigRepository,
    CommandEnvironmentService? commandEnvironmentService,
    BackgroundCommandTerminalService? terminalService,
    Locale? locale,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _scheduler = scheduler ?? IsolateScheduledJobScheduler(),
       _commandConfigRepository = commandConfigRepository,
       _terminalService = terminalService,
       _locale = locale ?? const Locale('en');

  final ScheduledJobRepository _repository;
  final NowProvider _nowProvider;
  final ScheduledJobScheduler _scheduler;
  final CommandConfigRepository? _commandConfigRepository;
  final BackgroundCommandTerminalService? _terminalService;
  final Locale _locale;
  StreamSubscription<int>? _completedJobSubscription;
  StreamSubscription<TerminalEvent>? _terminalEventSubscription;

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
  String? _commandEnvironmentError;
  String? _terminalInputError;
  List<RecommendedCommand> _recommendedCommands = const [];
  List<TerminalLine> _terminalLines = const [];
  bool _isTerminalExpanded = false;
  String? _selectedRecommendedCommandSlug;
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
  String? get commandEnvironmentError => _commandEnvironmentError;
  String? get terminalInputError => _terminalInputError;
  List<RecommendedCommand> get recommendedCommands => _recommendedCommands;
  List<TerminalLine> get terminalLines => _terminalLines;
  bool get isTerminalExpanded => _isTerminalExpanded;

  Future<void> loadJobs() async {
    await _ensureSchedulerStarted();
    _isLoading = true;
    notifyListeners();

    await _loadRecommendedCommands();
    _jobs = await _repository.fetchJobs();
    await _repairMissingCommandFolders();
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
    _commandEnvironmentError = null;
    _selectedRecommendedCommandSlug = null;
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
    _selectedRecommendedCommandSlug = null;
    notifyListeners();
  }

  void selectRecommendedCommand(RecommendedCommand command) {
    _runMode = command.config.type;
    _selectedRecommendedCommandSlug = command.slug;
    notifyListeners();
  }

  void toggleTerminalExpanded() {
    _isTerminalExpanded = !_isTerminalExpanded;
    notifyListeners();
  }

  void clearTerminalLines() {
    _terminalLines = const [];
    notifyListeners();
  }

  Future<void> submitTerminalCommand({
    required String commandText,
    required String commandRequired,
  }) async {
    final command = commandText.trim();
    _terminalInputError = command.isEmpty ? commandRequired : null;
    notifyListeners();
    if (_terminalInputError != null) {
      return;
    }

    await _terminalService?.enqueueUserCommand(command);
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
    _commandEnvironmentError = null;
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

    final commandConfig = CommandConfig(
      type: _runMode,
      command: command,
      description: description,
    );
    final selectedJob = _selectedJob;
    ScheduledJob? createdJob;
    try {
      if (selectedJob == null) {
        createdJob = await _repository.addJob(
          scheduledAt: scheduledAt,
          description: description,
          runMode: _runMode,
          command: command,
          commandConfigPath: '',
          isEnabled: false,
        );
        final commandConfigPath = await _prepareCommandFolder(
          jobId: createdJob.id,
          config: commandConfig,
        );
        await _repository.updateJob(
          id: createdJob.id,
          scheduledAt: scheduledAt,
          description: description,
          runMode: _runMode,
          command: command,
          commandConfigPath: commandConfigPath,
          isEnabled: false,
        );
      } else {
        final commandConfigPath = await _prepareCommandFolder(
          jobId: selectedJob.id,
          config: commandConfig,
          sourceConfigPath: selectedJob.commandConfigPath,
        );
        await _repository.updateJob(
          id: selectedJob.id,
          scheduledAt: scheduledAt,
          description: description,
          runMode: _runMode,
          command: command,
          commandConfigPath: commandConfigPath,
          isEnabled: selectedJob.isEnabled,
        );
      }
    } on Object {
      if (createdJob != null) {
        await _repository.deleteJob(createdJob.id);
      }
      _commandEnvironmentError = validationMessages.commandEnvironmentFailed;
      notifyListeners();
      return;
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
    await _commandConfigRepository?.deleteJobCommandFolder(
      job.commandConfigPath,
    );
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
    _commandEnvironmentError = null;
    _selectedRecommendedCommandSlug = null;
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
    _terminalEventSubscription = _terminalService?.events.listen(
      _handleTerminalEvent,
    );
    _schedulerStarted = true;
  }

  Future<void> _loadRecommendedCommands() async {
    final repository = _commandConfigRepository;
    if (repository == null) {
      return;
    }
    _recommendedCommands = await repository.fetchRecommendedCommands(_locale);
  }

  Future<void> _repairMissingCommandFolders() async {
    final repository = _commandConfigRepository;
    if (repository == null) {
      return;
    }

    var repaired = false;
    for (final job in _jobs.where((job) => job.commandConfigPath.isEmpty)) {
      final draft = await repository.createJobCommandFolderDraft(
        jobId: job.id,
        config: CommandConfig(
          type: job.runMode,
          command: job.command,
          description: job.description,
        ),
      );
      final folder = await draft.commit();
      await _repository.updateJob(
        id: job.id,
        scheduledAt: job.scheduledAt,
        description: job.description,
        runMode: job.runMode,
        command: job.command,
        commandConfigPath: folder.relativeConfigPath,
        isEnabled: job.isEnabled,
      );
      repaired = true;
    }

    if (repaired) {
      _jobs = await _repository.fetchJobs();
    }
  }

  Future<String> _prepareCommandFolder({
    required int jobId,
    required CommandConfig config,
    String? sourceConfigPath,
  }) async {
    final repository = _commandConfigRepository;
    if (repository == null) {
      return '';
    }

    final draft = await repository.createJobCommandFolderDraft(
      jobId: jobId,
      config: config,
      templateSlug: _selectedRecommendedCommandSlug,
      sourceConfigPath: _selectedRecommendedCommandSlug == null
          ? sourceConfigPath
          : null,
      locale: _selectedRecommendedCommandSlug == null ? null : _locale,
    );
    try {
      final folder = await draft.commit();
      return folder.relativeConfigPath;
    } on Object {
      await draft.discard();
      rethrow;
    }
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

  void _handleTerminalEvent(TerminalEvent event) {
    final currentLines = _terminalLines.length >= 499
        ? _terminalLines.sublist(_terminalLines.length - 499)
        : _terminalLines;
    _terminalLines = [...currentLines, TerminalLine.fromEvent(event)];
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _completedJobSubscription?.cancel();
    _terminalEventSubscription?.cancel();
    _scheduler.dispose();
    super.dispose();
  }
}
