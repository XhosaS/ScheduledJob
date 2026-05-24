import 'package:flutter/material.dart';
import 'package:scheduled_job/app.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_database.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final database = ScheduledJobDatabase(databaseFactory: databaseFactoryFfi);
  final repository = SqliteScheduledJobRepository(database);

  runApp(MyApp(repository: repository));
}
