import 'dart:convert';

import 'device_profile.dart';

/// 一类蓝牙设备的完整调试工作区。
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.deviceModel,
    required this.description,
    required this.tags,
    required this.devices,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String deviceModel;
  final String description;
  final List<String> tags;
  final List<DeviceProfile> devices;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Workspace.empty() {
    final DateTime now = DateTime.now();
    return Workspace(
      id: 'workspace-default',
      name: '默认工作区',
      deviceModel: '未知设备',
      description: 'BLExpert 初始调试工作区。',
      tags: const <String>['入门', '蓝牙'],
      devices: const <DeviceProfile>[],
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      deviceModel: json['deviceModel'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      devices: (json['devices'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => DeviceProfile.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'deviceModel': deviceModel,
      'description': description,
      'tags': tags,
      'devices': devices.map((DeviceProfile item) => item.toJson()).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Workspace copyWith({
    String? id,
    String? name,
    String? deviceModel,
    String? description,
    List<String>? tags,
    List<DeviceProfile>? devices,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceModel: deviceModel ?? this.deviceModel,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      devices: devices ?? this.devices,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
