// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Scheduled Job';

  @override
  String get newScheduledJobButton => 'New Scheduled Job';

  @override
  String get newScheduledJobTitle => 'New Scheduled Job';

  @override
  String get afterMinutes => 'After minutes';

  @override
  String get atTime => 'At time';

  @override
  String get minutesFromNow => 'Minutes from now';

  @override
  String get selectDateAndTime => 'Select date and time';

  @override
  String get description => 'Description';

  @override
  String get command => 'Command';

  @override
  String get recommendedCommands => 'Recommended commands';

  @override
  String get commandRequired => 'Command is required';

  @override
  String get commandEnvironmentFailed =>
      'Failed to prepare the command environment';

  @override
  String get terminal => 'Terminal';

  @override
  String get showTerminal => 'Show terminal';

  @override
  String get hideTerminal => 'Hide terminal';

  @override
  String get terminalCommand => 'Terminal command';

  @override
  String get sendTerminalCommand => 'Send command';

  @override
  String get clearTerminal => 'Clear terminal';

  @override
  String get noTerminalOutput => 'No terminal output';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get positiveMinutesRequired => 'Enter a positive number of minutes';

  @override
  String get dateTimeRequired => 'Select a date and time';

  @override
  String get dailyBackup => 'Daily backup';

  @override
  String get dataCleanup => 'Data cleanup';

  @override
  String get reportExport => 'Report export';

  @override
  String get healthCheck => 'Health check';

  @override
  String get notificationSync => 'Notification sync';

  @override
  String afterMinutesLabel(int minutes) {
    return 'After $minutes minutes';
  }
}
