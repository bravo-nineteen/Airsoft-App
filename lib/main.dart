import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initializeSupabase();
  runApp(const AirsoftApp());
}