enum ImportQuestionSeverity { info, warning, blocking }

class ImportEvidence {
  const ImportEvidence({
    required this.id,
    required this.excerpt,
    required this.location,
    required this.sourceHash,
  });

  final String id;
  final String excerpt;
  final String location;
  final String sourceHash;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'excerpt': excerpt,
    'location': location,
    'sourceHash': sourceHash,
  };
}

class ImportQuestion {
  const ImportQuestion({
    required this.id,
    required this.question,
    required this.severity,
    required this.candidateIds,
    required this.isAnswered,
  });

  final String id;
  final String question;
  final ImportQuestionSeverity severity;
  final List<String> candidateIds;
  final bool isAnswered;

  ImportQuestion copyWith({bool? isAnswered}) => ImportQuestion(
    id: id,
    question: question,
    severity: severity,
    candidateIds: candidateIds,
    isAnswered: isAnswered ?? this.isAnswered,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'question': question,
    'severity': severity.name,
    'candidateIds': candidateIds,
    'isAnswered': isAnswered,
  };
}
