import 'package:flutter_test/flutter_test.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/command_config.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

void main() {
  test('parses and serializes command config json', () {
    final config = CommandConfig.fromJson({
      'type': 'python',
      'command': 'print("hello")',
      'description': 'Say hello',
    });

    expect(config.type, JobRunMode.python);
    expect(config.command, 'print("hello")');
    expect(config.description, 'Say hello');
    expect(config.toJson(), {
      'type': 'python',
      'command': 'print("hello")',
      'description': 'Say hello',
    });
  });

  test('rejects unsupported command type', () {
    expect(
      () => CommandConfig.fromJson({
        'type': 'bash',
        'command': 'date',
        'description': 'Unsupported',
      }),
      throwsFormatException,
    );
  });
}
