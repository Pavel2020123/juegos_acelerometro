import 'package:flutter/material.dart';

import '../../app_logo.dart';
import '../../core/theme/app_theme.dart';
import 'tilt_maze_level.dart';
import 'tilt_maze_screen.dart';

class TiltMazeLevelSelectScreen extends StatelessWidget {
  const TiltMazeLevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _backButton(context),
              const SizedBox(height: 18),
              const _SelectorHeading(
                title: 'Tilt Maze',
                subtitle: 'Encuentra tu camino con precisión',
                accent: AppColors.tiltMaze,
              ),
              const SizedBox(height: 26),
              Expanded(
                child: ListView.separated(
                  itemCount: tiltMazeLevels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 13),
                  itemBuilder: (context, index) {
                    final level = tiltMazeLevels[index];
                    return _TiltLevelCard(
                      level: level,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TiltMazeScreen(level: level),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) => IconButton(
    tooltip: 'Volver a juegos',
    onPressed: () => Navigator.pop(context),
    icon: const Icon(Icons.arrow_back_rounded),
  );
}

class _SelectorHeading extends StatelessWidget {
  const _SelectorHeading({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const AppLogo(size: 48),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: accent, fontSize: 27),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TiltLevelCard extends StatelessWidget {
  const _TiltLevelCard({required this.level, required this.onPressed});

  final TiltMazeLevel level;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = switch (level.id) {
      1 => Icons.explore_rounded,
      2 => Icons.ac_unit_rounded,
      3 => Icons.bolt_rounded,
      _ => Icons.sports_esports_rounded,
    };
    final difficulty = switch (level.id) {
      1 => 'FÁCIL',
      2 => 'MEDIO',
      3 => 'DIFÍCIL',
      _ => '',
    };
    return _LevelCardShell(
      accent: AppColors.tiltMaze,
      icon: icon,
      levelNumber: level.id,
      difficulty: difficulty,
      title: level.name,
      subtitle: level.description,
      onPressed: onPressed,
    );
  }
}

class _LevelCardShell extends StatelessWidget {
  const _LevelCardShell({
    required this.accent,
    required this.icon,
    required this.levelNumber,
    required this.difficulty,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final Color accent;
  final IconData icon;
  final int levelNumber;
  final String difficulty;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.card),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Ink(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A24334D),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'NIVEL ${levelNumber.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DifficultyChip(label: difficulty, accent: accent),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    ),
  );
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}
