import 'package:flutter/material.dart';

import 'tilt_maze_level.dart';
import 'tilt_maze_screen.dart';

class TiltMazeLevelSelectScreen extends StatelessWidget {
  const TiltMazeLevelSelectScreen({
    super.key,
  });

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
              const SizedBox(height: 16),

              const Text(
                'TILT MAZE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Selecciona una misión',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 28),

              Expanded(
                child: ListView.separated(
                  itemCount: tiltMazeLevels.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(
                      height: 16,
                    );
                  },
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final level =
                        tiltMazeLevels[index];

                    return _LevelCard(
                      level: level,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) {
                              return TiltMazeScreen(
                                level: level,
                              );
                            },
                          ),
                        );
                      },
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
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.onPressed,
  });

  final TiltMazeLevel level;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = switch (level.id) {
      1 => Icons.explore,
      2 => Icons.ac_unit,
      3 => Icons.bolt,
      _ => Icons.sports_esports,
    };

    final difficulty = switch (level.id) {
      1 => 'FÁCIL',
      2 => 'MEDIO',
      3 => 'DIFÍCIL',
      _ => '',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius:
            BorderRadius.circular(22),
        child: Ink(
          padding:
              const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                const Color(0xFF11182A),
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color:
                  Colors.white.withValues(
                alpha: 0.09,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF536DFF)
                          .withValues(
                    alpha: 0.15,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF8EA1FF,
                  ),
                  size: 30,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'NIVEL ${level.id}',
                          style:
                              const TextStyle(
                            color:
                                Colors.white38,
                            fontSize:
                                11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const Spacer(),

                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white
                                    .withValues(
                              alpha: 0.06,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          child: Text(
                            difficulty,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white54,
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      level.name,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      level.description,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize:
                            13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              const Icon(
                Icons.chevron_right,
                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}