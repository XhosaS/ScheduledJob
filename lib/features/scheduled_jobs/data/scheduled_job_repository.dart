import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_database.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

abstract class ScheduledJobRepository {
  Future<List<ScheduledJob>> fetchJobs();

  Future<ScheduledJob> addJob({
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
  });

  Future<ScheduledJob> updateJob({
    required int id,
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
  });
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
  }) {
    return _database.insertJob(
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
    );
  }

  @override
  Future<ScheduledJob> updateJob({
    required int id,
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
  }) {
    return _database.updateJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
    );
  }
}
