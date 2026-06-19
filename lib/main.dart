import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'services/conversation_store.dart';
import 'services/openrouter_service.dart';
import 'services/secure_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(SecureStorageService(), prefs);
  final service = OpenRouterService();
  final store = ConversationStore();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<OpenRouterService>.value(value: service),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            service: service,
            store: store,
            settings: settings,
          ),
        ),
      ],
      child: const RouteApp(),
    ),
  );
}
