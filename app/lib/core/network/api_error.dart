import 'package:dio/dio.dart';

/// Converts any exception from an API call into a safe, user-facing message.
///
/// Rules:
///   5xx → generic server error (never leak internals)
///   429 → rate-limit message
///   400 → show backend `message` / `error` field if it looks safe, else generic
///   404 → not found
///   403 → access denied
///   timeout / connection error → network message
///   anything else → generic fallback
String apiErrorMessage(dynamic e) {
  if (e is DioException) {
    final status = e.response?.statusCode;

    if (status != null) {
      if (status == 429) {
        return 'Too many requests. Please wait a moment and try again.';
      }
      if (status >= 500) {
        return 'Something went wrong on our end. Please try again.';
      }
      if (status == 400) {
        return _extract400Message(e.response?.data)
            ?? 'Invalid request. Please try again.';
      }
      if (status == 403) return 'Access denied.';
      if (status == 404) return 'Not found.';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please try again.';
    }
  }

  // Non-Dio exceptions (e.g. platform errors during sign-in)
  final msg = e?.toString() ?? '';
  if (msg.contains('SocketException') || msg.contains('NetworkException')) {
    return 'No internet connection. Please try again.';
  }

  return 'Something went wrong. Please try again.';
}

/// Extracts a safe user message from a 400 response body.
/// Returns null if the message looks like an internal detail or stack trace.
String? _extract400Message(dynamic data) {
  if (data == null) return null;

  String? msg;
  if (data is Map<String, dynamic>) {
    msg = data['message'] as String?;
    msg ??= data['error'] as String?;
  } else if (data is String && data.isNotEmpty) {
    msg = data;
  }

  if (msg == null || msg.isEmpty) return null;

  // Reject anything that looks like a stack trace or internal detail
  if (msg.length > 280) return null;
  if (msg.contains('\n')) return null;
  if (msg.contains('at ') && msg.contains('.dart')) return null;
  if (msg.contains('Exception:') || msg.contains('Error:')) return null;
  if (RegExp(r'0x[0-9a-fA-F]{4,}').hasMatch(msg)) return null;

  return msg;
}
