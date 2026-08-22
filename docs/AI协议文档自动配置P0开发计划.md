# AI 协议文档自动配置 P0 开发计划

> 计划基线：2026-08-22。本文将 [AI协议文档自动配置方案评估](AI协议文档自动配置方案评估.md) 的 P0 拆分为可独立实现、验证和审查的工作包；本阶段不调用模型、不上传文档、不保存 API Key，也不向 BLE 设备发送数据。

## 1. 目标与完成定义

P0 的目标是建立一条完全离线、可重复验证的安全链路：

```text
人工构造的候选 JSON
  -> 解析为候选草案
  -> 本地确定性校验
  -> 审查并选择接受项
  -> 生成新的草案工作区
```

完成 P0 后，应用应能安全地接收一份人工构造的候选配置，并让用户在不影响当前活动工作区的前提下，查看其证据、风险、校验错误和审查状态；只有用户明确执行“生成草案工作区”后，才创建一个新的、可编辑但不会自动连接或发送的 `Workspace`。

P0 的验收不以模型效果为标准，而以候选结构、校验和审查边界的确定性为标准。这将为后续 BYOK 模型接入提供唯一的写入入口。

## 2. 范围

### 纳入 P0

- 独立于 `Workspace` 的候选草案、证据、问题、校验报告和审查状态模型。
- 受版本控制的候选 JSON 编解码与结构检查。
- 对协议、命令、响应映射、BLE UUID 和脚本候选的纯本地确定性校验。
- 候选项的接受、拒绝和编辑后重校验机制。
- 从已接受候选显式生成新的草案工作区；现有工作区只能作为只读对照，不能被覆盖。
- 最小审查界面或开发期入口：展示变更摘要、校验结果和必要的确认操作。
- 匿名/已授权的协议样例、候选 JSON fixture 与单元、Widget 回归测试。

### 明确不纳入 P0

- 模型提供商、HTTP、API Key、安全存储、网络重试和费用控制。
- PDF、DOCX、OCR、文件选择、长文档分段及提示词实现。
- 自动从文档提取证据或生成候选；P0 仅导入人工构造的候选 JSON。
- 自动启用 JavaScript、自动连接设备、自动发送命令，或 MCP 集成。
- 云端服务、团队权限和正式发布所需的平台 runtime 审计。

## 3. 当前基础与差距

可直接复用的基础：

- `Workspace` 已承载 `ProtocolDefinition`、`CommandDefinition`、`ResponseMapping`、`DeviceProfile` 与 `ScriptConfig`。
- `PacketEncoder`、`PacketDecoder`、`CommandPayloadEncoder` 和 `DataMapper` 已提供运行时约束的部分实现。
- `WorkspaceManager.previewImport` 已展示“先预览、后变更”的导入模式；导入脚本会被强制禁用并标记为不可信。
- 工作区指令白名单、设备发送策略和危险命令二次确认已接入发送路径。

P0 要补齐的差距：

- 现有 `fromJson` 主要承担运行配置反序列化，不能承载证据、置信度、假设、风险、问题和用户审查记录。
- 现有协议、指令和映射校验分散在表单、编码或解码时执行；缺少可在写入前一次性运行、可返回全部问题的统一校验器。
- `WorkspaceManager` 只有正式工作区；没有独立草案存储、草案生命周期和“只创建新工作区”的应用边界。
- 当前全量测试存在 Golden 基线差异及一项“直接发送绕过封包”失败。P0 代码合并前需确认该失败的根因和责任边界，不能把新的回归混入既有失败。

## 4. 目标架构与数据契约

### 4.1 目录与依赖方向

建议新增以下目录；模型和服务均不得依赖页面组件：

```text
lib/models/protocol_import/
  protocol_import_job.dart
  candidate_item.dart
  candidate_workspace.dart
  import_evidence.dart
  validation_report.dart
lib/services/protocol_import/
  candidate_workspace_codec.dart
  protocol_candidate_validator.dart
  workspace_draft_manager.dart
  candidate_workspace_mapper.dart
lib/features/configuration/protocol_import/
  protocol_import_review_workspace.dart
test/protocol_import/
  fixtures/
```

`ProtocolCandidateValidator` 必须是纯 Dart 服务，不依赖 `BuildContext`、BLE 服务、`SharedPreferences` 或模型网络接口。UI 只能消费结果并请求状态变化；映射服务是唯一允许把已接受候选转换为运行 `Workspace` 的位置。

### 4.2 核心模型

| 模型 | 必要字段 | 说明 |
| --- | --- | --- |
| `ProtocolImportJob` | `id`、`schemaVersion`、来源元数据、`candidateWorkspace`、问题、`validationReport`、状态 | 一次导入/审查任务的聚合根。P0 来源固定为人工候选 JSON。 |
| `CandidateWorkspace` | 工作区元信息、连接/协议/命令/映射/脚本候选列表 | 与运行 `Workspace` 分离，不得直接作为运行配置。 |
| `CandidateItem<T>` | `id`、`value`、`evidenceRefs`、`confidence`、`assumptions`、`riskLevel`、`reviewStatus` | 每个可审查变更的统一包装。 |
| `ImportEvidence` | `id`、文本片段、定位信息、来源哈希 | P0 支持人工文本片段和逻辑位置；页码、表格坐标预留字段。 |
| `ImportQuestion` | `id`、问题、严重级别、关联候选 ID、回答状态 | 表示缺失或矛盾信息，不允许通过默认猜测自动消除。 |
| `ValidationIssue` | `code`、严重级别、路径、说明、关联候选 ID | `error` 阻止应用；`warning` 要求额外审查；`info` 仅提示。 |
| `WorkspaceDraft` | `id`、来源 Job ID、生成时间、映射后的 `Workspace`、状态 | P0 只生成本地草案，不替换活动工作区。 |

所有模型 JSON 中必须有整数 `schemaVersion`。未知未来版本须拒绝导入；本项目尚未发布，可不为 P0 之前的候选格式建立迁移逻辑。模型密钥、文档全文、设备连接状态和 BLE 句柄不得进入这些模型。

### 4.3 状态与不可变规则

```text
created -> validated -> underReview -> readyToApply -> applied
                 |             |
                 +-> blocked <-+
```

- 任何 `error`、未回答的阻塞问题、未审查的危险项或未接受的必需配置，都会使任务处于 `blocked`，不能生成草案工作区。
- 候选编辑后必须清除其旧的校验结论，并重新运行完整校验；不能沿用编辑前的“已通过”。
- 普通候选至少需标记为 `accepted`；`warning` 与 `dangerous` 候选需要单独确认，不能使用“全部接受”绕过。
- 脚本候选即使通过审查，映射结果仍必须为 `enabled: false`、`trustState: importedUntrusted`，并写明 `source: AI import draft`。
- P0 中任何操作都不能调用 BLE 连接或写入服务。

## 5. 工作包与实施顺序

### WP0：基线确认与测试隔离

**目的**：让 P0 的验证结果可判读。

1. 复现并记录现有四个页面 Golden 差异及“直接发送绕过封包”失败的环境、命令和根因归属。
2. 为 P0 新增独立测试目录和 fixture，CI 中可单独运行其纯 Dart 测试；不得依赖 Golden 结果判断候选校验是否正确。
3. 在 P0 合并前恢复或明确豁免既有失败，且不更新 Golden 基准图来掩盖未定位的差异。

**产出**：基线记录、可独立运行的 `test/protocol_import/` 测试组。

### WP1：候选草案契约与 JSON codec

**目的**：先固定模型/人工输入与应用内部的安全边界。

1. 实现第 4.2 节模型及枚举：置信度、风险、审查状态、任务状态和问题严重级别。
2. 实现 `CandidateWorkspaceCodec`：严格 JSON 类型检查、格式版本检查、未知枚举拒绝、重复 ID 拒绝和错误路径定位。
3. 提供最小有效、含警告、含危险命令、含脚本、非法结构五组 fixture。
4. 约定稳定 issue code，例如 `schema.invalidType`、`candidate.duplicateId`、`evidence.missing`，以便 UI、测试和未来模型 adapter 不依赖中文错误文案。

**完成条件**：任意候选 JSON 都能得到对象或结构化错误；不允许因默认值静默吞掉输入错误。

### WP2：统一确定性校验器

**目的**：将运行时才会暴露的问题提前为可审查的完整报告。

`ProtocolCandidateValidator` 接收 `CandidateWorkspace` 和可选样例报文，返回不修改输入的 `ValidationReport`。至少覆盖：

- ID、名称、枚举、HEX、UUID、字节长度、范围、唯一性和引用完整性。
- 协议段顺序、唯一 payload、长度/序号/校验字段配置、固定 HEX、收发帧可编码/可解码性。
- 命令参数与载荷占位符一致性、命令 ID 和显示名冲突、可发送载荷可由 `CommandPayloadEncoder` 编码。
- 响应命令码、字段 key、偏移、长度、数据类型、字节序、缩放与字段重叠/越界。
- 已提供的示例报文可使用 `PacketEncoder`/`PacketDecoder` 重放；没有样例只能产生警告，不能伪称验证通过。
- 每个候选必须有至少一个有效证据引用；脚本候选必须标记警告且不允许成为可执行配置。
- 危险命令关键词命中、写入类命令、低置信度和存在假设的候选必须产生须审查的警告。

校验器应优先复用现有编码、解码和载荷编码服务，但要捕获 `FormatException` 并转化为 `ValidationIssue`，不能让单项异常中断整份报告。

**完成条件**：一份候选中的多个错误能在一次校验中全部返回，且同一输入始终产生相同的 issue code、路径和严重级别。

### WP3：草案存储、审查状态与映射

**目的**：确保 P0 的唯一写入出口是新的草案工作区。

1. 实现 `WorkspaceDraftManager`，使用独立 storage key 保存 `ProtocolImportJob` 与 `WorkspaceDraft`；不得复用 `blexpert.workspace-store.v1`。
2. 实现接受、拒绝、编辑与重新校验状态转换；持久化前后保持证据和审查记录。
3. 实现 `CandidateWorkspaceMapper`，仅选择已接受且无阻塞 issue 的候选，生成新 ID、新时间戳和“AI 导入草案”来源标记的 `Workspace`。
4. 映射必须复制而非修改当前 `Workspace`；生成成功后由用户决定是否切换查看新工作区。
5. 映射的脚本保持禁用不可信；命令不写入快速发送白名单；设备安全策略沿用最保守默认值。

**完成条件**：同一任务不可能覆盖活动工作区；草案生成前后均没有 BLE 调用，重启后仍能恢复未完成审查任务。

### WP4：最小审查入口

**目的**：验证用户能够理解并控制 P0 的安全状态，而非只测试后台对象。

1. 在“配置”工作区增加开发期入口“导入候选草案”，只接受 P0 JSON 文本。
2. 按协议、命令、映射、连接、脚本和问题分组展示：候选值、证据摘要、置信度、风险、校验结果和审查状态。
3. 提供接受、拒绝、编辑、重新校验和“生成草案工作区”操作；阻塞状态下禁用生成按钮并展示原因。
4. 为危险命令和脚本采用独立确认；脚本仅展示为建议，界面不得提供“立即启用”或“立即发送”。
5. 遵循现有 `features/configuration/` 与 shadcn UI 边界，所有新增可见文案加入中英文 l10n。

**完成条件**：通过 Widget 测试验证“导入候选不改变活动工作区”“未确认危险项无法生成”“生成后脚本仍禁用”。

### WP5：样本、回归与交付评审

**目的**：为 P1 的模型输出建立可量化、可回归的输入集。

1. 准备至少三类匿名或已获授权的样例：简单定长帧、含长度/校验的帧、含命令与响应映射的帧；每份附人工标注和证据片段。
2. 为每类样例准备“正确候选”“缺证据/低置信度”“多个规则冲突”版本。
3. 覆盖 codec、校验器、状态机、映射、草案持久化、重启恢复及审查 UI。
4. 形成 P0 验收记录：通过率、阻止的无效项、危险项确认、脚本禁用和零 BLE 写入证明。

**完成条件**：所有 P0 测试通过，并完成第 6 节全部验收场景。

## 6. 验收场景

| 场景 | 期望结果 |
| --- | --- |
| 合法人工候选 JSON | 可解析、校验、审查并生成新的草案工作区。 |
| JSON 类型错误、未知版本或重复 ID | 在 codec 阶段拒绝；当前工作区和既有草案不变。 |
| 无证据、低置信度或文档矛盾候选 | 显示问题/警告，不能被静默应用。 |
| 多个协议/命令/映射错误 | 一次性返回全部可定位 issue，不因第一个异常中断。 |
| 危险命令 | 必须独立确认；未确认时不能生成草案。 |
| AI 脚本候选 | 即使用户接受，也以禁用、未信任状态写入草案，且不会执行。 |
| 对已有工作区执行导入 | 活动工作区的 ID、内容和持久化数据不变；仅创建独立草案。 |
| 重启应用后 | 未完成任务、审查选择和验证报告可恢复；不会执行脚本或发送 BLE 数据。 |
| 任何 P0 流程 | 不访问网络、不读取/保存 API Key、不调用 BLE connect/write。 |

## 7. PR 切分与依赖

建议按以下顺序合并，避免把大规模 UI、模型接入和领域校验混在一个变更中：

1. **PR-1：P0 契约与 fixture** — WP0、WP1；不改正式工作区存储。
2. **PR-2：确定性校验器** — WP2；以纯 Dart 测试为主。
3. **PR-3：草案管理与映射** — WP3；覆盖持久化、隔离与脚本安全默认值。
4. **PR-4：审查入口** — WP4；只消费稳定服务接口。
5. **PR-5：样本与验收收口** — WP5；补齐回归、文档和质量记录。

依赖关系为 `PR-1 -> PR-2 -> PR-3 -> PR-4 -> PR-5`。WP0 的既有测试问题可并行排查，但不得阻塞 WP1/2 的纯领域开发；在 PR-4 合入主干前须对其结论作出处理。

## 8. P0 退出门槛与进入 P1 条件

P0 完成后才允许立项 P1 的模型连接；P1 不得绕过 P0 codec、校验器和草案应用服务。进入 P1 前必须满足：

- 所有第 6 节场景有自动化回归，P0 新增测试全绿。
- 草案与正式工作区使用独立存储和明确状态，代码审查确认不存在覆盖活动工作区的路径。
- 脚本候选始终禁用未信任，且危险命令无独立确认不能进入草案。
- 既有测试失败已修复、已获得明确的环境基线说明，或在 CI 中被可审计地隔离；不得以更新 Golden 基准图替代根因分析。
- 样例及人工标注具备可使用授权，不含真实 API Key、设备标识、客户机密或未脱敏报文。

满足后，P1 只需新增“文本来源 -> 证据提取 -> 候选 JSON”的上游生产者；下游审查、安全和写入边界保持不变。

## 9. 实施记录（2026-08-22）

P0 主链路已实现，代码位于 `lib/models/protocol_import/`、`lib/services/protocol_import/` 与 `lib/features/configuration/protocol_import_review.dart`：

- 候选 JSON 通过严格版本、类型和枚举 codec 进入系统；运行 `Workspace.fromJson` 不再直接面对候选输入。
- 校验器会聚合证据引用、ID、协议、命令、映射、UUID、危险命令、脚本和审查状态问题。
- 导入任务与生成的草案使用独立 `blexpert.protocol-import-drafts.v1` 存储；草案映射不会覆盖当前工作区。
- 配置页已提供候选 JSON 导入、检查、逐项接受/拒绝、完整候选 JSON 编辑、重新校验、新草案工作区生成，以及重启后继续未完成审查的入口。
- AI 脚本在映射时被强制为 `enabled: false`、`importedUntrusted`；命令不会进入快捷入口或发送白名单；P0 不调用网络或 BLE 服务。
- 新增 `test/protocol_import_test.dart` 与配置流程 Widget 回归，覆盖 codec、错误聚合、危险候选拦截、草案隔离/持久化、脚本禁用与编辑后重校验。

验证状态：`flutter analyze`、P0 专用测试与全量 `flutter test` 均通过（存在 2 项预期的 QuickJS 平台跳过）。本轮已修复原有的“直接发送绕过协议封包”回归；4 项完整页面 Golden 均已在确认根因后更新，未以未知差异替换基准。

### 9.1 Golden 基线复现记录（2026-08-22）

为区分 P0 改动和既有 UI 基线问题，已在当前工作区和从 `HEAD` 克隆出的干净副本中运行同一条命令：

```powershell
flutter test test/ui_page_golden_test.dart --plain-name "桌面调试工作台 dark 页面 Golden"
```

两处均得到相同结果：`3.37%`、`43,676px` 差异。因此该桌面 Golden 不由 P0 未提交改动引入。提交追溯显示桌面差异从 `8eb9964`（新增“直接发送”控件）开始，且差异仅位于发送区；已人工复核并更新两张桌面 Golden，使其覆盖该控件。375px 亮/暗两项在生成现有桌面基准的 `9267d85` 中已经失败；进一步追溯确认差异来自 `dc2fc8b` 的中文字体接入和记录筛选栏样式收口，且由现有 Widget 尺寸/布局回归覆盖。已更新两张移动端 Golden。最终 `flutter test` 123 项通过、2 项 QuickJS 平台测试按预期跳过，P0 已满足进入 P1 的自动化门槛。
