import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final RobotApi api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = false;
  String diagnosis = '';

  Future<void> _scan() async {
    setState(() {
      loading = true;
      diagnosis = 'Scansione in corso...';
    });
    try {
      final text = await widget.api.analyze();
      if (!mounted) return;
      setState(() {
        diagnosis = text;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        diagnosis = '$error';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('OGGI', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Il tuo orto è sotto controllo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [gattoGreen, gattoGreenDark]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pattugliamento', style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 4),
                    Text('Autonomo attivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              Icon(Icons.eco, color: Colors.white, size: 32),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: loading ? null : _scan,
          child: Text(loading ? 'Analisi in corso...' : 'Avvia scansione'),
        ),
        if (diagnosis.isNotEmpty) ...[
          const SizedBox(height: 12),
          _tile('Ultima diagnosi', diagnosis),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _stat('Umidità', '68%')),
            const SizedBox(width: 10),
            Expanded(child: _stat('Luce', '840 lx')),
          ],
        ),
      ],
    );
  }

  Widget _tile(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        ],
      ),
    );
  }
}
