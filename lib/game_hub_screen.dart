import 'package:flutter/material.dart';

import 'app_logo.dart';
import 'core/audio/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'games/astro_tilt/astro_tilt_level_select_screen.dart';
import 'games/gyro_aim/gyro_aim_screen.dart';
import 'games/tilt_maze/tilt_maze_level_select_screen.dart';
import 'screens/sensor_lab/sensor_lab_screen.dart';

class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppAudio.instance.claimMusic(this, AppAudio.menuTrack);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppAudio.instance.setAppActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppAudio.instance.releaseMusic(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AppLogo(size: 76),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AccelLab',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontSize: 34),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Experimenta el movimiento',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final games = [
                    (
                      title: 'TILT MAZE',
                      subtitle: 'Precisión e inclinación',
                      sensor: 'ACELERÓMETRO',
                      icon: Icons.route_rounded,
                      accent: AppColors.tiltMaze,
                      screen: const TiltMazeLevelSelectScreen(),
                    ),
                    (
                      title: 'GYRO AIM',
                      subtitle:
                          'Gira el celular, apunta y acierta a los objetivos.',
                      sensor: 'GIROSCOPIO',
                      icon: Icons.gps_fixed_rounded,
                      accent: const Color(0xFF0891B2),
                      screen: const GyroAimScreen(),
                    ),
                    (
                      title: 'ASTROTILT',
                      subtitle: 'Control espacial',
                      sensor: 'ACELERÓMETRO',
                      icon: Icons.rocket_launch_rounded,
                      accent: AppColors.astroTilt,
                      screen: const AstroTiltLevelSelectScreen(),
                    ),
                  ];
                  final game = games[index];
                  return _GameCard(
                    title: game.title,
                    subtitle: game.subtitle,
                    sensor: game.sensor,
                    icon: game.icon,
                    accent: game.accent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => game.screen),
                    ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SensorLabScreen()),
                  ),
                  icon: const Icon(Icons.sensors_rounded),
                  label: const Text('ABRIR LABORATORIO DE SENSORES'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.sensor,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String sensor;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.card),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B24334D),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: accent, size: 29),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sensor,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: accent, size: 21),
          ],
        ),
      ),
    ),
  );
}
