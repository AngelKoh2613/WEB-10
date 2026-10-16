import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthSuccess {
  const AuthSuccess({required this.accessToken});

  final String accessToken;
}

sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class AuthValidationFailure extends AuthFailure {
  const AuthValidationFailure(super.message);
}

class AuthCredentialsFailure extends AuthFailure {
  const AuthCredentialsFailure() : super('Correo o contraseña incorrectos');
}

class AuthConflictFailure extends AuthFailure {
  const AuthConflictFailure() : super('No se pudo completar el registro');
}

class AuthRateLimitFailure extends AuthFailure {
  const AuthRateLimitFailure()
    : super('Demasiados intentos. Espera antes de reintentar.');
}

class AuthNetworkFailure extends AuthFailure {
  const AuthNetworkFailure() : super('No hay conexión con el servidor');
}

class AuthUnavailableFailure extends AuthFailure {
  const AuthUnavailableFailure() : super('La autenticación no está disponible');
}

class AuthUnexpectedFailure extends AuthFailure {
  const AuthUnexpectedFailure() : super('No se pudo completar la operación');
}

abstract interface class AuthApi {
  Future<AuthSuccess> register({
    required String email,
    required String password,
  });

  Future<AuthSuccess> login({required String email, required String password});

  Future<void> session(String accessToken);

  Future<void> logout(String accessToken);
}

class HttpAuthApi implements AuthApi {
  HttpAuthApi({required this.baseUrl, required this.client});

  final String baseUrl;
  final http.Client client;

  @override
  Future<AuthSuccess> register({
    required String email,
    required String password,
  }) {
    return _submit('/api/auth/register', email: email, password: password);
  }

  @override
  Future<AuthSuccess> login({required String email, required String password}) {
    return _submit('/api/auth/login', email: email, password: password);
  }

  @override
  Future<void> session(String accessToken) async {
    final response = await _send(
      () => client.get(
        _uri('/api/auth/session'),
        headers: {
          'accept': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      ),
    );
    if (response.statusCode == 200) {
      return;
    }
    throw _failure(response.statusCode);
  }

  @override
  Future<void> logout(String accessToken) async {
    final response = await _send(
      () => client.post(
        _uri('/api/auth/logout'),
        headers: {'authorization': 'Bearer $accessToken'},
      ),
    );
    if (response.statusCode == 204) {
      return;
    }
    throw _failure(response.statusCode);
  }

  Future<AuthSuccess> _submit(
    String path, {
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => client.post(
        _uri(path),
        headers: const {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _success(response.body);
    }
    throw _failure(response.statusCode);
  }

  AuthSuccess _success(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const AuthUnexpectedFailure();
    }
    final token = decoded['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const AuthUnexpectedFailure();
    }
    return AuthSuccess(accessToken: token);
  }

  AuthFailure _failure(int statusCode) {
    return switch (statusCode) {
      400 => const AuthValidationFailure('Los datos enviados no son válidos'),
      401 => const AuthCredentialsFailure(),
      409 => const AuthConflictFailure(),
      429 => const AuthRateLimitFailure(),
      503 => const AuthUnavailableFailure(),
      _ => const AuthUnexpectedFailure(),
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw const AuthNetworkFailure();
    }
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }
}
