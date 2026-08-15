/// Returns printable ASCII characters from a byte sequence.
///
/// NUL and other control bytes are deliberately omitted so fixed-size,
/// zero-padded firmware strings remain readable in the log.
String printableAscii(List<int> bytes) => String.fromCharCodes(
  bytes.where((int byte) => byte >= 0x20 && byte <= 0x7E),
);
