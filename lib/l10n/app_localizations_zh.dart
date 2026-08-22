// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BLExpert';

  @override
  String get startScan => '开始扫描';

  @override
  String get stopScan => '停止扫描';

  @override
  String get exportWorkspacePreview => '导出工作区预览';

  @override
  String get newWorkspace => '新建工作区';

  @override
  String get deleteWorkspace => '删除工作区';

  @override
  String deleteWorkspaceConfirm(String name) {
    return '确定删除“$name”？此操作不可撤销。';
  }

  @override
  String get deleteWorkspaceLast => '至少需要保留一个工作区。';

  @override
  String get workspaceSaved => '工作区已保存。';

  @override
  String get importWorkspace => '导入工作区';

  @override
  String get exportWorkspace => '导出工作区';

  @override
  String get themeMode => '主题模式';

  @override
  String get settings => '设置';

  @override
  String get debug => '调试';

  @override
  String get configure => '配置';

  @override
  String get records => '记录';

  @override
  String get language => '语言';

  @override
  String get versionLabel => '版本号';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '亮色模式';

  @override
  String get darkMode => '暗色模式';

  @override
  String get english => '英文';

  @override
  String get chinese => '中文';

  @override
  String get workspace => '工作区';

  @override
  String deviceCount(int count) {
    return '设备数量：$count';
  }

  @override
  String get deviceScan => '设备扫描';

  @override
  String get selectDeviceFirst => '请先选择设备';

  @override
  String get connect => '连接';

  @override
  String get connected => '已连接';

  @override
  String deviceDetails(String protocol, int rssi, String id) {
    return '$protocol / RSSI $rssi / $id';
  }

  @override
  String get debugConsole => '调试控制台';

  @override
  String get noData => '暂无收发数据。';

  @override
  String get received => '接收';

  @override
  String get system => '系统';

  @override
  String get error => '错误';

  @override
  String get deviceUnavailable => '设备已离开蓝牙范围或停止广播，请重新扫描后再连接。';

  @override
  String bluetoothOperationFailed(String error) {
    return '蓝牙操作失败：$error';
  }

  @override
  String get connecting => '正在连接';

  @override
  String get disconnecting => '正在断开';

  @override
  String connectingDevice(String name) {
    return '正在连接 $name...';
  }

  @override
  String disconnectingDevice(String name) {
    return '正在断开 $name...';
  }

  @override
  String connectedToDevice(String name) {
    return '已连接 $name。';
  }

  @override
  String get workspaceSelector => '工作区';

  @override
  String get selectWorkspace => '选择工作区';

  @override
  String get connection => '连接设备';

  @override
  String get connectDevice => '连接设备';

  @override
  String get disconnectDevice => '断开设备';

  @override
  String get noDevice => '未选择设备';

  @override
  String get console => '控制台';

  @override
  String get allFilter => '全部';

  @override
  String get txFilter => 'TX';

  @override
  String get rxFilter => 'RX';

  @override
  String get systemFilter => 'SYS';

  @override
  String get errorFilter => 'ERR';

  @override
  String get filterLogs => '筛选日志';

  @override
  String get searchLogs => '搜索日志、HEX、来源或指令';

  @override
  String get noMatchingLogs => '没有匹配的日志';

  @override
  String get backToLatest => '回到最新';

  @override
  String get exportLogs => '导出日志';

  @override
  String retainedLogs(int retained, int discarded) {
    return '保留 $retained 条 / 已丢弃 $discarded 条';
  }

  @override
  String get clear => '清空';

  @override
  String get autoScroll => '自动滚动';

  @override
  String get sendData => '发送数据';

  @override
  String get directSend => '直接发送';

  @override
  String get directSendHint =>
      '开启后将跳过协议封包和发送前脚本，按当前模式解析后的输入字节会直接发送；设备发送策略仍然有效。';

  @override
  String sendUnavailable(String reason) {
    return '暂不可发送：$reason';
  }

  @override
  String get noWriteTargetSelected => '未选择可写特征';

  @override
  String get inputPlaceholder => '输入要发送的数据...';

  @override
  String get emptyInput => '请输入要发送的数据';

  @override
  String get invalidHexInput => 'HEX 数据格式无效';

  @override
  String payloadLength(int length) {
    return '业务载荷 $length 字节';
  }

  @override
  String finalFramePreview(int length, String frame) {
    return '最终帧 $length 字节：$frame';
  }

  @override
  String finalFrameLabel(int length) {
    return '最终帧 $length 字节：';
  }

  @override
  String get scriptPreviewUnavailable => '脚本模式：最终帧将在发送前生成';

  @override
  String get textMode => '文本';

  @override
  String get hexMode => 'HEX';

  @override
  String get lineEnding => '行尾';

  @override
  String get none => '无';

  @override
  String get lf => 'LF';

  @override
  String get crlf => 'CRLF';

  @override
  String get checksum => '校验和';

  @override
  String get autoSend => '自动发送';

  @override
  String get quickCommands => '快捷指令';

  @override
  String get newCommand => '新建指令';

  @override
  String get commandName => '指令名称';

  @override
  String get commandPayload => '数据内容';

  @override
  String get sendCommand => '发送';

  @override
  String connectedDevice(String name) {
    return '已连接：$name';
  }

  @override
  String deviceCountShort(int count) {
    return '$count 个设备';
  }

  @override
  String get characteristics => '特征';

  @override
  String get connectToDiscoverCharacteristics => '连接设备后可发现其 GATT 特征。';

  @override
  String get noCharacteristics => '未发现 GATT 特征。';

  @override
  String get filterCharacteristics => '筛选特征或 UUID';

  @override
  String get operableOnly => '仅显示可操作特征';

  @override
  String get noMatchingCharacteristics => '没有匹配的特征。';

  @override
  String get service => '服务';

  @override
  String get disconnected => '未连接';

  @override
  String get readCapabilityDescription => '读取：客户端拉取数据';

  @override
  String get writeCapabilityDescription => '写入响应：客户端推送，服务端返回确认';

  @override
  String get writeNoResponseCapabilityDescription => '无响应写入：客户端推送，服务端不返回确认';

  @override
  String get notifyCapabilityDescription => '通知：服务端推送，客户端不返回确认';

  @override
  String get indicateCapabilityDescription => '指示：服务端推送，客户端返回确认';

  @override
  String get selectedLog => '选中日志';

  @override
  String get viewLogDetails => '查看日志详情';

  @override
  String get closeLogDetails => '关闭日志详情';

  @override
  String get source => '来源';

  @override
  String get length => '长度';

  @override
  String get transaction => '事务';

  @override
  String get noSource => '无来源';

  @override
  String get subscribe => '订阅';

  @override
  String get writeWithResponse => 'Write';

  @override
  String get writeWithoutResponse => 'Write without response';

  @override
  String get notify => 'Notify';

  @override
  String get indicate => 'Indicate';

  @override
  String get read => 'Read';

  @override
  String get readValue => '读取';

  @override
  String dataSent(int length) {
    return '已发送 $length 字节';
  }

  @override
  String dataRead(int length) {
    return '已读取 $length 字节';
  }

  @override
  String subscriptionEnabled(String mode) {
    return '已订阅 $mode';
  }

  @override
  String subscriptionDisabled(String mode) {
    return '已取消订阅 $mode';
  }

  @override
  String get genericAccess => 'Generic Access';

  @override
  String get genericAttribute => 'Generic Attribute';

  @override
  String get deviceName => 'Device Name';

  @override
  String get serviceChanged => 'Service Changed';

  @override
  String get webServiceUuids => 'Web 服务 UUID';

  @override
  String get webServiceUuidsHint => '每行一个 UUID，或使用逗号分隔';

  @override
  String get webServiceUuidsInvalid => '请输入有效的 16 位、32 位或 128 位 UUID。';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get communication => '通信';

  @override
  String get workspaceSettings => '工作区设置';

  @override
  String get deviceTools => '设备';

  @override
  String get dataView => '数据';

  @override
  String get editWorkspace => '编辑工作区';

  @override
  String get deviceModel => '设备型号';

  @override
  String get description => '描述';

  @override
  String get tags => '标签';

  @override
  String get workspaceDevices => '设备配置';

  @override
  String get sentPackets => '发送';

  @override
  String get receivedPackets => '接收';

  @override
  String get noPacketData => '暂无数据';

  @override
  String get noCommands => '当前工作区还没有指令。';

  @override
  String get editCommand => '编辑指令';

  @override
  String get deleteCommand => '删除指令';

  @override
  String get commandGroup => '分组';

  @override
  String get commandNotes => '备注';

  @override
  String get commandFormat => '数据格式';

  @override
  String get commandHex => 'HEX';

  @override
  String get commandText => '文本';

  @override
  String get commandEnabled => '启用';

  @override
  String get invalidCommandPayload => '请输入有效的数据内容。';

  @override
  String get configurationErrors => '请先修复以下问题：';

  @override
  String requiredField(String field) {
    return '$field为必填项';
  }

  @override
  String get invalidHexPayload => 'HEX 数据必须是完整字节。';

  @override
  String get invalidCommandParameters => '参数 key 必须存在，且占位符必须在数据内容中。';

  @override
  String get commandLibrary => '指令集';

  @override
  String get quickAccess => '快捷入口';

  @override
  String get noQuickCommands => '尚未选择快捷指令。';

  @override
  String get protocolProfiles => '协议定义';

  @override
  String get newProtocol => '新建协议';

  @override
  String get editProtocol => '编辑协议';

  @override
  String get deleteProtocol => '删除协议';

  @override
  String get noProtocolProfiles => '当前工作区还没有协议定义。';

  @override
  String get protocolName => '协议名称';

  @override
  String get protocolMode => '协议模式';

  @override
  String get protocolHeader => '协议头 HEX';

  @override
  String get protocolFooter => '协议尾 HEX';

  @override
  String get sendFrame => '发送帧';

  @override
  String get receiveFrame => '接收帧';

  @override
  String get lengthField => '长度字段';

  @override
  String get sequenceField => '包序号字段';

  @override
  String get checksumField => '校验字段';

  @override
  String get fieldOffset => '字段偏移';

  @override
  String get fieldByteLength => '字节长度';

  @override
  String get checksumAlgorithm => '校验算法';

  @override
  String get byteOrder => '字节序';

  @override
  String get calculationRange => '计算范围';

  @override
  String get payloadRange => '有效载荷';

  @override
  String get frameExcludingChecksum => '整帧（排除校验字段）';

  @override
  String get invalidProtocol => '请填写协议名称，并至少配置一项有效的帧规则。';

  @override
  String get newProtocolSegment => '新增片段';

  @override
  String get editProtocolSegment => '编辑片段';

  @override
  String get deleteProtocolSegment => '删除片段';

  @override
  String get noProtocolSegments => '尚未配置片段。';

  @override
  String get segmentType => '片段类型';

  @override
  String get segmentLabel => '片段名称';

  @override
  String get fixedHexSegment => '固定 HEX';

  @override
  String get payloadSegment => '实际数据';

  @override
  String get invalidProtocolSegment => '请填写有效的片段配置。';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get scriptProtocolMode => '脚本协议';

  @override
  String get editScriptConfig => '编辑脚本';

  @override
  String get scriptEnabled => '启用脚本协议模式';

  @override
  String get scriptEngineReady => '当前平台支持脚本运行时';

  @override
  String get scriptEngineUnavailable => '当前平台仅支持脚本编辑，不执行脚本';

  @override
  String get beforeSendScript => '发送前脚本';

  @override
  String get afterReceiveScript => '接收后脚本';

  @override
  String get loadProtocolSample => '装入样例协议脚本';

  @override
  String get scriptRuntime => '脚本运行时';

  @override
  String get scriptConfirmTransformedSend => '脚本改帧发送前确认';

  @override
  String get scriptConfirmTransformedSendHint =>
      '关闭后，脚本生成的最终帧会直接发送；高风险指令和指令的强制确认设置不受影响。';

  @override
  String get enabledState => '已启用';

  @override
  String get disabledState => '未启用';

  @override
  String get standardProtocol => '普通协议';

  @override
  String get standardProtocolHint =>
      '适用于可由固定 HEX、实际数据、长度、序号和校验字段描述的协议。按片段顺序配置，发送与接收可独立定义。';

  @override
  String get scriptProtocolHint =>
      '适用于加密、转义、动态 CRC、TLV 或自定义拆包等复杂协议。脚本接管完整数据帧的编码和解码。';

  @override
  String get scriptMethods => '必须实现的方法';

  @override
  String get beforeSendContract => '发送前调用。输入业务载荷 HEX，返回完整待发送帧 HEX。';

  @override
  String get afterReceiveContract => '接收后调用。输入完整接收帧 HEX，返回解码后的业务载荷和校验状态。';

  @override
  String get scriptBuiltins => '内置脚本工具';

  @override
  String get scriptBuiltinsHint =>
      '脚本运行时自动注入。校验函数返回无符号整数，哈希函数返回大写 HEX；value 可传 HEX 字符串或字节数组。';

  @override
  String get dataMappings => '数据映射';

  @override
  String get addResponseMapping => '新增响应映射';

  @override
  String get dataMappingHint => '接收后先由协议或脚本得到 CMD 和 DATA；字段偏移从 DATA 的第 0 字节开始。';

  @override
  String get noResponseMappings => '尚未配置响应映射。';

  @override
  String mappingFieldCount(String command, int count) {
    return 'CMD $command | $count 个字段';
  }

  @override
  String get newResponseMapping => '新增响应映射';

  @override
  String get editResponseMapping => '编辑响应映射';

  @override
  String get deleteResponseMapping => '删除响应映射';

  @override
  String get responseName => '响应名称';

  @override
  String get responseCommandHex => '响应 CMD HEX';

  @override
  String get responseFieldsHint => '字段（偏移相对于 DATA）';

  @override
  String get addDataField => '新增字段';

  @override
  String get responseAsciiLog => 'ASCII 日志转码';

  @override
  String get responseAsciiLogHint => '命中此响应时，过滤空字节和控制字符后额外记录 ASCII 文本。';

  @override
  String get invalidResponseMapping => '请输入响应名称、一个 CMD 字节和字段 key。';

  @override
  String asciiDecodedLog(String name, String value) {
    return 'ASCII $name: $value';
  }

  @override
  String get fieldKey => '字段 key';

  @override
  String get fieldLabel => '字段名称';

  @override
  String get deleteDataField => '删除字段';

  @override
  String get dataOffset => 'DATA 偏移';

  @override
  String get dataFieldType => '字段类型';

  @override
  String get numericScale => '比例';

  @override
  String get numericOffset => '数值偏移';

  @override
  String get unit => '单位';

  @override
  String get bitNumber => '位号';

  @override
  String get bitNumberHint => '从 0 开始';

  @override
  String get enumValues => '枚举值';

  @override
  String get enumValuesHint => '数值=显示名称，多个选项以逗号分隔';

  @override
  String get commandsAndData => '指令与数据';

  @override
  String get mappedData => '映射数据';

  @override
  String get noMappedFields => '尚未选择要显示的映射字段。';

  @override
  String get showInDataPanel => '显示在数据面板';

  @override
  String commandLog(String name, String parameters) {
    return '指令 $name: $parameters';
  }

  @override
  String responseLog(String name, String command, String values) {
    return '响应 $name（CMD $command）: $values';
  }

  @override
  String get protocolCandidateImport => '导入 AI 协议候选草案';

  @override
  String get protocolCandidateImportHint =>
      '仅导入候选 JSON；需完成校验与逐项审查后才会创建新的草案工作区。';

  @override
  String get protocolCandidateP0Notice => 'P0 仅接受人工构造的候选 JSON，不调用模型或设备。';

  @override
  String get protocolCandidateJson => '候选草案 JSON';

  @override
  String get checkCandidate => '检查候选';

  @override
  String get enterReview => '进入审查';

  @override
  String get reviewProtocolCandidate => '审查协议候选草案';

  @override
  String get reviewLater => '稍后继续';

  @override
  String get revalidate => '重新校验';

  @override
  String get createDraftWorkspace => '生成草案工作区';

  @override
  String get candidateDraftCreated => '已创建新的 AI 导入草案工作区；脚本保持禁用。';

  @override
  String get candidateCurrentWorkspaceSafe => '当前工作区不会被覆盖，也不会连接或发送设备数据。';

  @override
  String get candidateRequiresReview => '此操作不会修改当前工作区；下一步仅进入独立审查任务。';

  @override
  String get candidateStatusCreated => '待校验';

  @override
  String get candidateStatusReview => '待审查';

  @override
  String get candidateStatusBlocked => '已阻止';

  @override
  String get candidateStatusReady => '可生成草案';

  @override
  String get candidateStatusApplied => '已生成草案';

  @override
  String get candidateAccept => '接受';

  @override
  String get candidateReject => '拒绝';

  @override
  String candidateEvidence(String value) {
    return '证据：$value';
  }

  @override
  String candidateAssumptions(String value) {
    return '假设：$value';
  }

  @override
  String get editCandidateJson => '编辑候选 JSON';

  @override
  String get updateCandidate => '检查并更新';

  @override
  String get resumeCandidateReview => '继续未完成审查';

  @override
  String get protocolTextImport => '从协议文本生成候选';

  @override
  String get protocolTextImportHint =>
      '粘贴 TXT 或 Markdown，使用你的 OpenAI-compatible API Key 生成候选；结果仍需本地校验和逐项审查。';

  @override
  String get modelConnection => '模型连接';

  @override
  String get apiKey => 'API Key';

  @override
  String get generateCandidate => '生成候选';

  @override
  String get generatingCandidate => '正在生成候选…';

  @override
  String get generatingCandidateHint => '正在请求模型并校验证据与候选，请勿关闭此窗口。';

  @override
  String protocolCandidateImportFailed(String error) {
    return '导入候选失败：$error';
  }

  @override
  String get protocolImportFailed => '生成候选失败，请检查模型连接后重试。';

  @override
  String get protocolSourceText => '协议文本';
}
