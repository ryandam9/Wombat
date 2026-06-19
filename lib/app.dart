import 'package:auris/auris.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

class RouteApp extends StatelessWidget {
  const RouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (s) => s.themeMode,
    );
    return MaterialApp(
      title: 'Route',
      debugShowCheckedModeBanner: false,
      theme: AurisTheme.light(),
      darkTheme: AurisTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
