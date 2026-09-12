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
  String lightValue = '—';
  String lightHint = 'Non collegato';
  bool lightOk = false;
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
        lightOk = status.lightOk;
        if (status.lightOk && status.lightLux != null) {
          lightValue = '${status.lightLux} lx';
          lightHint = status.lightLabel;
        } else {
          lightValue = '—';
          lightHint = status.lightLabel.isEmpty ? 'Non collegato' : status.lightLabel;
        }
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
    final sensors = [
      ('Umidità terreno', '—', 'Non collegato', false),
      ('Luce', lightValue, lightHint, lightOk),
      ('Temperatura', '—', 'Non collegato', false),
      ('Batteria', '—', 'Non collegato', false),
    ];
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
        const SizedBox(height: 20),
        const Text('AZIONI', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionTile(
                icon: patrolActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                label: patrolBusy
                    ? 'Attendi...'
                    : patrolActive
                        ? 'Ferma pattuglia'
                        : 'Avvia pattuglia',
                onTap: patrolBusy ? null : _togglePatrol,
                active: patrolActive,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionTile(
                icon: Icons.document_scanner_outlined,
                label: loading ? 'Analisi...' : 'Avvia scansione',
                onTap: loading ? null : _scan,
                active: loading,
              ),
            ),
          ],
        ),
        if (tourStops.isNotEmpty) ...[
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.replay,
            label: tourBusy ? 'Attendi...' : 'Ripeti giro (${tourStops.length})',
            onTap: tourBusy ? null : _playTour,
            wide: true,
          ),
        ],
        if (diagnosis.isNotEmpty) ...[
          const SizedBox(height: 14),
          _tile('Ultima diagnosi', diagnosis),
        ],
        const SizedBox(height: 22),
        const Text('SENSORI', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('In tempo reale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: [
            for (final item in sensors)
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
                    Text(item.$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: gattoGreenDark)),
                    const SizedBox(height: 6),
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: item.$4 ? gattoGreen : const Color(0xFFD97706),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
    bool wide = false,
  }) {
    return Material(
      color: active ? gattoGreen : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: wide ? double.infinity : null,
          height: wide ? 64 : 112,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? gattoGreen : const Color(0xFFDCFCE7)),
          ),
          child: wide
              ? Row(
                  children: [
                    Icon(icon, color: active ? Colors.white : gattoGreenDark, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: active ? Colors.white : gattoGreenDark,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: active ? Colors.white : gattoGreenDark, size: 28),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.2,
                        color: active ? Colors.white : gattoGreenDark,
                      ),
                    ),
                  ],
                ),
        ),
      ),
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
}
