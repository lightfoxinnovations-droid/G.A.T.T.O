import 'dart:async';

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
  bool patrolBusy = false;
  bool patrolActive = false;
  bool tourBusy = false;
  List<String> tourStops = [];
  String diagnosis = '';
  String patrolTitle = 'Fermo';
  String patrolSubtitle = 'Pattugliamento';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadPatrol();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _loadPatrol());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadPatrol() async {
    try {
      final status = await widget.api.status();
      if (!mounted || status == null) return;
      setState(() {
        patrolActive = status.driveMode == 'autonomous';
        patrolSubtitle = 'Pattugliamento';
        if (status.driveMode == 'autonomous' && status.patrolRunning) {
          patrolTitle = status.patrolMessage.isEmpty ? 'L\'IA sta guidando' : status.patrolMessage;
        } else if (status.driveMode == 'autonomous') {
          patrolTitle = 'Autonomo, in attesa';
        } else {
          patrolTitle = 'Fermo';
        }
        if (!loading && status.patrolDiagnosis.isNotEmpty) {
          diagnosis = status.patrolDiagnosis;
        }
        tourStops = status.tourStops;
      });
    } catch (_) {}
  }

  Future<void> _togglePatrol() async {
    setState(() => patrolBusy = true);
    try {
      await widget.api.setDriveMode(patrolActive ? 'manual' : 'autonomous');
      await _loadPatrol();
    } catch (_) {}
    if (mounted) setState(() => patrolBusy = false);
  }

  Future<void> _playTour() async {
    setState(() => tourBusy = true);
    try {
      await widget.api.tourPlay();
      await _loadPatrol();
    } catch (_) {}
    if (mounted) setState(() => tourBusy = false);
  }

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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patrolSubtitle, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(patrolTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              const Icon(Icons.eco, color: Colors.white, size: 32),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: patrolBusy ? null : _togglePatrol,
          child: Text(
            patrolBusy
                ? 'Attendi...'
                : patrolActive
                    ? 'Ferma pattuglia'
                    : 'Avvia pattuglia',
          ),
        ),
        if (tourStops.isNotEmpty) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: tourBusy ? null : _playTour,
            child: Text(tourBusy ? 'Attendi...' : 'Ripeti giro (${tourStops.length})'),
          ),
        ],
        const SizedBox(height: 10),
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
