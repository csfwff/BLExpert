enum ValidationIssueSeverity { error, warning, info }

class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.path,
    required this.message,
    this.candidateId,
  });

  final String code;
  final ValidationIssueSeverity severity;
  final String path;
  final String message;
  final String? candidateId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'severity': severity.name,
    'path': path,
    'message': message,
    if (candidateId != null) 'candidateId': candidateId,
  };
}

class ValidationReport {
  const ValidationReport({required this.issues, required this.validatedAt});

  final List<ValidationIssue> issues;
  final DateTime validatedAt;

  bool get hasErrors => issues.any(
    (ValidationIssue item) => item.severity == ValidationIssueSeverity.error,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'issues': issues.map((ValidationIssue item) => item.toJson()).toList(),
    'validatedAt': validatedAt.toIso8601String(),
  };
}
