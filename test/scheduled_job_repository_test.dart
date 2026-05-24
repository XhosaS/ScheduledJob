import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_database.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late ScheduledJobDatabase database;
  late ScheduledJobRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = ScheduledJobDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    repository = SqliteScheduledJobRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('initializes the scheduled_jobs table', () async {
    final db = await database.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [ScheduledJobDatabase.tableName],
    );

    expect(rows, hasLength(1));
  });

  test('adds and fetches a job', () async {
    final scheduledAt = DateTime(2026, 5, 24, 18, 30);

    final created = await repository.addJob(
      scheduledAt: scheduledAt,
      description: 'Write report',
      runMode: JobRunMode.powershell,
      command: 'Get-Process',
    );
    final jobs = await repository.fetchJobs();

    expect(created.id, greaterThan(0));
    expect(jobs, hasLength(1));
    expect(jobs.single.id, created.id);
    expect(jobs.single.scheduledAt, scheduledAt);
    expect(jobs.single.description, 'Write report');
    expect(jobs.single.runMode, JobRunMode.powershell);
    expect(jobs.single.command, 'Get-Process');
    expect(jobs.single.isEnabled, isFalse);
  });

  test('fetches jobs ordered by scheduled time then id', () async {
    final later = DateTime(2026, 5, 24, 19);
    final earlier = DateTime(2026, 5, 24, 18);

    await repository.addJob(
      scheduledAt: later,
      description: 'Later',
      runMode: JobRunMode.powershell,
      command: 'Later',
    );
    await repository.addJob(
      scheduledAt: earlier,
      description: 'Earlier',
      runMode: JobRunMode.powershell,
      command: 'Earlier',
    );
    await repository.addJob(
      scheduledAt: earlier,
      description: 'Same time',
      runMode: JobRunMode.python,
      command: 'print("same")',
    );

    final jobs = await repository.fetchJobs();

    expect(jobs.map((job) => job.description), [
      'Earlier',
      'Same time',
      'Later',
    ]);
  });

  test('updates an existing job', () async {
    final created = await repository.addJob(
      scheduledAt: DateTime(2026, 5, 24, 18),
      description: 'Draft report',
      runMode: JobRunMode.powershell,
      command: 'Get-Date',
    );

    await repository.updateJob(
      id: created.id,
      scheduledAt: DateTime(2026, 5, 24, 19, 30),
      description: 'Final report',
      runMode: JobRunMode.python,
      command: 'print("final")',
      isEnabled: true,
    );

    final jobs = await repository.fetchJobs();

    expect(jobs, hasLength(1));
    expect(jobs.single.id, created.id);
    expect(jobs.single.scheduledAt, DateTime(2026, 5, 24, 19, 30));
    expect(jobs.single.description, 'Final report');
    expect(jobs.single.runMode, JobRunMode.python);
    expect(jobs.single.command, 'print("final")');
    expect(jobs.single.isEnabled, isTrue);
  });

  test('updates only enabled state and next scheduled time', () async {
    final created = await repository.addJob(
      scheduledAt: DateTime(2026, 5, 24, 18),
      description: 'Draft report',
      runMode: JobRunMode.powershell,
      command: 'Get-Date',
    );

    await repository.setJobEnabled(
      id: created.id,
      isEnabled: true,
      scheduledAt: DateTime(2026, 5, 25, 18),
    );

    final jobs = await repository.fetchJobs();

    expect(jobs.single.id, created.id);
    expect(jobs.single.scheduledAt, DateTime(2026, 5, 25, 18));
    expect(jobs.single.description, 'Draft report');
    expect(jobs.single.runMode, JobRunMode.powershell);
    expect(jobs.single.command, 'Get-Date');
    expect(jobs.single.isEnabled, isTrue);
  });

  test('deletes a job', () async {
    final created = await repository.addJob(
      scheduledAt: DateTime(2026, 5, 24, 18),
      description: 'Draft report',
      runMode: JobRunMode.powershell,
      command: 'Get-Date',
    );

    await repository.deleteJob(created.id);

    expect(await repository.fetchJobs(), isEmpty);
  });

  test('migrates version 1 jobs to version 2 defaults', () async {
    final path = p.join(
      await databaseFactoryFfi.getDatabasesPath(),
      'scheduled_job_migration_test.db',
    );
    await databaseFactoryFfi.deleteDatabase(path);

    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE ${ScheduledJobDatabase.tableName} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scheduled_at INTEGER NOT NULL,
  description TEXT NOT NULL
)
''');
        },
      ),
    );
    await v1.insert(ScheduledJobDatabase.tableName, {
      'scheduled_at': DateTime(2026, 5, 24, 18).millisecondsSinceEpoch,
      'description': 'Legacy job',
    });
    await v1.close();

    final migratedDatabase = ScheduledJobDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: 'scheduled_job_migration_test.db',
    );
    final migratedRepository = SqliteScheduledJobRepository(migratedDatabase);
    addTearDown(() async {
      await migratedDatabase.close();
      await databaseFactoryFfi.deleteDatabase(path);
    });

    final jobs = await migratedRepository.fetchJobs();

    expect(jobs, hasLength(1));
    expect(jobs.single.description, 'Legacy job');
    expect(jobs.single.runMode, JobRunMode.powershell);
    expect(jobs.single.command, isEmpty);
    expect(jobs.single.isEnabled, isFalse);
  });

  test('migrates version 2 jobs to version 3 disabled state', () async {
    final path = p.join(
      await databaseFactoryFfi.getDatabasesPath(),
      'scheduled_job_v2_migration_test.db',
    );
    await databaseFactoryFfi.deleteDatabase(path);

    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE ${ScheduledJobDatabase.tableName} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scheduled_at INTEGER NOT NULL,
  description TEXT NOT NULL,
  run_mode TEXT NOT NULL,
  command TEXT NOT NULL
)
''');
        },
      ),
    );
    await v2.insert(ScheduledJobDatabase.tableName, {
      'scheduled_at': DateTime(2026, 5, 24, 18).millisecondsSinceEpoch,
      'description': 'Version 2 job',
      'run_mode': JobRunMode.python.storageValue,
      'command': 'print("legacy")',
    });
    await v2.close();

    final migratedDatabase = ScheduledJobDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: 'scheduled_job_v2_migration_test.db',
    );
    final migratedRepository = SqliteScheduledJobRepository(migratedDatabase);
    addTearDown(() async {
      await migratedDatabase.close();
      await databaseFactoryFfi.deleteDatabase(path);
    });

    final jobs = await migratedRepository.fetchJobs();

    expect(jobs, hasLength(1));
    expect(jobs.single.description, 'Version 2 job');
    expect(jobs.single.runMode, JobRunMode.python);
    expect(jobs.single.command, 'print("legacy")');
    expect(jobs.single.isEnabled, isFalse);
  });
}
