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
- 后台调度只在应用运行期间生效，应用关闭后不会继续执行任务。
- 右侧提供默认折叠的交互命令行面板，用于展示后台任务和用户命令的输出。
- 任务列表支持右键或长按弹出菜单删除任务和数据库记录。
- 表单提供推荐命令气泡，推荐命令通过命令配置文件夹加载，当前包含一个 PowerShell 关机命令模板。
- Windows 发布包内置 Python 运行时，Python 任务使用共享 venv 执行。
- 支持英文和简体中文本地化。

## 架构概览

项目采用轻量 MVVM：

- **View**：Flutter 页面和 Widget，只负责展示、输入和事件转发。
- **ViewModel**：保存页面状态，执行业务校验，协调 Repository 和调度服务，并通过 `ChangeNotifier` 通知 UI。
- **Repository**：定义业务数据读写接口，屏蔽 SQLite 实现细节。
- **Database**：负责 SQLite 建表、迁移、查询、插入、更新和删除。
- **Scheduler Service**：负责后台任务到期调度。
- **Terminal Service**：负责长期 PowerShell 会话、命令队列、后台任务执行和输出事件。
- **Command Config Service**：负责推荐命令模板和每个任务的命令配置文件夹。

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
        background_command_terminal_service.dart
        command_environment_service.dart
        scheduled_job_scheduler.dart
      domain/
        command_config.dart
        scheduled_job.dart
      data/
        command_config_repository.dart
        scheduled_job_database.dart
        scheduled_job_repository.dart
      presentation/
        scheduled_jobs_page.dart
        scheduled_jobs_view_model.dart
        widgets/
          job_list_pane.dart
          new_scheduled_job_form.dart
          terminal_pane.dart
  l10n/
    app_en.arb
    app_zh.arb
    generated/
assets/
  commands/
    templates/
third_party/
  python/
    windows-x64/
```

## 关键文件职责

- `lib/main.dart`：应用入口，初始化 Flutter、SQLite FFI、Database、Repository、命令配置服务、终端服务和调度器。
- `lib/app.dart`：配置 `MaterialApp`、主题、本地化和 `ScheduledJobsViewModel` 注入。
- `lib/features/scheduled_jobs/domain/scheduled_job.dart`：任务实体和运行模式。
- `lib/features/scheduled_jobs/domain/command_config.dart`：命令配置 JSON 模型。
- `lib/features/scheduled_jobs/data/scheduled_job_database.dart`：SQLite schema、迁移和底层读写。
- `lib/features/scheduled_jobs/data/scheduled_job_repository.dart`：任务数据访问抽象。
- `lib/features/scheduled_jobs/data/command_config_repository.dart`：读取推荐命令模板，创建和删除任务命令配置文件夹。
- `lib/features/scheduled_jobs/application/scheduled_job_scheduler.dart`：任务到期调度器，到期后把任务交给终端服务执行。
- `lib/features/scheduled_jobs/application/background_command_terminal_service.dart`：长期 PowerShell 会话、串行命令队列和命令行输出事件。
- `lib/features/scheduled_jobs/application/command_environment_service.dart`：内置 Python 路径、共享 venv 路径和 requirements 路径解析。
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
  -> Terminal Service 启动长期 PowerShell 并准备共享 Python venv
  -> UI 展示 SQLite 中的任务列表
```

保存任务时：

```text
用户填写表单
  -> NewScheduledJobForm 调用 ViewModel.saveJob()
  -> ViewModel 校验输入并计算 scheduledAt
  -> CommandConfigRepository 写入任务命令配置文件夹
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
  -> 到点后 Scheduler 将任务放入 Terminal Service 串行队列
  -> Terminal Service 在长期 PowerShell 会话中执行命令并推送 stdout/stderr
  -> Scheduler 发回完成事件
  -> ViewModel 将任务关闭并刷新 UI
```

用户在右侧命令行输入命令时：

```text
用户输入命令
  -> TerminalPane 调用 ViewModel.submitTerminalCommand()
  -> ViewModel 校验非空
  -> Terminal Service 将命令加入同一个长期 PowerShell 队列
  -> UI 显示命令输出和错误输出
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
  command_config_path TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 0
);
```

字段含义：

- `id`：任务主键。
- `scheduled_at`：下一次计划执行时间，保存为 `DateTime.millisecondsSinceEpoch`。
- `description`：任务描述。
- `run_mode`：命令运行方式，当前支持 `powershell` 和 `python`。
- `command`：要执行的命令文本。
- `command_config_path`：任务命令配置文件相对路径，例如 `jobs/5/command.json`。
- `is_enabled`：任务是否已加入调度队列。

## 命令配置、venv 和 libs 目录

命令配置从单个字段扩展为命令文件夹。每个任务都有独立配置目录：

```text
<commands-workspace>/
  jobs/
    <job-id>/
      command.json
      run.py                  # Python 任务执行时生成
      libs/
        requirements.txt
  python_venv/                # 所有 Python 任务共享的 venv
```

当前 `<commands-workspace>` 位于 SQLite 数据库目录下的 `commands` 子目录。Windows 桌面运行时通常在 `sqflite_common_ffi` 返回的数据库目录中，例如：

```text
<database-dir>/commands
```

代码中由 `main.dart` 通过以下方式计算：

```dart
path.join(await databaseFactoryFfi.getDatabasesPath(), 'commands')
```

目录职责：

- `jobs/<job-id>/command.json`：保存该任务的 `type`、`command`、`description`。
- `jobs/<job-id>/libs/requirements.txt`：该任务声明的 Python 依赖清单。
- `jobs/<job-id>/run.py`：Python 任务执行前由终端服务生成，内容来自任务命令文本。
- `python_venv/`：所有 Python 任务共享的 venv，不属于任何单个任务。

推荐命令模板位于仓库内置资源：

```text
assets/commands/templates/<locale>/<slug>/
  command.json
  libs/
    requirements.txt
```

内置 Python 运行时位于：

```text
third_party/python/windows-x64/
```

Windows 构建时会复制到发布目录：

```text
build/windows/x64/runner/Release/runtime/python/
```

## 命令执行

命令执行统一经过右侧长期 PowerShell 会话：

- PowerShell 任务：直接把任务命令放入终端队列执行。
- Python 任务：把任务命令写入 `jobs/<job-id>/run.py`，先按需执行 `python_venv/Scripts/python.exe -m pip install -r jobs/<job-id>/libs/requirements.txt`，再执行 `python_venv/Scripts/python.exe jobs/<job-id>/run.py`。
- 用户在右侧命令行输入的命令也进入同一个 PowerShell 队列。

执行失败也会消耗本次任务，并把开关自动关闭。stdout/stderr 和非 0 exit code 会显示在右侧命令行面板中。

注意：任务类型为 `Python` 时，命令内容应是 Python 代码，例如：

```python
import sys
print(sys.version)
```

如果要执行 shell 命令，例如 `python --version`，任务类型应选择 `PowerShell`。

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
- `test/scheduled_job_scheduler_test.dart`：验证调度器将到期任务交给终端队列并发送完成事件。
- `test/command_config_test.dart` 和 `test/command_config_repository_test.dart`：验证命令配置 JSON、推荐命令模板和任务命令文件夹。

运行：

```bash
dart format lib test
flutter gen-l10n
flutter analyze
flutter test
```
