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
}
