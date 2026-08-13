# BLExpert

BLExpert 是一款使用 Flutter 开发的跨平台蓝牙调试与分析工具。

目标平台：

- Android
- iOS
- Windows
- macOS
- Web

## 项目目标

BLExpert 面向物联网和嵌入式设备开发场景，重点解决设备协议差异大、调试流程分散、团队协作成本高等问题。

应用以“工作区”为核心组织单位，把设备信息、指令集、解析脚本、数据映射表、收发日志和导入导出配置集中管理，让同一类设备的调试过程可以复用、分享和持续沉淀。

## 核心能力

- 工作区管理：为不同设备或项目建立独立配置空间。
- 蓝牙通信：支持 BLE 与经典蓝牙 SPP 的扫描、连接、断开、读写和通知订阅。
- 脚本引擎：通过 JavaScript 在发送前和接收后处理 HEX 数据。
- 数据解析：把原始 HEX 数据解析为温度、湿度、电量、状态位等结构化字段。
- 导入导出：将完整工作区导出为单文件 JSON，便于团队协作。
- 实时可视化：支持 HEX、ASCII、JSON、时间戳日志，后续扩展图表监控。

## 当前状态

当前仓库已完成第一版基础骨架：

- Flutter 应用入口已替换为 BLExpert 工作台。
- 已建立工作区、设备配置、脚本配置等基础模型。
- 已建立工作区管理器，支持 JSON 导入导出的基础能力。
- 已建立蓝牙服务抽象层，并提供 Mock 实现用于桌面/Web 预览和早期开发。
- 首页已包含工作区、设备扫描、调试控制台三个区域。
- 界面支持亮色、暗色和跟随系统三种主题模式。
- 已接入 Flutter 国际化，支持中文、英文和跟随系统语言；可从顶部语言菜单切换。
- 已接入 `universal_ble` 的真实 BLE Central 实现：扫描、连接、GATT 服务发现、用户选择通知订阅和写入特征。

## 蓝牙实现说明

- BLE 适配层使用 `universal_ble`，许可证为 BSD 3-Clause，可用于商业项目。
- 默认运行时使用真实 BLE；Android、iOS、macOS、Windows、Linux 和 Web 均由插件覆盖。
- 当前基础调试流程会自动选择设备首个可写特征和首个可通知 / 指示特征。后续工作区配置将允许固定指定服务和特征 UUID。
- 经典蓝牙 SPP 不属于 BLE，需作为独立的平台适配器实现，当前未接入。
- 本地演示可使用 Mock 服务：`flutter run --dart-define=USE_MOCK_BLUETOOTH=true`。

## 项目资料

更多项目说明请查看：

- [项目说明文档](docs/BLExpert_Project_Brief.md)
- [Agent 协作说明](agent.md)

## 建议目录结构

```bash
lib/
├── main.dart
├── models/
├── services/
├── providers/
├── screens/
├── widgets/
└── utils/
```

## 开发优先级

下一阶段建议按以下顺序推进：

1. 拆分 `main.dart`，补齐 `screens/`、`widgets/`、`providers/` 目录。
2. 接入状态管理，统一管理工作区、扫描状态、连接状态和日志。
3. 接入真实 BLE 插件，优先实现扫描、连接、服务发现、特征值读写。
4. 设计经典蓝牙 SPP 的平台适配方案。
5. 完善 HEX 工具、CRC 工具和数据日志结构。
6. 集成 JavaScript 脚本引擎。
7. 实现工作区持久化、导入导出和示例工作区。

## 运行项目

```bash
flutter pub get
flutter run
```

### Web Bluetooth 调试

Chrome 的 Web Bluetooth 在 Linux 等平台需要启用实验性 Web 平台功能。使用以下命令启动 Flutter Web，Flutter 会将参数传给它启动的 Chrome：

```bash
flutter run -d chrome \
  --web-browser-flag=--enable-experimental-web-platform-features
```

VS Code 用户可从“运行和调试”选择 `BLExpert Web Bluetooth` 配置；该配置已包含相同参数。首次使用时还应确认：

- 使用 Google Chrome 或 Chromium，且蓝牙适配器已开启。
- 在 Chrome 地址栏打开 `chrome://flags/#enable-experimental-web-platform-features`，确认该实验功能为 `Enabled`，然后重启浏览器。
- Web Bluetooth 仅允许在安全上下文中访问。`flutter run` 提供的本地地址可用；部署环境需使用 HTTPS。

## 设计原则

- 优先使用中文界面和中文文档。
- 默认跟随系统主题，同时允许用户手动切换亮色和暗色模式。
- 首页应直接呈现可用工具，不做营销页。
- 调试界面应保持专业、紧凑、易扫描。
- 平台特定能力必须放在服务层或适配层，避免 UI 直接绑定插件。
