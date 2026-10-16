bool passwordViolatesPolicy(String password, String email) {
  if (password.length < 10 || password.length > 128) {
    return true;
  }
  final hasLetter = RegExp('[A-Za-z]').hasMatch(password);
  final hasDigit = RegExp('[0-9]').hasMatch(password);
  if (!hasLetter || !hasDigit) {
    return true;
  }
  return password.toLowerCase() == email.trim().toLowerCase();
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  if (!valid || email.length > 254) {
    return 'El correo no es válido';
  }
  return null;
}

String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty || value.length > 128) {
    return 'La contraseña no cumple la política';
  }
  return null;
}

String? validateNewPassword(String? value, String email) {
  if (passwordViolatesPolicy(value ?? '', email)) {
    return 'La contraseña no cumple la política';
  }
  return null;
}
