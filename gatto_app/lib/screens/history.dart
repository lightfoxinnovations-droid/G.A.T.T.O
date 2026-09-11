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
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCFCE7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('Basilico · Vaso balcone', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
                  ),
                  Chip(label: Text('+15%'), backgroundColor: Color(0xFFDCFCE7)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _shot('1 settembre', 'Prima', const Color(0xFFF3F4F6))),
                  const SizedBox(width: 10),
                  Expanded(child: _shot('Oggi', 'Attuale', const Color(0xFFDCFCE7))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shot(String date, String label, Color color) {
    return Column(
      children: [
        Text(date, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: gattoGreenDark)),
        ),
      ],
    );
  }
}
