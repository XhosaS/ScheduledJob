enum JobRunMode {
  powershell('powershell'),
  python('python');

  const JobRunMode(this.storageValue);

  final String storageValue;

  static JobRunMode fromStorageValue(String value) {
    return tryFromStorageValue(value) ?? JobRunMode.powershell;
  }

  static JobRunMode? tryFromStorageValue(String value) {
    for (final mode in JobRunMode.values) {
      if (mode.storageValue == value) {
        return mode;
      }
    }
    return null;
  }
}

class ScheduledJob {
  const ScheduledJob({
    required this.id,
    required this.scheduledAt,
    required this.description,
    required this.runMode,
    required this.command,
    required this.commandConfigPath,
    required this.isEnabled,
  });

  final int id;
  final DateTime scheduledAt;
  final String description;
  final JobRunMode runMode;
  final String command;
  final String commandConfigPath;
  final bool isEnabled;

  ScheduledJob copyWith({
    int? id,
    DateTime? scheduledAt,
    String? description,
    JobRunMode? runMode,
    String? command,
    String? commandConfigPath,
    bool? isEnabled,
  }) {
    return ScheduledJob(
      id: id ?? this.id,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      description: description ?? this.description,
      runMode: runMode ?? this.runMode,
      command: command ?? this.command,
      commandConfigPath: commandConfigPath ?? this.commandConfigPath,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
