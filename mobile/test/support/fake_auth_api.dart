import 'dart:async';

import 'package:secureplan_mobile/features/auth/data/auth_api.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.accessToken = 'stored-token'});

  final String accessToken;
  AuthFailure? failure;
  Completer<void>? gate;
  final calls = <String>[];

  @override
  Future<AuthSuccess> register({
    required String email,
    required String password,
  }) {
    return _result('register');
  }

  @override
  Future<AuthSuccess> login({required String email, required String password}) {
    return _result('login');
  }

  @override
  Future<void> session(String accessToken) async {
    calls.add('session');
    await _pause();
    final error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> logout(String accessToken) async {
    calls.add('logout');
    await _pause();
    final error = failure;
    if (error != null) {
      throw error;
    }
  }

  Future<AuthSuccess> _result(String call) async {
    calls.add(call);
    await _pause();
    final error = failure;
    if (error != null) {
      throw error;
    }
    return AuthSuccess(accessToken: accessToken);
  }

  Future<void> _pause() async {
    final pending = gate;
    if (pending != null) {
      await pending.future;
    }
  }
}
