import 'dart:convert';

String accessTokenWithExpiry(int expSeconds) {
  String part(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part({'sub': 'user-1', 'exp': expSeconds})}.signature';
}
