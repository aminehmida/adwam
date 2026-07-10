import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
import '../widgets/context_card.dart';
import 'session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final progress = context.watch<ProgressController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذكار', style: TextStyle(fontFamily: 'Amiri')),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final session in SessionType.values)
            Builder(builder: (context) {
              final visible = config.visibleIds(session);
              return ContextCard(
                session: session,
                done: progress.doneCount(session, visible),
                total: visible.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionScreen(session: session),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
