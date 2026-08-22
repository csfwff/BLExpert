import 'candidate_workspace.dart';
import 'import_evidence.dart';
import 'validation_report.dart';

enum ProtocolImportJobStatus {
  created,
  validated,
  underReview,
  blocked,
  readyToApply,
  applied,
}

class ProtocolImportSource {
  const ProtocolImportSource({
    required this.name,
    required this.hash,
    required this.importedAt,
  });

  final String name;
  final String hash;
  final DateTime importedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'hash': hash,
    'importedAt': importedAt.toIso8601String(),
  };
}

class ProtocolImportJob {
  const ProtocolImportJob({
    required this.id,
    required this.schemaVersion,
    required this.source,
    required this.evidence,
    required this.questions,
    required this.candidateWorkspace,
    required this.status,
    this.validationReport,
  });

  static const int currentSchemaVersion = 1;

  final String id;
  final int schemaVersion;
  final ProtocolImportSource source;
  final List<ImportEvidence> evidence;
  final List<ImportQuestion> questions;
  final CandidateWorkspace candidateWorkspace;
  final ProtocolImportJobStatus status;
  final ValidationReport? validationReport;

  ProtocolImportJob copyWith({
    List<ImportQuestion>? questions,
    CandidateWorkspace? candidateWorkspace,
    ProtocolImportJobStatus? status,
    ValidationReport? validationReport,
    bool clearValidationReport = false,
  }) => ProtocolImportJob(
    id: id,
    schemaVersion: schemaVersion,
    source: source,
    evidence: evidence,
    questions: questions ?? this.questions,
    candidateWorkspace: candidateWorkspace ?? this.candidateWorkspace,
    status: status ?? this.status,
    validationReport: clearValidationReport
        ? null
        : (validationReport ?? this.validationReport),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'schemaVersion': schemaVersion,
    'source': source.toJson(),
    'evidence': evidence.map((ImportEvidence item) => item.toJson()).toList(),
    'questions': questions.map((ImportQuestion item) => item.toJson()).toList(),
    'candidateWorkspace': candidateWorkspace.toJson(),
    'status': status.name,
    if (validationReport != null)
      'validationReport': validationReport!.toJson(),
  };
}
