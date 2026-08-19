# Flutter 开发规范

> 文档基线：2026-08-19。适用于 BLExpert 的 Dart、Flutter UI、平台适配与测试代码。

## 目标

本规范用于保持 BLExpert 的模块边界清晰、跨平台行为可验证，并避免入口文件、页面状态和第三方 UI API 再次集中到单个大文件中。

开发时遵循以下优先级：

1. 不改变已验证的 BLE、协议和安全发送行为。
2. 依赖方向清晰，平台能力与界面分离。
3. 组件职责单一，可在窄屏、桌面和明暗主题下复用。
4. 变更可通过静态分析、单元测试和 Widget 测试验证。

## 目录职责

```text
lib/
├── main.dart                  # 仅负责应用启动和导出应用根
├── app/
│   ├── blexpert_app.dart      # MaterialApp、主题、语言和全局宿主
│   ├── app_theme.dart         # 主题令牌
│   └── design/                # 项目拥有的第三方 UI 适配层
├── features/
│   ├── home/                  # 主工作台状态协调和应用栏
│   ├── configuration/         # 工作区、协议、命令和映射配置
│   ├── debug/                 # 控制台、日志和 Inspector
│   ├── device/                # GATT、快捷命令和监控数据
│   └── records/               # 会话记录
├── models/                    # 稳定领域模型和 JSON 契约
├── services/                  # BLE、协议、脚本、持久化及平台适配
├── utils/                     # 无状态、无界面的通用函数
├── widgets/                   # 跨 feature 的应用骨架或通用组合组件
└── l10n/                      # 国际化资源和生成代码
```

新增代码必须放入职责最接近的目录。不要以“临时方便”为由将业务逻辑放回 `main.dart`，也不要在 `utils/` 中堆放带状态或依赖具体 feature 的代码。

## 依赖方向

推荐依赖方向如下：

```text
main -> app -> features -> services/models
                    └──> app/design
services -> models/utils
```

- `main.dart` 只创建应用根，不声明页面、服务或业务状态。
- `models/` 不依赖 Widget、BuildContext 或具体蓝牙插件。
- `services/` 不展示 Dialog、SnackBar 或其他界面反馈；错误通过结果、异常或事件交给调用方处理。
- feature 通过 `BluetoothService` 等项目抽象访问平台能力，不直接调用具体 BLE 插件。
- 平台差异使用条件导入/导出和 `*_io.dart`、`*_web.dart`、`*_stub.dart` 适配文件隔离。
- `app/design/` 是业务界面接入 `shadcn_flutter` 的稳定边界。能由 `ToolButton`、`ToolTextField`、`ToolSelect`、`ToolToggle` 或 `showToolDialog` 表达的控件，不直接依赖第三方 API。

## Dart Library 与文件边界

- 默认使用普通 `import` 暴露 feature 的公共入口。
- 只有一组实现需要共享私有类型、且共同构成同一个 feature library 时才使用 `part`。
- `part` 的拥有者必须是明确的 feature 入口，例如 `home_screen.dart`；禁止再次让 `main.dart` 成为全项目 `part` 宿主。
- `part` 文件不声明独立公共 API，不被其他 library 单独导入。
- 一个文件应有一个明确的主要职责。新增独立 Panel、Editor、Toolbar、Dialog 或复杂 Tile 时创建单独文件。
- 单个 `build` 方法超过约 150 行，或 Widget 文件超过约 600 行时，应检查是否可以按视觉区域、交互状态或复用边界拆分。这是评审触发线，不是机械拆分指标。
- `HomeScreen` 当前承担存量状态协调。不要继续向其中加入大段内联编辑器或弹窗；新增流程优先抽为独立组件或控制器，再由回调传递结果。

## Widget 与组件规范

- 优先使用组合而不是继承；无内部状态的组件使用 `StatelessWidget`。
- 可为常量的构造函数和子树使用 `const`。
- Widget 通过明确的只读参数和回调交换数据，不直接修改父级状态。
- 页面负责布局和流程编排，Panel 负责一个功能区域，Editor 负责编辑模型，Tile/Row 负责单条数据展示。
- 业务组件不保存可由模型或父组件推导出的重复状态。
- `TextEditingController`、`FocusNode`、`ScrollController`、订阅和计时器必须由创建它们的 State 在 `dispose` 中释放。
- 异步操作返回后访问 `context` 或调用 `setState` 前检查 `mounted`；连接、保存和发送期间要防止重复提交。
- 列表使用稳定业务 ID 作为 Key。测试 Key 用于稳定的用户行为入口，不绑定临时布局层级。

## 命名规范

- 文件和目录使用 `snake_case`，类型使用 `UpperCamelCase`，字段和方法使用 `lowerCamelCase`。
- 页面级工作区使用 `*Workspace`，独立功能区域使用 `*Panel`，编辑组件使用 `*Editor`，列表项使用 `*Tile`，工具栏使用 `*Toolbar`。
- 服务抽象使用能力名称，例如 `BluetoothService`；平台实现使用平台后缀，不在调用方判断插件类型。
- 布尔值使用 `is`、`has`、`can`、`should` 等可读前缀。
- 避免 `common.dart`、`helpers.dart`、`misc.dart` 等无法表达职责的文件名。

## 响应式与可访问性

- 根据父约束选择布局时使用 `LayoutBuilder`，不要只依赖全局屏幕宽度或固定设备型号。
- 至少覆盖 375px 窄屏和 1440px 桌面宽度；固定工具栏、列表和底部导航必须考虑 SafeArea。
- 文本允许系统缩放，长 UUID、HEX、设备名和本地化文案必须使用换行、`Flexible` 或省略策略避免溢出。
- 图标按钮必须有 Tooltip 或等价语义标签；状态不能只依赖颜色表达。
- 移动端主要点击区域不小于 44x44，密集桌面控件也要保留清晰的焦点、禁用态和点击反馈。
- 所有用户可见文案进入 ARB 国际化资源；协议原文、HEX、UUID 和脚本内容除外。
- 明暗主题颜色从 `ThemeData`/`ColorScheme` 获取，组件中不新增仅适配单一主题的颜色常量。

## 模型、服务与错误处理

- 持久化和导入导出的模型变更必须明确 JSON 版本、默认值和迁移策略。
- 原始 BLE 收发日志不得因协议解析、脚本或映射失败而丢失。
- 所有真实设备写入继续经过统一的编码、脚本、安全策略和最终帧校验链路；UI 不得绕过服务层直接写入。
- 捕获异常时要保留可诊断上下文，但日志中不得输出密钥或不必要的设备隐私数据。
- 流和队列必须有容量、取消和异常处理策略，避免无限增长或在页面销毁后继续更新状态。

## 测试与提交门槛

提交前至少执行：

```bash
dart format lib test
flutter analyze
flutter test
git diff --check
```

- 模型、编码、解析和安全策略变更添加单元测试。
- 用户可见流程、响应式边界和第三方组件适配添加 Widget 测试。
- 修复缺陷时优先增加能复现问题的回归测试。
- 不以删除断言、扩大等待时间或跳过测试来掩盖不稳定行为。
- 依赖原生运行时而无法在当前环境执行的测试必须明确说明跳过条件。

提交信息沿用仓库现有风格：`type: 简短说明`，常用类型包括 `feat`、`fix`、`refactor`、`docs`、`test` 和 `chore`。一次提交只包含同一目标下的代码、测试和文档变更。

## 评审清单

- [ ] `main.dart` 仍只承担启动职责。
- [ ] 新文件位于正确的 feature 或基础层。
- [ ] 没有新增反向依赖、跨层平台调用或绕过设计适配层。
- [ ] 大型 Widget 已检查可拆分边界，控制器和订阅均正确释放。
- [ ] 窄屏、桌面、明暗主题和本地化文本无溢出或遮挡。
- [ ] BLE 原始日志、安全发送链路和导入信任边界未被绕过。
- [ ] 格式化、静态分析、测试和差异检查通过。
