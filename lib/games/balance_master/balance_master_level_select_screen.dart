import 'package:flutter/material.dart';

import 'balance_master_level.dart';
import 'balance_master_screen.dart';

class BalanceMasterLevelSelectScreen extends StatelessWidget {
  const BalanceMasterLevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                tooltip: 'Volver a juegos',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 18),
              const Text(
                'BALANCE MASTER',
                style: TextStyle(
                  color: Color(0xFFB3F7F6),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tres retos de precisión y estabilidad',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 26),
              Expanded(
                child: ListView.separated(
                  itemCount: balanceMasterLevels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final level = balanceMasterLevels[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BalanceMasterScreen(level: level),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF102238),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF285066)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17465B),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  switch (level.id) {
                                    1 => Icons.adjust,
                                    2 => Icons.filter_2,
                                    _ => Icons.auto_awesome,
                                  },
                                  color: const Color(0xFF7BE8E6),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NIVEL ${level.id}  ·  ${level.difficulty}',
                                      style: const TextStyle(
                                        color: Color(0xFF83ACBA),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      level.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${level.duration.toInt()} segundos  ·  '
                                      '${level.objectCount} '
                                      '${level.objectCount == 1 ? 'objeto' : 'objetos'}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                            ],
                          ),
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
}
