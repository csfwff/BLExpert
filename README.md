# BLExpert

> 文档基线：2026-08-17。开发状态和优先级以 [开发路线图](docs/开发路线图.md) 为准。

BLExpert 是一款基于 Flutter 的跨平台 BLE 协议调试与分析工具。它面向嵌入式、IoT、测试和现场支持工程师，将设备连接、原始收发、协议配置、参数化指令和响应字段映射组织为可复用的工作区。

> 当前版本可用于 BLE 基础调试、标准协议封包/解帧和工作区配置验证。会话记录导出及脚本可终止隔离仍在开发中，详见“当前边界”。

## 当前能力

### 调试工作台

- 三种工作模式：`调试`、`配置`、`记录`。
- 桌面端使用模式导航、设备与特征区、通信控制台和可收起 Inspector；窄屏端使用底部导航。
- 支持亮色、暗色和跟随系统主题，以及中文、英文和跟随系统语言。
- 通信控制台记录带时间戳的发送、接收、系统和错误事件，支持 HEX/文本手动发送、自动滚动和清空。

### BLE Central

- 基于 `universal_ble` 实现扫描、连接、断开、服务/特征发现。
- 支持 Read、Write、Write without response、Notify 和 Indicate。
- 可手动选择写入目标特征和通知/指示订阅特征。
- 保留 Mock 蓝牙服务：`flutter run --dart-define=USE_MOCK_BLUETOOTH=true`。
- 覆盖 Android、iOS、Windows、macOS、Linux 和 Web 的 BLE 调试路径，实际平台能力受系统蓝牙栈和浏览器限制。

### 工作区与协议配置

- 工作区保存元信息、协议段、脚本配置、指令、响应映射和最近活动工作区。
- 使用 `shared_preferences` 保存工作区列表和当前工作区；支持完整工作区 JSON 导入/导出与旧字段兼容读取。
- 协议编辑支持发送/接收片段：固定 HEX、业务载荷、长度、序号和校验。
- 标准协议已接入发送和接收链路：自动生成长度、序号和 XOR/SUM8/CRC8/CRC16/CRC32 校验，并支持拆包、粘包、多帧和校验失败后的恢复。
- 标准解帧后的业务载荷会进入 `CMD/DATA` 响应映射；原始通知始终保留在控制台。

### 指令与数据映射

- 指令支持 HEX 或文本业务载荷、启用状态和快捷入口。
- HEX 指令支持 `{{key}}` 参数占位符：整数、HEX、ASCII、UTF-8、布尔、枚举及当前日期/时间字节。
- 响应映射按 `CMD` 匹配，字段偏移相对解码后的 `DATA`；支持数值、HEX、ASCII、UTF-8、布尔、枚举、位域、字节序、比例、数值偏移和单位。
- Inspector 会展示最近一次成功映射的字段值和已启用的快捷指令。

### JavaScript 协议脚本

- 原生平台通过 `flutter_js` 支持 `beforeSend(context)` 和 `afterReceive(context)`。
- 提供 HEX、校验和、CRC、MD5 等 JavaScript 内置工具函数。
- Web 端保留脚本配置，但不执行 JavaScript 脚本。
- 导入工作区的脚本会被强制禁用并标记为未信任；首次启用需要显式确认来源与风险。
- 脚本源码、输入/输出帧和日志已有大小上限；Android/Windows/Linux 的 QuickJS 已启用 50ms/16MiB 硬限制，脚本写入按 200ms 限流，改写帧与高风险关键词命令会要求确认。Apple JavaScriptCore 的可终止超时、工作区命令白名单和设备能力策略尚未完成。

## 当前边界与已知限制

- 产品范围仅包含 BLE Central；不计划支持经典蓝牙 SPP。
- 标准协议当前覆盖常见固定帧、长度字段、序号和校验规则；复杂状态机、转义、加密和非常规长度语义需要脚本或后续扩展。
- 工作区按设备保存服务 UUID、默认写入/订阅特征及 Web 服务 UUID；连接后会尝试恢复，并对失效配置给出日志提示。
- 导入尚无版本迁移、冲突处理或可审查的局部应用流程。
- 会话记录目前是内存日志视图，没有持久化、筛选、书签和正式导出能力。
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

当前仓库测试覆盖工作区/指令/协议 JSON 兼容、参数化载荷编码、响应字段映射、Web 服务 UUID 解析和核心 Widget 工作流。

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
- [脚本执行安全评估与整改计划](docs/脚本执行安全评估与整改计划.md)：脚本信任边界与 P0 安全整改。
- [AI协议文档自动配置方案评估](docs/AI协议文档自动配置方案评估.md)：AI 导入助手的方案、风险与分期。
- [Agent 协作说明](agent.md)。

## 项目级技能

仓库在 `.agents/skills/` 固化了项目级设计技能，包括 `ui-ux-pro-max`。UI 设计、评审和实现任务应先加载对应技能，并遵循 [UI设计规范](docs/UI设计规范.md)。
