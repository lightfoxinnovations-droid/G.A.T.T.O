import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key, required this.api});

  final RobotApi api;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Umidità terreno', '68%', 'Ottimale', true),
      ('Luce', '840 lx', 'Soleggiato', false),
      ('Temperatura', '23°C', 'Stabile', true),
      ('Batteria', '84%', 'In carica solare', true),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('TELEMETRIA', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Sensori in tempo reale', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (final item in items)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    const Spacer(),
                    Text(item.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: gattoGreenDark)),
                    const SizedBox(height: 6),
                    Text(item.$3, style: TextStyle(color: item.$4 ? gattoGreen : const Color(0xFFD97706), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
