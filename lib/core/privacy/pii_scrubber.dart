class PiiScrubber {
  /// Redacts common PII patterns from free-text input before transmission.
  static String scrub(String input) {
    var result = input;

    result = result.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'\b\d{3}[-\s]?\d{3}[-\s]?\d{3}\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'(?:1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'\b1\d{10}\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'\b[A-CEGHJ-PR-TW-Z]{2}\d{6}[A-D]\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b'),
      '[REDACTED]',
    );

    result = result.replaceAll(
      RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
      '[REDACTED]',
    );

    return result;
  }
}
