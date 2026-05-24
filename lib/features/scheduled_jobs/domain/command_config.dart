import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

class CommandConfig {
  const CommandConfig({
    required this.type,
    required this.command,
    required this.description,
  });

  factory CommandConfig.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    final command = json['command'];
    final description = json['description'];
    if (type is! String || command is! String || description is! String) {
      throw const FormatException('Invalid command config');
    }

    final runMode = JobRunMode.tryFromStorageValue(type);
    if (runMode == null) {
      throw FormatException('Unsupported command type: $type');
    }

    return CommandConfig(
      type: runMode,
      command: command,
      description: description,
    );
  }

  final JobRunMode type;
  final String command;
  final String description;

  Map<String, Object> toJson() {
    return {
      'type': type.storageValue,
      'command': command,
      'description': description,
    };
  }
}

class RecommendedCommand {
  const RecommendedCommand({required this.slug, required this.config});

  final String slug;
  final CommandConfig config;
}
