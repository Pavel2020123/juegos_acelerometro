import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'game_hub_screen.dart';

void main() {
  runApp(const AccelLabApp());
}

class AccelLabApp extends StatelessWidget {
  const AccelLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AccelLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const GameHubScreen(),
    );
  }
}
