import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/features/auth/domain/access_token.dart';

import 'support/auth_token.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 12);

  test('accepts a token that expires later', () {
    final token = accessTokenWithExpiry(
      now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(isAccessTokenUsable(token, now), isTrue);
  });

  test('rejects expired and malformed tokens', () {
    final expired = accessTokenWithExpiry(
      now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(isAccessTokenUsable(expired, now), isFalse);
    expect(isAccessTokenUsable('not-a-token', now), isFalse);
    expect(isAccessTokenUsable('a.b.c', now), isFalse);
  });
}
