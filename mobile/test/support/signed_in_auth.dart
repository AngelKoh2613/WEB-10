import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';

class SignedInAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession('test-token');
}

class FixedSelectedDay extends SelectedDay {
  @override
  DateTime build() => DateTime(2026, 10, 13);
}
