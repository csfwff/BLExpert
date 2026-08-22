import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/protocol_import/model_connection.dart';

class ModelProviderException implements Exception {
  const ModelProviderException(this.message);

  /// Safe for UI presentation: never includes a credential, document text, or
  /// arbitrary response payload.
  final String message;

  @override
  String toString() => message;
}

class ModelJsonRequest {
  const ModelJsonRequest({
    required this.connection,
    required this.apiKey,
    required this.systemPrompt,
    required this.userPrompt,
  });

  final ModelConnection connection;
  final String apiKey;
  final String systemPrompt;
  final String userPrompt;
}

abstract class ModelProviderAdapter {
  Future<Map<String, dynamic>> generateJson(ModelJsonRequest request);
}

/// Narrow OpenAI Chat Completions adapter used by P1. It has no access to BLE,
/// workspace persistence, or script execution; it only returns untrusted JSON.
class OpenAiCompatibleAdapter implements ModelProviderAdapter {
  OpenAiCompatibleAdapter({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<String, dynamic>> generateJson(ModelJsonRequest request) async {
    if (request.connection.provider !=
        ModelConnectionProvider.openAiCompatible) {
      throw const ModelProviderException('当前模型提供方不受支持。');
    }
    if (request.apiKey.trim().isEmpty) {
      throw const ModelProviderException('请先提供 API Key。');
    }
    final Uri endpoint = _chatCompletionsUri(request.connection.baseUrl);
    try {
      final http.Response response = await _client
          .post(
            endpoint,
            headers: <String, String>{
              'Authorization': 'Bearer ${request.apiKey}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'model': request.connection.model,
              'temperature': 0,
              'response_format': <String, String>{'type': 'json_object'},
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'system',
                  'content': request.systemPrompt,
                },
                <String, String>{'role': 'user', 'content': request.userPrompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ModelProviderException('模型服务请求失败（HTTP ${response.statusCode}）。');
      }
      final Object? decoded = _decode(response.body);
      if (decoded is! Map) {
        throw const ModelProviderException('模型服务返回了无效响应。');
      }
      final Object? choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const ModelProviderException('模型服务未返回候选结果。');
      }
      final Object? message = (choices.first as Map)['message'];
      if (message is! Map || message['content'] is! String) {
        throw const ModelProviderException('模型服务未返回文本结果。');
      }
      final Object? result = _decodeJsonObject(
        (message['content'] as String).trim(),
      );
      if (result is! Map) {
        throw const ModelProviderException('模型结果不是 JSON 对象。');
      }
      return Map<String, dynamic>.from(result);
    } on ModelProviderException {
      rethrow;
    } on FormatException {
      throw const ModelProviderException('模型服务返回了无法解析的 JSON。');
    } on TimeoutException {
      throw const ModelProviderException('模型服务响应超时，请稍后重试。');
    } on http.ClientException {
      throw const ModelProviderException('无法连接模型服务，请检查地址与网络。');
    }
  }

  Uri _chatCompletionsUri(String baseUrl) {
    final Uri base;
    try {
      base = Uri.parse(baseUrl.trim());
    } on FormatException {
      throw const ModelProviderException('模型服务地址无效。');
    }
    final bool local = base.host == 'localhost' || base.host == '127.0.0.1';
    if ((base.scheme != 'https' && !(local && base.scheme == 'http')) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const ModelProviderException('模型服务地址必须是 HTTPS 地址（本机服务可使用 HTTP）。');
    }
    final List<String> segments = base.pathSegments
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: true);
    if (segments.length < 2 ||
        segments[segments.length - 2] != 'chat' ||
        segments.last != 'completions') {
      segments.addAll(<String>['chat', 'completions']);
    }
    return base.replace(pathSegments: segments);
  }

  Object? _decode(String value) => jsonDecode(value);

  Object? _decodeJsonObject(String value) {
    String normalized = value;
    if (normalized.startsWith('```')) {
      final int firstNewline = normalized.indexOf('\n');
      final int closing = normalized.lastIndexOf('```');
      if (firstNewline > 0 && closing > firstNewline) {
        normalized = normalized.substring(firstNewline + 1, closing).trim();
      }
    }
    return jsonDecode(normalized);
  }
}
