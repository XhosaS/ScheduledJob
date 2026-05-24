# AGENTS.md

本文件约束后续自动化代理和开发者在本仓库中的实现方式。

## 架构要求

- 修改方案必须遵循 MVVM。
- View 只负责 UI 展示、输入控件和事件转发，不直接访问数据库、不直接执行命令。
- ViewModel 负责页面状态、输入校验、业务流程编排和通知 UI 刷新。
- Repository 负责数据访问抽象，View 和 Widget 不应依赖 SQLite 细节。
- Database 只处理 SQLite schema、迁移和底层 CRUD。
- 后台任务调度和命令执行应放在 application/service 层，不应塞进 Widget。

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
