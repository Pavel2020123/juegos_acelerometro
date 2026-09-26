import 'package:flutter/material.dart';

import 'games/tilt_maze/tilt_maze_level_select_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B6CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TiltMazeLevelSelectScreen(),
    );
  }
}
