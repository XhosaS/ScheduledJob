import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_database.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

abstract class ScheduledJobRepository {
  Future<List<ScheduledJob>> fetchJobs();

  Future<ScheduledJob> addJob({
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    required String commandConfigPath,
    bool isEnabled = false,
  });

  Future<ScheduledJob> updateJob({
    required int id,
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    required String commandConfigPath,
    required bool isEnabled,
  });

  Future<void> setJobEnabled({
    required int id,
    required bool isEnabled,
    required DateTime scheduledAt,
  });

  Future<void> deleteJob(int id);
}

class SqliteScheduledJobRepository implements ScheduledJobRepository {
  const SqliteScheduledJobRepository(this._database);

  final ScheduledJobDatabase _database;

  @override
  Future<List<ScheduledJob>> fetchJobs() {
    return _database.fetchJobs();
  }

  @override
  Future<ScheduledJob> addJob({
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    required String commandConfigPath,
    bool isEnabled = false,
  }) {
    return _database.insertJob(
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      commandConfigPath: commandConfigPath,
      isEnabled: isEnabled,
    );
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
  }) {
    return _database.updateJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      commandConfigPath: commandConfigPath,
      isEnabled: isEnabled,
    );
  }

  @override
  Future<void> setJobEnabled({
    required int id,
    required bool isEnabled,
    required DateTime scheduledAt,
  }) {
    return _database.setJobEnabled(
      id: id,
      isEnabled: isEnabled,
      scheduledAt: scheduledAt,
    );
  }

  @override
  Future<void> deleteJob(int id) {
    return _database.deleteJob(id);
  }
}
