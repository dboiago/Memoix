/// Structured result from an AI service call.
///
/// Wraps either a successful parsed JSON response or a typed error so the
/// UI never needs to catch raw exceptions.
class AiResponse {
  /// The parsed JSON body on success.
  final Map<String, dynamic>? data;

  /// A user-facing error description when [isSuccess] is `false`.
  final String? errorMessage;

  /// Machine-readable error type for UI branching.
  final AiErrorType? errorType;

  const AiResponse.success(this.data)
      : errorMessage = null,
        errorType = null,
        rawError = null;

  const AiResponse.error(this.errorMessage, this.errorType, {this.rawError})
      : data = null;

  /// Full technical error text (raw API JSON) for clipboard copy.
  /// Only present on error responses where a parseable body was available.
  final String? rawError;

  bool get isSuccess => data != null && errorType == null;
}

/// Categorised error types the UI can react to.
enum AiErrorType {
  /// No API key configured.
  noToken,

  /// The key was rejected (HTTP 401 / 403).
  invalidToken,

  /// Rate-limited (HTTP 429).
  rateLimited,

  /// Network unreachable / DNS failure.
  noInternet,

  /// The request or response timed out.
  timeout,

  /// Response exceeded the safety limit.
  responseTooLarge,

  /// The provider returned unparseable content.
  malformedResponse,

  /// AI feature is disabled in settings.
  disabled,

  /// Catch-all.
  unknown,
}
