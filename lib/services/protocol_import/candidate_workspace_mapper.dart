import '../../models/protocol_import/candidate_item.dart';
import '../../models/protocol_import/protocol_import_job.dart';
import '../../models/script_config.dart';
import '../../models/workspace.dart';

/// Converts only accepted, locally validated candidates to a new runnable
/// workspace. It never receives or mutates the active workspace.
class CandidateWorkspaceMapper {
  Workspace mapToDraft(ProtocolImportJob job) {
    final accepted = CandidateReviewStatus.accepted;
    final metadata = job.candidateWorkspace.metadata;
    if (metadata.reviewStatus != accepted) {
      throw StateError('工作区元信息尚未接受。');
    }
    final protocols = job.candidateWorkspace.protocols
        .where((item) => item.reviewStatus == accepted)
        .toList(growable: false);
    if (protocols.length > 1) {
      throw StateError('P0 草案仅支持一个已接受的协议定义。');
    }
    final DateTime now = DateTime.now().toUtc();
    return Workspace(
      id: 'ai-import-${now.microsecondsSinceEpoch.toRadixString(36)}',
      name: metadata.value.name.trim(),
      deviceModel: metadata.value.deviceModel.trim(),
      description:
          '${metadata.value.description.trim()}\n\n来源：AI 导入草案 ${job.id}'.trim(),
      tags: List<String>.unmodifiable(<String>[
        ...metadata.value.tags,
        'AI 草案',
      ]),
      devices: List.unmodifiable(
        job.candidateWorkspace.devices
            .where((item) => item.reviewStatus == accepted)
            .map((item) => item.value),
      ),
      protocol: protocols.isEmpty
          ? Workspace.empty().protocol
          : protocols.single.value,
      scriptConfig: _untrustedScript(job),
      commands: List.unmodifiable(
        job.candidateWorkspace.commands
            .where((item) => item.reviewStatus == accepted)
            .map((item) => item.value.copyWith(isQuickAccess: false)),
      ),
      allowedCommandIds: const <String>[],
      responseMappings: List.unmodifiable(
        job.candidateWorkspace.responseMappings
            .where((item) => item.reviewStatus == accepted)
            .map((item) => item.value),
      ),
      createdAt: now,
      updatedAt: now,
    );
  }

  ScriptConfig _untrustedScript(ProtocolImportJob job) {
    final scripts = job.candidateWorkspace.scripts
        .where((item) => item.reviewStatus == CandidateReviewStatus.accepted)
        .toList(growable: false);
    if (scripts.isEmpty) {
      return ScriptConfig.empty();
    }
    final ScriptConfig script = scripts.first.value;
    return script.copyWith(
      enabled: false,
      trustState: ScriptTrustState.importedUntrusted,
      source: 'AI import draft',
    );
  }
}
