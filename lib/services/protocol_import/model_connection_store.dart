import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/protocol_import/model_connection.dart';

/// Persists only displayable connection metadata. Secrets are managed by
/// [ModelCredentialStore] and must never share this storage key.
class ModelConnectionStore {
  ModelConnectionStore({this.preferences});

  static const String storageKey = 'blexpert.model-connections.v1';
  SharedPreferences? preferences;

  Future<List<ModelConnection>> load() async {
    preferences ??= await SharedPreferences.getInstance();
    final String? raw = preferences!.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <ModelConnection>[];
    final Object? decoded = json.decode(raw);
    if (decoded is! Map || decoded['connections'] is! List) {
      throw const FormatException('模型连接存储格式无效。');
    }
    final List<ModelConnection> result = (decoded['connections'] as List)
        .map((Object? item) {
          if (item is! Map) {
            throw const FormatException('模型连接条目格式无效。');
          }
          return ModelConnection.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    final Set<String> ids = <String>{};
    for (final ModelConnection item in result) {
      if (!ids.add(item.id)) throw FormatException('模型连接 ID 重复：${item.id}。');
    }
    return result;
  }

  Future<void> save(List<ModelConnection> connections) async {
    final Set<String> ids = connections
        .map((ModelConnection item) => item.id)
        .toSet();
    if (ids.length != connections.length) {
      throw const FormatException('模型连接 ID 重复。');
    }
    preferences ??= await SharedPreferences.getInstance();
    final bool saved = await preferences!.setString(
      storageKey,
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'version': 1,
        'connections': connections
            .map((ModelConnection item) => item.toJson())
            .toList(),
      }),
    );
    if (!saved) throw StateError('无法保存模型连接。');
  }
}
