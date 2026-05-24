enum JobRunMode {
  powershell('powershell'),
  python('python');

  const JobRunMode(this.storageValue);

  final String storageValue;

  static JobRunMode fromStorageValue(String value) {
    return JobRunMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => JobRunMode.powershell,
    );
  }
}

class ScheduledJob {
  const ScheduledJob({
    required this.id,
    required this.scheduledAt,
    required this.description,
    required this.runMode,
    required this.command,
    required this.isEnabled,
  });

  final int id;
  final DateTime scheduledAt;
  final String description;
  final JobRunMode runMode;
  final String command;
  final bool isEnabled;

  ScheduledJob copyWith({
    int? id,
    DateTime? scheduledAt,
    String? description,
    JobRunMode? runMode,
    String? command,
    bool? isEnabled,
  }) {
    return ScheduledJob(
      id: id ?? this.id,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      description: description ?? this.description,
      runMode: runMode ?? this.runMode,
      command: command ?? this.command,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
