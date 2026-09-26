import 'package:flutter/material.dart';

import 'games/balance_master/balance_master_level_select_screen.dart';
import 'games/tilt_maze/tilt_maze_level_select_screen.dart';

class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050711),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 26),
              const Text(
                'ACCELLAB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Explora el acelerómetro jugando',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
              const SizedBox(height: 34),
              _gameCard(
                context,
                title: 'TILT MAZE',
                subtitle: 'Guía una esfera por tres laberintos.',
                icon: Icons.route,
                accent: const Color(0xFF8B6CFF),
                screen: const TiltMazeLevelSelectScreen(),
              ),
              const SizedBox(height: 16),
              _gameCard(
                context,
                title: 'BALANCE MASTER',
                subtitle:
                    'Controla inclinaciones pequeñas y mantén el equilibrio.',
                icon: Icons.balance,
                accent: const Color(0xFF66DDE5),
                screen: const BalanceMasterLevelSelectScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget screen,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: const Color(0xFF121B2D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    ),
  );
}
