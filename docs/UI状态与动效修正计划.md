# UI shadcn 全面迁移与状态动效修正计划

> 建立日期：2026-08-19；实现状态更新：2026-08-19。应用层 shadcn 全面迁移、状态样式、完整页面 Golden 与当前 Linux/Web 视觉回归已完成；阶段 11 的多平台真机视觉回归仍待执行。

## 修正前诊断

当前控件状态逻辑正常，问题集中在视觉主题和动效策略：

- Material 主题使用 BLExpert 蓝色体系，`ShadcnLayer` 仍使用 `shadcn_flutter` 默认 Slate 主题，两套语义颜色没有同步。
- 9 处直接使用的 `shad.SelectedButton` 主要采用 `outline` / `ghost` 作为未选中态、`secondary` 作为选中态。默认亮色 Slate 下，项目表面上的 `outline` 合成色约为 `#F1F4F8`，`secondary` 为 `#F1F5F9`，两者对比约为 `1.007:1`；暗色 Slate 的 `secondary`、`border`、`input` 均为 `#1E293B`。
- Material `NavigationRailThemeData` 不会影响 shadcn `NavigationRail`，因此桌面模式导航和配置导航没有获得应用主题中已有的蓝色选中态。
- `shadcn_flutter 0.0.53` 的 Switch 轨道与滑块动画固定为 100ms，按钮部分状态变换为 50ms；`SwitchTheme` 不暴露时长。工作区下拉菜单还显式使用了 `Duration.zero`。
- 系统启用“减少动态效果”时，Flutter 会进一步缩短隐式动画。语义状态仍应立即生效，但视觉过渡需要项目拥有的统一策略。
- 仓库仍直接创建 Material `MaterialApp`、`Scaffold`、窄屏 `NavigationBar`、`TabBar`、13 处 Tooltip、2 处 InkWell 和对话框透明 Material 容器，并使用 63 种 Material 图标；这些全部属于待迁移范围。

这不是状态回调、Key 或依赖版本失效。最终目标是应用拥有的业务 UI 全部使用 shadcn 或项目的 shadcn 适配层；修正应落在应用根、项目主题、`app/design` 适配层和视觉回归上，不修改 `.pub-cache`。

## 当前结果

- 应用根已迁移为 `shad.ShadcnApp`，亮暗主题由 `buildAppTheme` 统一构建，不再保留应用层 Material 主题源或 `ShadcnLayer` 过渡结构。
- 业务选择控件已收敛到 `ToolSelectedButton`，选中态同时改变背景、边框和文字/图标强调，并公开 `selected`、`button`、`enabled` 语义。
- `ToolSwitch` 已由项目拥有轨道与滑块过渡，使用 200ms `AppMotion.standard`；减少动态效果时使用 0ms 直接到达终态。
- `Scaffold`、导航、Tabs、Tooltip、Toast、可点击行、SelectableText、Scrollbar、对话框承载层及图标均已迁移到 shadcn 或项目的 shadcn 适配层。`lib/` 不再导入 `package:flutter/material.dart`，应用直接创建 Material 可见控件的例外为零。
- 已增加亮暗主题对比度、透明状态实际合成色、选中/禁用/焦点语义、Switch 中间帧/终态、减少动态效果和组件 Golden 回归；`flutter analyze` 与全套 `flutter test` 已通过。
- Golden 已覆盖选择按钮和 Switch 组件边界，以及 375px 窄屏、1440px 桌面的亮暗完整页面；真实 Web 亮暗主题也已按相同尺寸完成检查，未发现空白画布、文字重叠、导航标签截断、底部遮挡或横向溢出。
- Android、iOS、Windows、macOS 与真实 BLE 设备的视觉、焦点和交互矩阵仍按阶段 11 执行，当前结果不替代目标平台验收。

## 目标与边界

### 目标

1. 让选中、未选中、悬停、按下、焦点和禁用状态在亮暗主题下均可辨识。
2. 以 shadcn 亮暗主题作为唯一应用 UI 主题源，所有业务状态颜色从项目语义令牌生成。
3. 为高频微交互建立统一时长和缓动令牌，并正确响应减少动态效果。
4. 将直接使用第三方选择控件的业务区域逐步收敛到项目适配层。
5. 用自动化对比度检查、Widget 测试和 Golden 回归防止状态再次退化。
6. 将 Material 应用根、页面骨架、导航、Tabs、Tooltip、点击表面、对话框承载层和图标体系全部迁移到 shadcn。

### 非目标

- 不重做整体视觉风格，不引入新的组件库、动画库、渐变、发光或大面积高饱和色块。
- 不采用无法逐批验证的大爆炸式提交；这只是交付策略，不能缩减全面迁移范围或保留永久 Material 区域。
- 不改变 BLE 状态、连接流程、发送安全策略、协议配置、工作区格式或脚本信任边界。
- 不通过修改 `shadcn_flutter` 缓存源码解决问题。

## 状态与动效标准

### 状态表达

选择类控件不得只依赖接近背景色的浅色填充。至少同时满足：

- 选中态使用项目主色体系，并具有背景、边框/指示条、文字/图标中的至少两种可见变化。
- 关键边界、图标或指示条与相邻颜色的对比度不低于 3:1；普通文字与背景不低于 4.5:1。
- 导航选中态除色彩外，还应使用指示条、填充图标或字重之一；开关和复选框继续暴露 `toggled` / `checked` 语义。
- 悬停和按下是瞬时交互反馈，不能与持久选中态使用完全相同的样式。
- 焦点环独立于选中态，在亮暗主题和键盘操作下保持可见。
- 禁用态降低强调但仍可读，并且不响应点击。

建议的项目级状态角色：

| 角色 | 用途 | 视觉要求 |
| --- | --- | --- |
| `selectedStrong` | 当前模式、关键互斥选择 | 主色实底、对比前景色，可附加选中图标 |
| `selectedSubtle` | 筛选、分段按钮、特征状态 | 主色浅容器 + 主色边框 + 主色文字/图标 |
| `unselected` | 可选择但未激活 | 表面色或透明背景 + 中性可见边框 |
| `hovered` | 指针悬停 | 在当前持久状态上增加轻微强调，不改变布局 |
| `pressed` | 按下反馈 | 透明度、表面色或轻微缩放反馈，不移动周围布局 |
| `focused` | 键盘焦点 | 2px 等效焦点环或同等面积的高对比指示 |
| `disabled` | 不可操作 | 降低强调、保留可读性、无点击反馈 |

最终色值从统一主题构建函数生成；业务组件不得自行复制十六进制颜色。

### 动效令牌

不同交互不能机械使用同一时长，建议先建立以下项目令牌：

| 令牌 | 建议范围 | 场景 |
| --- | --- | --- |
| `motionFast` | 100-150ms | hover、pressed、轻量颜色反馈 |
| `motionStandard` | 180-220ms | Switch、选中态、展开/折叠、小范围位置变化 |
| `motionOverlay` | 200-300ms | Dialog、Select、Dropdown 等弹层进出场 |
| `motionReduced` | 0ms 或最短可感知时长 | 系统请求减少动态效果时，仅保留必要状态反馈 |

- 状态值和可访问性语义必须在操作后立即更新，不得依赖动画完成回调。
- Switch 应使用项目拥有的 180-220ms 位置与颜色过渡；需要自定义实现时放在 `ToolSwitch` 内，不复制业务状态。
- 非必要弹层不得显式传入 `Duration.zero`；确需无动画时在调用点记录原因。
- 快速连续切换时，新状态直接替换旧目标，不等待上一段动画结束。

## 修正批次

### P0-A：统一主题源

涉及文件：

- `lib/app/app_theme.dart`
- `lib/app/blexpert_app.dart`

任务：

- 建立项目拥有的 shadcn 亮暗主题构建函数，共享主色、状态容器、边框、焦点环和危险色语义。
- 将应用根从 `MaterialApp + ShadcnLayer` 迁移到 `ShadcnApp`，保留现有国际化、主题模式、快捷键、builder 和路由行为。
- `ShadcnApp` 不再直接使用默认 `shad.ThemeData()` / `ThemeData.dark()`；过渡期 `materialTheme` 只服务尚未迁移的存量控件，完成时删除应用层 Material 主题依赖。
- 保持现有表面层级、低圆角和高密度工具布局，不因主题同步扩大圆角或阴影。
- 为语义颜色增加纯函数测试，至少校验正文、选中前景、关键边界和焦点环对比度。

验收：应用由 `ShadcnApp` 承载；应用层 Material 主题依赖归零；亮暗主题关键对比度均达标。

### P0-B：收敛选择控件

涉及文件：

- `lib/app/design/tool_button.dart`
- `lib/features/device/characteristic_tile.dart`
- `lib/features/device/device_tools_panel.dart`
- `lib/features/records/record_workspace.dart`
- `lib/widgets/app_workspace_shell.dart`
- `lib/features/configuration/configuration_workspace.dart`

任务：

- 在 `app/design` 增加项目级选择按钮/样式入口，区分 `selectedStrong` 与 `selectedSubtle`。
- 替换业务代码中重复的 `outline/ghost -> secondary` 配置，保留现有 Key、文案、回调和尺寸。
- 顶层模式和配置导航增加稳定的主色指示；筛选器、主题选择、写入目标和订阅状态使用浅主色容器、主色边框及文字/图标变化。
- 对可反选与不可反选控件分别处理，避免点击当前模式后进入无选择状态。
- 为选中语义、键盘焦点和禁用态补充 Widget 回归。

验收：不依赖悬停即可在 1 秒内识别当前模式、筛选条件、写入目标和订阅状态；选中态不再直接依赖默认 `ButtonStyle.secondary`。

### P1-A：修正 Switch 和通用微交互

涉及文件：

- `lib/app/design/tool_toggle.dart`
- `lib/app/design/tool_button.dart`
- `lib/features/home/workspace_toolbar.dart`

任务：

- 在 `ToolSwitch` 内提供项目拥有的轨道、滑块、焦点和禁用态样式，使用 `motionStandard`。
- 检查按钮 hover/pressed/selected 的反馈层级，避免 50ms 变换被误认为瞬切。
- 移除工作区菜单无依据的零时长配置，或保留并写明跨平台问题及回归用例。
- 使用 `MediaQuery.disableAnimations` 或等价平台信号实现减少动态效果分支。

验收：正常动效设置下可观察到连续但不拖沓的 Switch 和选择状态过渡；减少动态效果下状态立即、稳定地到达终态。

### P1-B：全面替换剩余 Material UI

当前基线与目标：

| 当前应用层用法 | 目标 |
| --- | --- |
| `MaterialApp` + 手工 `ShadcnLayer` | `shad.ShadcnApp` |
| Material `Scaffold` | shadcn `Scaffold` 与项目骨架适配 |
| 窄屏 Material `NavigationBar` / `NavigationDestination` | shadcn `NavigationBar` / `NavigationItem` |
| Material `TabBar` / `TabBarView` | shadcn `Tabs` / `TabList` / `TabItem` |
| 13 处 Material `Tooltip` | shadcn Tooltip 或统一 `ToolTooltip` |
| 2 处 `InkWell` 点击行 | shadcn `Clickable`、Button 或项目行交互适配 |
| 对话框透明 Material 承载层 | 纯 shadcn Dialog 内容和操作区 |
| 63 种 Material `Icons.*` | 语义对应的 Lucide/Radix 图标 |

任务：

- 先扩展 `app/design` 的 Tooltip、Tabs、可点击行、Scaffold/导航适配，再逐个 feature 替换，避免业务页面重复第三方参数。
- 窄屏导航保留 SafeArea、触控尺寸和返回行为，但实现改为 shadcn。
- 替换 Material 图标时建立语义映射表，保持线性/填充状态规则、尺寸、tooltip 和测试查找入口。
- 每完成一个批次，审计 `lib/` 中应用直接创建的 Material 可见控件；例外必须记录组件、原因、影响平台和删除条件。
- 最终删除仅服务 Material UI 的主题配置、透明承载层和 imports；Flutter 基础 Widget 与 shadcn 内部 Material 依赖不属于清理目标。

验收：应用业务 UI 中不再直接创建 Material 可见控件或交互表面；仓库记录的例外数量为零；现有 Key、语义、国际化和业务回调全部保留。

### P1-C：回归和发布门槛

任务：

- Widget 测试覆盖选中值、语义状态、禁用态、焦点态、动画中间帧和最终帧。
- Golden 覆盖 375px 窄屏与 1440px 桌面、亮色与暗色；至少包含主导航、分段控件、记录筛选、特征操作和 Switch。
- 对主题令牌执行自动化对比度断言，透明颜色按实际表面合成后计算。
- Linux 和 Web 先完成视觉回归；Android、iOS、Windows、macOS 与真实设备回归并入阶段 11。
- 提交前执行 `dart format lib test`、`flutter analyze`、`flutter test` 和 `git diff --check`。

验收：自动化检查能够在选中态退回默认 Slate `secondary` 或动画退回不可感知时失败；阶段 11 的平台矩阵中没有新增状态辨识差异。

## 执行顺序与状态

| 顺序 | 批次 | 状态 | 阻塞关系 |
| --- | --- | --- | --- |
| 1 | P0-A 统一主题源 | 已完成 | `ShadcnApp` 与项目亮暗主题已落地 |
| 2 | P0-B 收敛选择控件 | 已完成 | 业务选择态已收敛到项目适配层 |
| 3 | P1-A 修正 Switch 与微交互 | 已完成 | 200ms 与减少动态效果分支已有测试 |
| 4 | P1-B 全面替换剩余 Material UI | 已完成 | 应用层 Material UI 与 import 例外为零 |
| 5 | P1-C 自动化与平台回归 | 当前环境已完成 | 组件/完整页面自动化与 Linux/Web 视觉检查已通过；阶段 11 真机矩阵继续跟踪 |

P0-A 至 P1-C 的当前 Linux/Flutter/Web 验收已收口。后续不得重新引入应用层 Material UI，也不得绕过 `app/design` 重复定义选择状态；Android、iOS、Windows、macOS 和真实 BLE 设备回归进入阶段 11 跟踪。

## 风险与回退

- shadcn 主题是唯一应用 UI 主题源；Flutter 基础 Widget 和 `shadcn_flutter` 内部实现使用 Material 不计为应用层例外。
- 自定义 Switch 必须保留键盘操作、焦点、鼠标光标、禁用态和 `Semantics`，不能只复制外观。
- 样式收敛不得改变 `SelectedButton` 的业务选择模型或异步 BLE 回调。
- Golden 只覆盖稳定组件边界，避免把实时日志、系统字体细节和平台抗锯齿差异做成脆弱快照。
- 如第三方升级已提供可配置时长或更完整主题 API，先在隔离分支验证，再决定是否删除项目适配代码。
