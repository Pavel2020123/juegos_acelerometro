import 'package:flutter/material.dart';

import 'games/tilt_maze/tilt_maze_screen.dart';

void main() {
  runApp(const AccelLabApp());
}

class AccelLabApp extends StatelessWidget {
  const AccelLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AccelLab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TiltMazeScreen(),
    );
  }
}

typedef MyApp = AccelLabApp;
