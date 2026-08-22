enum ModelConnectionProvider { openAiCompatible }

/// Non-secret connection metadata. API keys intentionally live outside this
/// model so it is safe to persist, export independently, and show in the UI.
class ModelConnection {
  const ModelConnection({
    required this.id,
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final ModelConnectionProvider provider;
  final String baseUrl;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;

  ModelConnection copyWith({
    String? name,
    ModelConnectionProvider? provider,
    String? baseUrl,
    String? model,
    DateTime? updatedAt,
  }) => ModelConnection(
    id: id,
    name: name ?? this.name,
    provider: provider ?? this.provider,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'provider': provider.name,
    'baseUrl': baseUrl,
    'model': model,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ModelConnection fromJson(Map<String, dynamic> json) {
    String string(String key) {
      final Object? value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('模型连接 $key 必须是非空字符串。');
      }
      return value.trim();
    }

    DateTime date(String key) {
      final DateTime? value = DateTime.tryParse(string(key));
      if (value == null) throw FormatException('模型连接 $key 必须是 ISO-8601 时间。');
      return value;
    }

    final String providerName = string('provider');
    final ModelConnectionProvider provider =
        ModelConnectionProvider.values
            .where((ModelConnectionProvider item) => item.name == providerName)
            .firstOrNull ??
        (throw FormatException('不支持的模型提供方：$providerName。'));
    return ModelConnection(
      id: string('id'),
      name: string('name'),
      provider: provider,
      baseUrl: string('baseUrl'),
      model: string('model'),
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }
}
