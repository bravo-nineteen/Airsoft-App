import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initializeSupabase();
  runApp(const AirsoftApp());
}
