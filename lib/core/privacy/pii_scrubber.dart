class PiiScrubber {
  /// Pre-compiled regex patterns to prevent recompilation on every call.
  static final List<RegExp> _patterns = [
    // Email addresses
    RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
    
    // Credit Cards (16-digit Visa/MC/Discover with optional spaces/dashes)
    RegExp(r'\b(?:\d{4}[-\s]?){3}\d{4}\b'),
    
    // Credit Cards (15-digit Amex)
    RegExp(r'\b3[47]\d{2}[-\s]?\d{6}[-\s]?\d{5}\b'),
    
    // US SSN (Social Security Number)
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    
    // 9-digit numbers (Routing numbers, formatting-free SSN/SIN)
    RegExp(r'\b\d{3}[-\s]?\d{3}[-\s]?\d{3}\b'),
    
    // Phone numbers (US/CAN standard formats)
    RegExp(r'(?:1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),
    
    // 11-digit numbers (e.g., raw phone numbers starting with 1)
    RegExp(r'\b1\d{10}\b'),
    
    // UK National Insurance Number
    RegExp(r'\b[A-CEGHJ-PR-TW-Z]{2}\d{6}[A-D]\b', caseSensitive: false),
    
    // IBAN (International Bank Account Number)
    RegExp(r'\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b', caseSensitive: false),
    
    // IPv4 Addresses
    RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
    
    // Cryptocurrency Wallets (Ethereum - 40 hex chars after 0x)
    RegExp(r'\b0x[a-fA-F0-9]{40}\b', caseSensitive: false),
    
    // Cryptocurrency Wallets (Bitcoin - basic P2PKH/P2SH catch)
    RegExp(r'\b[13][a-km-zA-HJ-NP-Z1-9]{25,34}\b'),
  ];

  /// Redacts common PII patterns from free-text input before transmission.
  static String scrub(String input) {
    if (input.isEmpty) return input;
    
    var result = input;
    for (final pattern in _patterns) {
      result = result.replaceAll(pattern, '[REDACTED]');
    }
    
    return result;
  }
}