enum ProtocolDocumentFormat { plainText, markdown }

/// In-memory P1 document input. Its full text is never written into a
/// workspace, import job, application log, or model connection record.
class ProtocolTextDocument {
  const ProtocolTextDocument({
    required this.name,
    required this.text,
    required this.format,
  });

  final String name;
  final String text;
  final ProtocolDocumentFormat format;
}
