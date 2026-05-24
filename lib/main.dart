import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scheduled_job/app.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/background_command_terminal_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/command_environment_service.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/command_config_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_database.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final database = ScheduledJobDatabase(databaseFactory: databaseFactoryFfi);
  final repository = SqliteScheduledJobRepository(database);
  final commandWorkspacePath = p.join(
    await databaseFactoryFfi.getDatabasesPath(),
    'commands',
  );
  final pythonRuntime = PythonRuntimeService(
    commandWorkspacePath: commandWorkspacePath,
  );
  final commandConfigRepository = FileCommandConfigRepository(
    workspacePath: commandWorkspacePath,
  );
  final terminalService = PowerShellBackgroundCommandTerminalService(
    commandConfigRepository: commandConfigRepository,
    pythonRuntime: pythonRuntime,
  );

  runApp(
    MyApp(
      repository: repository,
      scheduler: IsolateScheduledJobScheduler(terminalService: terminalService),
      commandConfigRepository: commandConfigRepository,
      commandEnvironmentService: LocalCommandEnvironmentService(
        pythonRuntime: pythonRuntime,
      ),
      terminalService: terminalService,
    ),
  );
}
