/// Confidence is intentionally independent from validation: an item can be
/// structurally valid while still requiring a human to verify its evidence.
enum CandidateConfidence { high, medium, low }

enum CandidateRiskLevel { normal, warning, dangerous }

enum CandidateReviewStatus { pending, accepted, rejected, edited }

/// A single proposal that may be reviewed before it reaches a runnable
/// workspace. [value] is kept separate from review metadata on purpose.
class CandidateItem<T> {
  const CandidateItem({
    required this.id,
    required this.value,
    required this.evidenceRefs,
    required this.confidence,
    required this.assumptions,
    required this.riskLevel,
    required this.reviewStatus,
  });

  final String id;
  final T value;
  final List<String> evidenceRefs;
  final CandidateConfidence confidence;
  final List<String> assumptions;
  final CandidateRiskLevel riskLevel;
  final CandidateReviewStatus reviewStatus;

  CandidateItem<T> copyWith({
    T? value,
    List<String>? evidenceRefs,
    CandidateConfidence? confidence,
    List<String>? assumptions,
    CandidateRiskLevel? riskLevel,
    CandidateReviewStatus? reviewStatus,
  }) {
    return CandidateItem<T>(
      id: id,
      value: value ?? this.value,
      evidenceRefs: evidenceRefs ?? this.evidenceRefs,
      confidence: confidence ?? this.confidence,
      assumptions: assumptions ?? this.assumptions,
      riskLevel: riskLevel ?? this.riskLevel,
      reviewStatus: reviewStatus ?? this.reviewStatus,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value) valueToJson) {
    return <String, dynamic>{
      'id': id,
      'value': valueToJson(value),
      'evidenceRefs': evidenceRefs,
      'confidence': confidence.name,
      'assumptions': assumptions,
      'riskLevel': riskLevel.name,
      'reviewStatus': reviewStatus.name,
    };
  }
}
