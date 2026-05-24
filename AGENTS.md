# AGENTS.md

本文件约束后续自动化代理和开发者在本仓库中的实现方式。

## 架构要求

- 修改方案必须遵循 MVVM。
- View 只负责 UI 展示、输入控件和事件转发，不直接访问数据库、不直接执行命令。
- ViewModel 负责页面状态、输入校验、业务流程编排和通知 UI 刷新。
- Repository 负责数据访问抽象，View 和 Widget 不应依赖 SQLite 细节。
- Database 只处理 SQLite schema、迁移和底层 CRUD。
- 后台任务调度和命令执行应放在 application/service 层，不应塞进 Widget。
- 后台任务到期调度和命令执行必须分离：Scheduler 只负责到期和队列同步，实际命令执行应通过终端/命令执行 service。
- 右侧命令行是长期 PowerShell 会话；Widget 只能展示输出、输入控件和事件转发，不得直接启动进程或写 stdin。
- Python 运行时路径、共享 venv 路径、requirements 路径解析应集中在 application/service 层，不应散落在 View、ViewModel 或 Repository。
- Repository 只保存任务数据和命令配置路径，不应创建 venv、不应执行 pip、不应执行任务命令。

## 命令配置与 Python 环境要求

- 每个任务必须保留独立命令配置文件夹，结构为 `jobs/<job-id>/command.json` 和 `jobs/<job-id>/libs/requirements.txt`。
- Python 任务执行时可生成 `jobs/<job-id>/run.py`，但不得把 venv 放在任务目录下。
- 所有 Python 任务共用同一个 venv：`<commands-workspace>/python_venv/`。
- `<commands-workspace>` 当前由 `databaseFactoryFfi.getDatabasesPath()` 下的 `commands` 目录确定；修改路径策略时必须同步 README。
- `libs/requirements.txt` 是该任务的依赖声明，安装目标是共享 `python_venv`。
- 删除任务时只删除该任务的 `jobs/<job-id>/` 配置目录，不得删除共享 `python_venv`。
- 推荐命令模板应放在 `assets/commands/templates/<locale>/<slug>/`，并通过 `CommandConfigRepository` 读取。
- Windows 内置 Python 运行时位于 `third_party/python/windows-x64/`，构建时复制到发布目录的 `runtime/python/`。
- Debug 运行和 Release 运行的 Python 路径行为必须保持一致或有明确 fallback；修改后必须验证 `python.exe`、`pip`、`venv` 可用。

## 本地化要求

- 不得把用户可见文本直接写在 Dart UI 代码中。
- 新增或修改用户可见文本时，必须同步更新 `lib/l10n/app_en.arb` 和 `lib/l10n/app_zh.arb`。
- UI 中必须通过 `context.l10n` 或生成的 `AppLocalizations` 访问本地化文本。
- 更新 ARB 后必须运行 `flutter gen-l10n`，并提交生成后的 `lib/l10n/generated/` 变更。
- 测试中如需断言本地化文本，应优先使用生成的 localization getter，而不是复制硬编码字符串。

## 验证要求

- 修改 Dart 代码后运行 `dart format lib test`。
- 功能或架构变更后运行 `flutter analyze` 和 `flutter test`。
- 数据模型或迁移变更必须补 Repository/Database 测试。
- ViewModel 行为变更必须补 ViewModel 测试。
- UI 交互变更必须补 Widget 测试。
