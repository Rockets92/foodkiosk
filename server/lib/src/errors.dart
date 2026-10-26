/// An error caused by the request, mapped to a 4xx response with a code the
/// apps can translate.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, Object?> details;

  ApiException(this.status, this.code, this.message, [this.details = const {}]);

  ApiException.badRequest(
    String code,
    String message, [
    Map<String, Object?> details = const {},
  ]) : this(400, code, message, details);

  ApiException.notFound(String what) : this(404, 'notFound', '$what not found');

  ApiException.conflict(String code, String message) : this(409, code, message);

  Map<String, Object?> toJson() => {
    'error': code,
    'message': message,
    if (details.isNotEmpty) 'details': details,
  };

  @override
  String toString() => 'ApiException($status, $code, $message)';
}
