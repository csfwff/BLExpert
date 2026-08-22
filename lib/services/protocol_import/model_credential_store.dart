import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores API keys outside preferences and all import/workspace JSON.
///
/// On Web an API key is deliberately memory-only for the current app session.
/// On mobile and desktop the platform secure storage implementation is used.
class ModelCredentialStore {
  ModelCredentialStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static final Map<String, String> _webSessionKeys = <String, String>{};
  final FlutterSecureStorage _secureStorage;

  String _storageKey(String connectionId) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(connectionId)) {
      throw const FormatException('模型连接 ID 格式无效。');
    }
    return 'blexpert.model-credential.v1.$connectionId';
  }

  Future<void> write(String connectionId, String apiKey) async {
    if (apiKey.trim().isEmpty) throw const FormatException('API Key 不能为空。');
    final String key = _storageKey(connectionId);
    if (kIsWeb) {
      _webSessionKeys[key] = apiKey;
      return;
    }
    await _secureStorage.write(key: key, value: apiKey);
  }

  Future<String?> read(String connectionId) async {
    final String key = _storageKey(connectionId);
    if (kIsWeb) return _webSessionKeys[key];
    return _secureStorage.read(key: key);
  }

  Future<void> delete(String connectionId) async {
    final String key = _storageKey(connectionId);
    if (kIsWeb) {
      _webSessionKeys.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }
}
