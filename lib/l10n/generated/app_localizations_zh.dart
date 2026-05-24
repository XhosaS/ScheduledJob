// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '计划任务';

  @override
  String get newScheduledJobButton => '新建计划任务';

  @override
  String get newScheduledJobTitle => '新建计划任务';

  @override
  String get afterMinutes => '分钟后';

  @override
  String get atTime => '指定时间';

  @override
  String get minutesFromNow => '从现在起的分钟数';

  @override
  String get selectDateAndTime => '选择日期和时间';

  @override
  String get description => '描述';

  @override
  String get command => '命令';

  @override
  String get recommendedCommands => '推荐命令';

  @override
  String get commandRequired => '请输入命令';

  @override
  String get commandEnvironmentFailed => '命令运行环境准备失败';

  @override
  String get terminal => '命令行';

  @override
  String get showTerminal => '显示命令行';

  @override
  String get hideTerminal => '隐藏命令行';

  @override
  String get terminalCommand => '命令行命令';

  @override
  String get sendTerminalCommand => '发送命令';

  @override
  String get clearTerminal => '清空命令行';

  @override
  String get noTerminalOutput => '暂无命令行输出';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get descriptionRequired => '请输入描述';

  @override
  String get positiveMinutesRequired => '请输入大于 0 的分钟数';

  @override
  String get dateTimeRequired => '请选择日期和时间';

  @override
  String get dailyBackup => '每日备份';

  @override
  String get dataCleanup => '数据清理';

  @override
  String get reportExport => '报表导出';

  @override
  String get healthCheck => '健康检查';

  @override
  String get notificationSync => '通知同步';

  @override
  String afterMinutesLabel(int minutes) {
    return '$minutes 分钟后';
  }
}
