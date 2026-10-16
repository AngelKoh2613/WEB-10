import 'dart:convert';

/// Local expiry check. This does not verify the signature; the signing secret
/// stays on the server.
String? subjectOf(String token) {
  final payload = _payload(token);
  final subject = payload?['sub'];
  if (subject is! String || !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(subject)) {
    return null;
  }
  return subject;
}

bool isAccessTokenUsable(String token, DateTime now) {
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    return false;
  }

  try {
    final payload = _payload(token);
    if (payload == null) {
      return false;
    }
    final exp = payload['exp'];
    if (exp is! int) {
      return false;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    return expiresAt.isAfter(now.toUtc());
  } on FormatException {
    return false;
  }
}

Map<String, dynamic>? _payload(String token) {
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    return null;
  }
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is Map<String, dynamic>) {
      return payload;
    }
  } on FormatException {
    return null;
  }
  return null;
}
