import 'package:flutter/material.dart';
import 'router.dart';
import 'core/theme/app_theme.dart';

class AirsoftApp extends StatelessWidget {
  const AirsoftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airsoft App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
