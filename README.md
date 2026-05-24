# Scheduled Job

一个 Flutter Windows 桌面计划任务应用，用于创建一次性任务，并在应用运行期间按计划执行 PowerShell 或 Python 命令。

## 当前功能

- 创建和编辑计划任务。
- 支持两种时间方式：
  - `分钟后`：从当前时间开始延迟指定分钟数执行。
  - `指定时间`：只选择时、分、秒，保存时自动计算下一次到达该时刻的日期。
- 支持 PowerShell 和 Python 命令。
- 任务列表提供 `Switch` 开关：
  - 新建任务默认关闭。
  - 打开后加入后台调度。
  - 执行完成或执行失败后自动关闭，只执行一次。
- 后台调度使用 Dart Isolate，应用关闭后不会继续执行任务。
- 任务列表支持右键或长按弹出菜单删除任务和数据库记录。
- 表单提供推荐命令气泡，当前包含一个 PowerShell 关机命令模板。
- 支持英文和简体中文本地化。

## 架构概览

项目采用轻量 MVVM：

- **View**：Flutter 页面和 Widget，只负责展示、输入和事件转发。
- **ViewModel**：保存页面状态，执行业务校验，协调 Repository 和调度服务，并通过 `ChangeNotifier` 通知 UI。
- **Repository**：定义业务数据读写接口，屏蔽 SQLite 实现细节。
- **Database**：负责 SQLite 建表、迁移、查询、插入、更新和删除。
- **Scheduler Service**：负责后台调度和命令执行，当前实现为 Dart Isolate。

状态管理使用 `provider` + `ChangeNotifier`。SQLite 使用 `sqflite_common_ffi`。

## 目录结构

```text
lib/
  main.dart
  app.dart
  core/
    l10n/
      app_localizations_context.dart
  features/
    scheduled_jobs/
      application/
        scheduled_job_scheduler.dart
      domain/
        scheduled_job.dart
      data/
        scheduled_job_database.dart
        scheduled_job_repository.dart
      presentation/
        scheduled_jobs_page.dart
        scheduled_jobs_view_model.dart
        widgets/
          job_list_pane.dart
          new_scheduled_job_form.dart
  l10n/
    app_en.arb
    app_zh.arb
    generated/
```

## 关键文件职责

- `lib/main.dart`：应用入口，初始化 Flutter、SQLite FFI、Database 和 Repository。
- `lib/app.dart`：配置 `MaterialApp`、主题、本地化和 `ScheduledJobsViewModel` 注入。
- `lib/features/scheduled_jobs/domain/scheduled_job.dart`：任务实体和运行模式。
- `lib/features/scheduled_jobs/data/scheduled_job_database.dart`：SQLite schema、迁移和底层读写。
- `lib/features/scheduled_jobs/data/scheduled_job_repository.dart`：任务数据访问抽象。
- `lib/features/scheduled_jobs/application/scheduled_job_scheduler.dart`：Isolate 调度器，负责执行 PowerShell/Python 命令。
- `lib/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart`：页面状态、表单校验、启停、删除和调度同步。
- `lib/features/scheduled_jobs/presentation/widgets/`：纯 UI 组件。

## 数据流

启动时：

```text
main.dart
  -> ScheduledJobDatabase
  -> SqliteScheduledJobRepository
  -> MyApp
  -> ScheduledJobsViewModel.loadJobs()
  -> Scheduler 同步已启用任务
  -> UI 展示 SQLite 中的任务列表
```

保存任务时：

```text
用户填写表单
  -> NewScheduledJobForm 调用 ViewModel.saveJob()
  -> ViewModel 校验输入并计算 scheduledAt
  -> Repository add/update
  -> SQLite 写入
  -> ViewModel 刷新任务列表并同步 Scheduler
```

打开任务开关时：

```text
用户打开 Switch
  -> ViewModel 重新计算下一次 scheduledAt
  -> Repository 持久化 is_enabled 和 scheduled_at
  -> Scheduler upsert 任务
  -> 到点后 Isolate 执行命令
  -> Scheduler 发回完成事件
  -> ViewModel 将任务关闭并刷新 UI
```

## SQLite 数据模型

当前表为 `scheduled_jobs`：

```sql
CREATE TABLE scheduled_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scheduled_at INTEGER NOT NULL,
  description TEXT NOT NULL,
  run_mode TEXT NOT NULL,
  command TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 0
);
```

字段含义：

- `id`：任务主键。
- `scheduled_at`：下一次计划执行时间，保存为 `DateTime.millisecondsSinceEpoch`。
- `description`：任务描述。
- `run_mode`：命令运行方式，当前支持 `powershell` 和 `python`。
- `command`：要执行的命令文本。
- `is_enabled`：任务是否已加入调度队列。

## 命令执行

任务到期后，Isolate 会按运行模式执行：

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command <command>
python -c <command>
```

执行失败也会消耗本次任务，并把开关自动关闭。当前版本不展示执行日志。

## 本地化

用户可见文本应放在 `lib/l10n/app_en.arb` 和 `lib/l10n/app_zh.arb` 中，并通过 `context.l10n` 使用。更新 ARB 后运行：

```bash
flutter gen-l10n
```

## 测试

测试分三层：

- `test/widget_test.dart`：验证页面布局、表单交互、推荐命令、开关和删除菜单。
- `test/scheduled_job_repository_test.dart`：验证 SQLite 建表、迁移、增删改查和排序。
- `test/scheduled_jobs_view_model_test.dart`：验证 ViewModel 校验、保存、启停、执行完成回调和删除逻辑。

运行：

```bash
flutter analyze
flutter test
```
