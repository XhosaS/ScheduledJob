import 'package:path/path.dart' as p;
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ScheduledJobDatabase {
  ScheduledJobDatabase({
    required this.databaseFactory,
    this.databaseName = 'scheduled_jobs.db',
  });

  static const tableName = 'scheduled_jobs';

  final DatabaseFactory databaseFactory;
  final String databaseName;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path = databaseName == inMemoryDatabasePath
        ? inMemoryDatabasePath
        : p.join(await databaseFactory.getDatabasesPath(), databaseName);

    return _database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE $tableName ADD COLUMN run_mode TEXT NOT NULL DEFAULT 'powershell'",
            );
            await db.execute(
              "ALTER TABLE $tableName ADD COLUMN command TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE $tableName ADD COLUMN is_enabled INTEGER NOT NULL DEFAULT 0',
            );
          }
        },
      ),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<ScheduledJob> insertJob({
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    bool isEnabled = false,
  }) async {
    final db = await database;
    final id = await db.insert(tableName, {
      'scheduled_at': scheduledAt.millisecondsSinceEpoch,
      'description': description,
      'run_mode': runMode.storageValue,
      'command': command,
      'is_enabled': isEnabled ? 1 : 0,
    });

    return ScheduledJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      isEnabled: isEnabled,
    );
  }

  Future<ScheduledJob> updateJob({
    required int id,
    required DateTime scheduledAt,
    required String description,
    required JobRunMode runMode,
    required String command,
    required bool isEnabled,
  }) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'scheduled_at': scheduledAt.millisecondsSinceEpoch,
        'description': description,
        'run_mode': runMode.storageValue,
        'command': command,
        'is_enabled': isEnabled ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return ScheduledJob(
      id: id,
      scheduledAt: scheduledAt,
      description: description,
      runMode: runMode,
      command: command,
      isEnabled: isEnabled,
    );
  }

  Future<void> setJobEnabled({
    required int id,
    required bool isEnabled,
    required DateTime scheduledAt,
  }) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_enabled': isEnabled ? 1 : 0,
        'scheduled_at': scheduledAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteJob(int id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScheduledJob>> fetchJobs() async {
    final db = await database;
    final rows = await db.query(tableName, orderBy: 'scheduled_at ASC, id ASC');
    return rows.map(_jobFromRow).toList(growable: false);
  }

  ScheduledJob _jobFromRow(Map<String, Object?> row) {
    return ScheduledJob(
      id: row['id']! as int,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        row['scheduled_at']! as int,
      ),
      description: row['description']! as String,
      runMode: JobRunMode.fromStorageValue(row['run_mode']! as String),
      command: row['command']! as String,
      isEnabled: (row['is_enabled']! as int) == 1,
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE $tableName (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scheduled_at INTEGER NOT NULL,
  description TEXT NOT NULL,
  run_mode TEXT NOT NULL,
  command TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 0
)
''');
  }
}
