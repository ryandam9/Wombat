import 'package:flutter/material.dart';

import '../widgets/chat_view.dart';
import '../widgets/conversation_list.dart';

/// Responsive shell: a persistent sidebar on wide (desktop) layouts, and a
/// drawer on narrow (phone) layouts.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _wideBreakpoint = 800;
  static const double _sidebarWidth = 300;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    if (isWide) {
      return const Scaffold(
        body: Row(
          children: [
            SizedBox(width: _sidebarWidth, child: ConversationList()),
            VerticalDivider(width: 1),
            Expanded(child: ChatView(showMenuButton: false)),
          ],
        ),
      );
    }

    return const Scaffold(
      drawer: Drawer(child: ConversationList(inDrawer: true)),
      body: ChatView(showMenuButton: true),
    );
  }
}
