# BLExpert

> 文档基线：2026-08-21。开发状态和优先级以 [开发路线图](docs/开发路线图.md) 为准。

BLExpert 是一款基于 Flutter 的跨平台 BLE 协议调试与分析工具。它面向嵌入式、IoT、测试和现场支持工程师，将设备连接、原始收发、协议配置、参数化指令和响应字段映射组织为可复用的工作区。

> 当前版本可用于 BLE 基础调试、标准协议封包/解帧、会话记录导出和工作区配置验证；脚本可终止隔离与多平台发布回归仍在开发中，详见“当前边界”。

## 当前能力

### 调试工作台

- 三种工作模式：`调试`、`配置`、`记录`。
- 桌面端使用模式导航、设备与特征区、通信控制台和可收起 Inspector；窄屏端使用底部导航。
- 支持亮色、暗色和跟随系统主题，以及中文、英文和跟随系统语言。
- 通信控制台记录带时间戳的发送、接收、系统和错误事件，支持方向/关键字/HEX 筛选、自动滚动、回到最新、保留/丢弃计数、日志导出和清空。
- 手动 HEX 输入会过滤非法字符、自动转为大写并按字节分组；发送区固定展示目标、业务载荷字节数、最终帧预览和不可发送原因，避免预览变化导致输入框跳动。
- 选中日志会在 Inspector 中展示完整帧和事务上下文，Inspector 可关闭以恢复控制台空间。
- UI 已全面迁移到 `shadcn_flutter`：应用根、页面骨架、桌面/窄屏导航、Tabs、Tooltip、Toast、对话框、输入与选择控件、点击表面、SelectableText、Scrollbar 和 Lucide 图标均通过 shadcn 组件或本地适配层实现；应用层 Material UI 例外为零。

### BLE Central

- 基于 `universal_ble` 实现扫描、连接、断开、服务/特征发现。
- 支持 Read、Write、Write without response、Notify 和 Indicate。
- 可手动选择写入目标特征和通知/指示订阅特征。
- 保留 Mock 蓝牙服务：`flutter run --dart-define=USE_MOCK_BLUETOOTH=true`。
- 覆盖 Android、iOS、Windows、macOS、Linux 和 Web 的 BLE 调试路径，实际平台能力受系统蓝牙栈和浏览器限制。

### 工作区与协议配置

- 工作区保存元信息、协议段、脚本配置、指令、响应映射和最近活动工作区。
- 使用 `shared_preferences` 保存工作区列表和当前工作区；支持导出当前工作区或全部工作区、完整工作区 JSON 导入与旧字段兼容读取。
- 协议编辑支持发送/接收片段：固定 HEX、业务载荷、长度、序号和校验。
- 标准协议已接入发送和接收链路：自动生成长度、序号和 XOR/SUM8/CRC8/CRC16/CRC32 校验，并支持拆包、粘包、多帧和校验失败后的恢复。
- 标准解帧后的业务载荷会进入 `CMD/DATA` 响应映射；原始通知始终保留在控制台。

### 指令与数据映射

- 指令支持 HEX 或文本业务载荷、启用状态和快捷入口。
- HEX 指令支持 `{{key}}` 参数占位符：整数、HEX、ASCII、UTF-8、布尔、枚举及当前日期/时间字节；年月日时分秒参数未填写时，发送时自动取当前时间。
- 响应映射按 `CMD` 匹配，字段偏移相对解码后的 `DATA`；支持数值、HEX、ASCII、UTF-8、布尔、枚举、位域、字节序、比例、数值偏移和单位。
- Inspector 会展示最近一次成功映射的字段值和已启用的快捷指令；收到新帧导致字段值变化时，映射字段会保持高亮，清空数据后恢复普通状态。

### JavaScript 协议脚本

- 原生平台通过 `flutter_js` 支持 `beforeSend(context)` 和 `afterReceive(context)`。
- 提供 HEX、校验和、CRC、MD5 等 JavaScript 内置工具函数。
- Web 端保留脚本配置，但不执行 JavaScript 脚本。
- 导入工作区的脚本会被强制禁用并标记为未信任；首次启用需要显式确认来源与风险。
- 脚本源码、输入/输出帧和日志已有大小上限；Android/Windows/Linux 的 QuickJS 已启用 50ms/16MiB 硬限制，脚本写入按 200ms 限流。脚本改写最终帧前是否确认可在脚本协议配置中单独控制，但改写帧、高风险关键词命令和指令级强制确认仍会要求确认。工作区命令白名单和设备发送策略已接入真实发送路径；Apple JavaScriptCore 的可终止超时及完整目标平台审计仍未完成。

## 当前边界与已知限制

- 产品范围仅包含 BLE Central；不计划支持经典蓝牙 SPP。
- 标准协议当前覆盖常见固定帧、长度字段、序号和校验规则；复杂状态机、转义、加密和非常规长度语义需要脚本或后续扩展。
- 工作区按设备保存服务 UUID、默认写入/订阅特征及 Web 服务 UUID；连接后会尝试恢复，并对失效配置给出日志提示。
- 工作区导入已支持 v1 -> v2 迁移预览、完整替换或按工作区 ID 合并，以及冲突时覆盖/保留当前；字段级合并仍未实现。
- 会话记录已支持最近 300 条持久化恢复、方向/特征/指令/文本/HEX/书签筛选、事务关联和当前筛选结果 JSON 导出；会话命名、脱敏导出和更精细的主动上报归因仍在后续规划中。
- 尚未完成 Android、iOS、Windows、macOS、Linux、Web 的多平台真机回归和发布准备。

## 运行项目

环境要求：Flutter SDK（Dart `^3.12.1`）。

```bash
flutter pub get
flutter run
```

开发验证：

```bash
flutter analyze
flutter test
```

### 版本与构建

当前应用版本为 `1.0.0+1`，设置页会显示该版本号。发布构建可通过 `--dart-define=APP_VERSION=<version>` 覆盖设置页展示值；平台安装包的版本名和构建号仍可分别通过 Flutter 的 `--build-name` 与 `--build-number` 覆盖。

当前仓库测试覆盖工作区/指令/协议 JSON 兼容、参数化载荷编码、响应字段映射、Web 服务 UUID 解析和核心 Widget 工作流；UI 回归另覆盖亮暗主题对比度、选中/禁用/焦点语义、Switch 动效，以及 375px/1440px 完整页面 Golden。`flutter analyze` 当前通过；375px 记录页的亮暗 Golden 存在待定位的 2.94% 基线差异，详见 [开发路线图](docs/开发路线图.md)。

## 项目结构

`main.dart` 只负责启动并导出应用根。应用装配位于 `lib/app/`；工作台、配置、调试、设备和记录界面按业务职责位于 `lib/features/`；领域模型、平台无关服务、通用函数和国际化资源分别位于 `lib/models/`、`lib/services/`、`lib/utils/` 和 `lib/l10n/`。

Home 工作台是当前的 feature library 宿主，紧密共享私有状态的内部组件通过 `part` 组织；其他模块默认使用普通 `import`。新增代码不得将 `main.dart` 恢复为页面或业务逻辑容器。完整目录职责、组件粒度、依赖方向和提交门槛见 [Flutter 开发规范](docs/Flutter开发规范.md)。

## Web Bluetooth 调试

Web Bluetooth 需要 Chrome 或 Chromium，并受浏览器安全模型约束。Linux 等平台通常还要启用实验性 Web 平台功能：

```bash
flutter run -d chrome \
  --web-browser-flag=--enable-experimental-web-platform-features
```

使用前请注意：

- 本地 `flutter run` 地址可使用；部署环境必须使用 HTTPS。
- 在 Chrome 中启用 `chrome://flags/#enable-experimental-web-platform-features` 后重启浏览器。
- 设备选择前必须配置需要访问的服务 UUID。应用支持 16 位、32 位和 128 位服务 UUID，并会标准化处理。
- 未通过 Web Bluetooth `optionalServices` 声明的服务和特征不会暴露给网页；修改 UUID 后需重新扫描并重新选择设备。
- Web 端不运行 JavaScript 协议脚本，但原始 BLE 调试仍可使用。

## Linux / BlueZ 说明

- 连接未配对设备时，应用会通过系统能力尝试设置临时信任；请确保已安装 `bluez`，且当前用户可访问 Bluetooth D-Bus 服务。
- 连接前会停止扫描，降低 BlueZ 扫描与 GATT 连接的竞态风险。
- Linux 仅展示 BlueZ 在当前 GATT 会话中真实暴露且可安全操作的服务和特征；不会合成特征或用广播名称替代读取值。

## 文档

文档入口按职责分工，当前开发状态和下一步只查看“开发路线图”。

- [产品说明](docs/产品说明.md)：产品定位、范围、用户、领域模型和技术边界。
- [开发路线图](docs/开发路线图.md)：唯一的当前状态、已完成能力、优先级和下一步入口。
- [UI设计规范](docs/UI设计规范.md)：调试工作台的交互、视觉、响应式和可访问性规范。
- [Flutter 开发规范](docs/Flutter开发规范.md)：目录职责、依赖方向、组件拆分、编码、测试和提交规范。
- [脚本执行安全评估与整改计划](docs/脚本执行安全评估与整改计划.md)：脚本信任边界与 P0 安全整改。
- [AI协议文档自动配置方案评估](docs/AI协议文档自动配置方案评估.md)：AI 导入助手的方案、风险与分期。
- [Agent 协作说明](agent.md)。

## 项目级技能

仓库在 `.agents/skills/` 固化了项目级设计技能，包括 `ui-ux-pro-max`。UI 设计、评审和实现任务应先加载对应技能，并遵循 [UI设计规范](docs/UI设计规范.md)。
