import '../workspace.dart';

class WorkspaceDraft {
  const WorkspaceDraft({
    required this.id,
    required this.jobId,
    required this.createdAt,
    required this.workspace,
  });

  final String id;
  final String jobId;
  final DateTime createdAt;
  final Workspace workspace;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'jobId': jobId,
    'createdAt': createdAt.toIso8601String(),
    'workspace': workspace.toJson(),
  };
}
