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
  String get themeMode => '主题模式';

  @override
  String get language => '语言';

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
  String get clear => '清空';

  @override
  String get autoScroll => '自动滚动';

  @override
  String get sendData => '发送数据';

  @override
  String get inputPlaceholder => '输入要发送的数据...';

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
  String get service => '服务';

  @override
  String get disconnected => '未连接';

  @override
  String get writeTarget => '写入目标';

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
}
