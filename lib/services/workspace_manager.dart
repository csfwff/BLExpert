import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace.dart';

/// Keeps the current list of workspaces in memory and prepares them for local
/// persistence or export/import.
class WorkspaceManager {
  WorkspaceManager({SharedPreferences? preferences}) {
    _preferences = preferences;
    _workspaces = <Workspace>[Workspace.empty()];
    _activeWorkspaceId = _workspaces.first.id;
  }

  static const String _storageKey = 'blexpert.workspace-store.v1';

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
    final int index = _workspaces.indexWhere((Workspace item) => item.id == workspace.id);
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

    _workspaces = _workspaces.where((Workspace item) => item.id != workspaceId).toList(growable: false);
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
    importWorkspaces(jsonText);
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
      'version': 1,
      'activeWorkspaceId': _activeWorkspaceId,
      'workspaces': _workspaces.map((Workspace workspace) => workspace.toJson()).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void importWorkspaces(String jsonText) {
    final Map<String, dynamic> payload = json.decode(jsonText) as Map<String, dynamic>;
    final List<dynamic> rawWorkspaces = payload['workspaces'] as List<dynamic>? ?? const <dynamic>[];

    _workspaces = rawWorkspaces
        .map((dynamic item) => Workspace.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);

    if (_workspaces.isEmpty) {
      _workspaces = <Workspace>[Workspace.empty()];
    }

    final String candidateId = payload['activeWorkspaceId'] as String? ?? _workspaces.first.id;
    _activeWorkspaceId = _workspaces.any((Workspace workspace) => workspace.id == candidateId)
        ? candidateId
        : _workspaces.first.id;
  }
}
