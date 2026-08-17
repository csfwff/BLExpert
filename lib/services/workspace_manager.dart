import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace.dart';
import '../models/script_config.dart';

enum WorkspaceImportMode { replace, merge }

enum WorkspaceConflictPolicy { replaceExisting, keepExisting }

class WorkspaceImportPreview {
  const WorkspaceImportPreview({
    required this.sourceVersion,
    required this.version,
    required this.workspaces,
    required this.activeWorkspaceId,
    required this.conflictingWorkspaceIds,
    required this.scriptedWorkspaceCount,
  });

  final int sourceVersion;
  final int version;
  final List<Workspace> workspaces;
  final String activeWorkspaceId;
  final List<String> conflictingWorkspaceIds;
  final int scriptedWorkspaceCount;

  bool get migrationApplied => sourceVersion != version;
}

class _WorkspacePayload {
  const _WorkspacePayload({required this.payload, required this.sourceVersion});

  final Map<String, dynamic> payload;
  final int sourceVersion;

  bool get migrationApplied =>
      sourceVersion != WorkspaceManager.currentFormatVersion;
}

/// Keeps the current list of workspaces in memory and prepares them for local
/// persistence or export/import.
class WorkspaceManager {
  WorkspaceManager({SharedPreferences? preferences}) {
    _preferences = preferences;
    _workspaces = <Workspace>[Workspace.empty()];
    _activeWorkspaceId = _workspaces.first.id;
  }

  static const String _storageKey = 'blexpert.workspace-store.v1';
  static const int currentFormatVersion = 2;

  late List<Workspace> _workspaces;
  late String _activeWorkspaceId;
  SharedPreferences? _preferences;

  List<Workspace> get workspaces => List<Workspace>.unmodifiable(_workspaces);

  Workspace get activeWorkspace {
    return _workspaces.firstWhere(
      (Workspace workspace) => workspace.id == _activeWorkspaceId,
      orElse: () => _workspaces.first,
    );
  }

  void setActiveWorkspace(String workspaceId) {
    if (_workspaces.any((Workspace workspace) => workspace.id == workspaceId)) {
      _activeWorkspaceId = workspaceId;
    }
  }

  void upsertWorkspace(Workspace workspace) {
    final int index = _workspaces.indexWhere(
      (Workspace item) => item.id == workspace.id,
    );
    if (index >= 0) {
      _workspaces[index] = workspace;
    } else {
      _workspaces = <Workspace>[..._workspaces, workspace];
    }

    _activeWorkspaceId = workspace.id;
  }

  void removeWorkspace(String workspaceId) {
    if (_workspaces.length == 1 && _workspaces.first.id == workspaceId) {
      return;
    }

    _workspaces = _workspaces
        .where((Workspace item) => item.id != workspaceId)
        .toList(growable: false);
    if (_activeWorkspaceId == workspaceId && _workspaces.isNotEmpty) {
      _activeWorkspaceId = _workspaces.first.id;
    }
  }

  /// Loads every persisted workspace and restores the active workspace ID.
  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    final String? jsonText = _preferences!.getString(_storageKey);
    if (jsonText == null || jsonText.trim().isEmpty) {
      return;
    }
    final _WorkspacePayload parsed = _parsePayload(jsonText);
    _restoreWorkspaces(parsed.payload);
    if (parsed.migrationApplied) {
      await _preferences!.setString(_storageKey, exportWorkspaces());
    }
  }

  /// Persists protocols, script configuration, commands and workspace metadata.
  Future<void> save() async {
    _preferences ??= await SharedPreferences.getInstance();
    final bool saved = await _preferences!.setString(
      _storageKey,
      exportWorkspaces(),
    );
    if (!saved) {
      throw StateError('Unable to save workspace configuration.');
    }
  }

  String exportWorkspaces() {
    final Map<String, dynamic> payload = <String, dynamic>{
      'version': currentFormatVersion,
      'activeWorkspaceId': _activeWorkspaceId,
      'workspaces': _workspaces
          .map((Workspace workspace) => workspace.toJson())
          .toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void importWorkspaces(
    String jsonText, {
    WorkspaceImportMode mode = WorkspaceImportMode.replace,
    WorkspaceConflictPolicy conflictPolicy =
        WorkspaceConflictPolicy.replaceExisting,
  }) {
    final WorkspaceImportPreview preview = previewImport(jsonText);
    final List<Workspace> importedWorkspaces = preview.workspaces
        .map(
          (Workspace workspace) => workspace.copyWith(
            scriptConfig: workspace.scriptConfig.copyWith(
              enabled: false,
              trustState: ScriptTrustState.importedUntrusted,
              source: 'imported JSON',
            ),
          ),
        )
        .toList(growable: false);
    if (mode == WorkspaceImportMode.replace) {
      _workspaces = importedWorkspaces;
      _activeWorkspaceId = preview.activeWorkspaceId;
      return;
    }

    final List<Workspace> merged = List<Workspace>.from(_workspaces);
    for (final Workspace workspace in importedWorkspaces) {
      final int index = merged.indexWhere(
        (Workspace current) => current.id == workspace.id,
      );
      if (index < 0) {
        merged.add(workspace);
      } else if (conflictPolicy == WorkspaceConflictPolicy.replaceExisting) {
        merged[index] = workspace;
      }
    }
    _workspaces = merged;
    if (merged.any(
      (Workspace workspace) => workspace.id == preview.activeWorkspaceId,
    )) {
      _activeWorkspaceId = preview.activeWorkspaceId;
    }
  }

  /// Validates an external export without mutating the current configuration.
  WorkspaceImportPreview previewImport(String jsonText) {
    final _WorkspacePayload parsed = _parsePayload(jsonText);
    final Map<String, dynamic> payload = parsed.payload;
    final Object? rawWorkspaces = payload['workspaces'];
    if (rawWorkspaces is! List || rawWorkspaces.isEmpty) {
      throw const FormatException('导入内容至少需要一个工作区。');
    }
    final List<Workspace> workspaces = <Workspace>[
      for (final Object? rawWorkspace in rawWorkspaces)
        if (rawWorkspace is Map)
          Workspace.fromJson(Map<String, dynamic>.from(rawWorkspace))
        else
          throw const FormatException('工作区条目必须是对象。'),
    ];
    final Set<String> importedIds = <String>{};
    for (final Workspace workspace in workspaces) {
      if (workspace.id.trim().isEmpty || workspace.name.trim().isEmpty) {
        throw const FormatException('每个工作区都需要 ID 和名称。');
      }
      if (!importedIds.add(workspace.id)) {
        throw FormatException('导入内容包含重复工作区 ID：${workspace.id}。');
      }
    }
    final String candidateId =
        payload['activeWorkspaceId'] as String? ?? workspaces.first.id;
    final String activeWorkspaceId = importedIds.contains(candidateId)
        ? candidateId
        : workspaces.first.id;
    final Set<String> existingIds = _workspaces
        .map((Workspace workspace) => workspace.id)
        .toSet();
    return WorkspaceImportPreview(
      sourceVersion: parsed.sourceVersion,
      version: currentFormatVersion,
      workspaces: List<Workspace>.unmodifiable(workspaces),
      activeWorkspaceId: activeWorkspaceId,
      conflictingWorkspaceIds: workspaces
          .map((Workspace workspace) => workspace.id)
          .where(existingIds.contains)
          .toList(growable: false),
      scriptedWorkspaceCount: workspaces
          .where(
            (Workspace workspace) =>
                workspace.scriptConfig.beforeSendScript.trim().isNotEmpty ||
                workspace.scriptConfig.afterReceiveScript.trim().isNotEmpty,
          )
          .length,
    );
  }

  _WorkspacePayload _parsePayload(String jsonText) {
    final Object? decoded;
    try {
      decoded = json.decode(jsonText);
    } on FormatException {
      throw const FormatException('导入内容不是有效 JSON。');
    }
    if (decoded is! Map) {
      throw const FormatException('导入内容必须是工作区对象。');
    }
    Map<String, dynamic> payload = Map<String, dynamic>.from(decoded);
    final Object? rawVersion = payload['version'];
    if (rawVersion != null && rawVersion is! int) {
      throw const FormatException('工作区版本必须是整数。');
    }
    final int sourceVersion = rawVersion as int? ?? 1;
    if (sourceVersion < 1 || sourceVersion > currentFormatVersion) {
      throw FormatException('不支持的工作区版本：$sourceVersion。');
    }
    if (sourceVersion == 1) {
      final Object? rawWorkspaces = payload['workspaces'];
      if (rawWorkspaces is List) {
        payload = <String, dynamic>{
          ...payload,
          'version': currentFormatVersion,
          'workspaces': rawWorkspaces
              .map(
                (Object? item) => item is Map
                    ? Workspace.fromJson(
                        Map<String, dynamic>.from(item),
                      ).toJson()
                    : item,
              )
              .toList(growable: false),
        };
      } else {
        payload = <String, dynamic>{
          ...payload,
          'version': currentFormatVersion,
        };
      }
    }
    return _WorkspacePayload(payload: payload, sourceVersion: sourceVersion);
  }

  void _restoreWorkspaces(Map<String, dynamic> payload) {
    final List<dynamic> rawWorkspaces =
        payload['workspaces'] as List<dynamic>? ?? const <dynamic>[];

    _workspaces = rawWorkspaces
        .map(
          (dynamic item) =>
              Workspace.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);

    if (_workspaces.isEmpty) {
      _workspaces = <Workspace>[Workspace.empty()];
    }

    final String candidateId =
        payload['activeWorkspaceId'] as String? ?? _workspaces.first.id;
    _activeWorkspaceId =
        _workspaces.any((Workspace workspace) => workspace.id == candidateId)
        ? candidateId
        : _workspaces.first.id;
  }
}
