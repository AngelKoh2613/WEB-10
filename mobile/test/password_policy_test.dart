import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/features/auth/domain/password_policy.dart';

void main() {
  test('accepts a password with a letter and a digit', () {
    expect(passwordViolatesPolicy('CorrectHorse1', 'ana@example.com'), isFalse);
    expect(validateEmail(' ana@example.com '), isNull);
    expect(validateNewPassword('CorrectHorse1', 'ana@example.com'), isNull);
  });

  test('rejects short, letter-only and email-matching passwords', () {
    expect(validateNewPassword('short1', 'ana@example.com'), isNotNull);
    expect(validateNewPassword('longpassword', 'ana@example.com'), isNotNull);
    expect(
      validateNewPassword('ana@example.com', 'ana@example.com'),
      isNotNull,
    );
    expect(validateEmail('not-an-email'), isNotNull);
    expect(validateLoginPassword(''), isNotNull);
  });
}
