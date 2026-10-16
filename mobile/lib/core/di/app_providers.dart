import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/config/app_config.dart';

final appNameProvider = Provider<String>((ref) => AppConfig.appName);
