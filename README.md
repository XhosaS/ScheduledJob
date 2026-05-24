# Scheduled Job

一个 Flutter 桌面计划任务示例项目。当前项目重点是把 UI、页面状态、业务逻辑和 SQLite 持久化拆开，方便后续维护和编写测试。

## 架构概览

项目采用轻量 MVVM 风格：

- **View**：只负责界面展示和用户交互，把事件转发给 ViewModel。
- **ViewModel**：保存页面状态、执行表单校验、调用 Repository，并通过 `ChangeNotifier` 通知 UI 刷新。
- **Repository**：定义业务数据读写接口，屏蔽底层 SQLite 实现。
- **Database**：负责 SQLite 初始化、建表、查询和插入。

状态管理使用 `provider` + `ChangeNotifier`。SQLite 使用 `sqflite_common_ffi`，当前按 Windows 桌面项目配置。

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

- `lib/main.dart`：应用入口，初始化 Flutter、SQLite FFI、创建数据库和 Repository，然后启动 `MyApp`。
- `lib/app.dart`：配置 `MaterialApp`、主题、本地化，并通过 `ChangeNotifierProvider` 注入 `ScheduledJobsViewModel`。
- `lib/features/scheduled_jobs/domain/scheduled_job.dart`：任务实体，只包含 `id`、`scheduledAt`、`description`。
- `lib/features/scheduled_jobs/data/scheduled_job_database.dart`：SQLite 表结构和底层读写。
- `lib/features/scheduled_jobs/data/scheduled_job_repository.dart`：业务数据接口，UI 和 ViewModel 只依赖这个抽象。
- `lib/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart`：页面状态和业务流程，例如加载任务、进入新建状态、校验输入、保存任务。
- `lib/features/scheduled_jobs/presentation/scheduled_jobs_page.dart`：页面骨架，组合左侧列表和右侧表单。
- `lib/features/scheduled_jobs/presentation/widgets/`：纯 UI 组件。

## 数据流

启动时：

```text
main.dart
  -> ScheduledJobDatabase
  -> SqliteScheduledJobRepository
  -> MyApp
  -> ScheduledJobsViewModel.loadJobs()
  -> UI 展示 SQLite 中的真实任务列表
```

新增任务时：

```text
用户填写表单
  -> NewScheduledJobForm 调用 ViewModel.saveJob()
  -> ViewModel 校验描述、分钟数或指定时间
  -> Repository.addJob()
  -> SQLite 插入 scheduled_jobs
  -> Repository.fetchJobs()
  -> ViewModel notifyListeners()
  -> UI 自动刷新列表
```

## SQLite 数据模型

当前只有一张表：

```sql
CREATE TABLE scheduled_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scheduled_at INTEGER NOT NULL,
  description TEXT NOT NULL
);
```

字段含义：

- `id`：任务主键。
- `scheduled_at`：计划执行时间，保存为 `DateTime.millisecondsSinceEpoch`。
- `description`：任务描述。

列表展示的数据全部来自 SQLite，不再使用假数据。

## 测试

测试分三层：

- `test/widget_test.dart`：验证页面布局、空列表、新建任务和表单校验。
- `test/scheduled_job_repository_test.dart`：验证 SQLite 建表、插入、查询和排序。
- `test/scheduled_jobs_view_model_test.dart`：验证 ViewModel 的加载、校验、保存和状态刷新。

运行：

```bash
flutter analyze
flutter test
```

## 后续扩展建议

- 如果要支持 Android/iOS，可以在数据库初始化层扩展不同平台的 SQLite factory。
- 如果业务复杂度继续上升，可以继续保留 Repository 接口，并把调度执行、任务状态、删除/编辑等逻辑拆到独立 service。
- 当前中文本地化文件存在乱码，后续可以单独修复 `lib/l10n/app_zh.arb` 并重新生成本地化代码。
