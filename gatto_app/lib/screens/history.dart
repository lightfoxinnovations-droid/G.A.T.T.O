import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.api});

  final RobotApi api;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('ARCHIVIO', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Storico ispezioni', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCFCE7)),
          ),
          child: const Column(
            children: [
              Icon(Icons.photo_library_outlined, size: 40, color: Color(0xFF9CA3AF)),
              SizedBox(height: 12),
              Text(
                'Ancora nessuna ispezione',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: gattoGreenDark),
              ),
              SizedBox(height: 8),
              Text(
                'Quando analizzi una pianta da Controllo, le foto e le diagnosi compariranno qui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
