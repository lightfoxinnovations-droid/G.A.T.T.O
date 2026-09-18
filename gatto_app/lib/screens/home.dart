import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../battery.dart';
import '../robot.dart';
import '../theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final RobotApi api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool patrolBusy = false;
  bool patrolActive = false;
  bool tourBusy = false;
  List<String> tourStops = [];
  String diagnosis = '';
  String diagnosisImage = '';
  String patrolTitle = 'Fermo';
  String lightValue = '—';
  String lightHint = 'In attesa';
  bool lightOk = false;
  String batteryValue = '—';
  String batteryHint = 'In attesa';
  bool batteryOk = false;
  int? batteryPercent;
  String soilValue = '—';
  String soilHint = 'In attesa';
  bool soilOk = false;
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
        if (status.driveMode == 'autonomous' && status.patrolRunning) {
          patrolTitle = status.patrolMessage.isEmpty ? 'Sta pattugliando' : status.patrolMessage;
        } else if (status.driveMode == 'autonomous') {
          patrolTitle = 'Autonomo, in attesa';
        } else {
          patrolTitle = 'Fermo';
        }
        if (status.patrolDiagnosis.isNotEmpty) {
          diagnosis = status.patrolDiagnosis;
          diagnosisImage = status.patrolDiagnosisImage;
        }
        tourStops = status.tourStops;
        lightOk = status.lightOk;
        if (status.lightOk && status.lightLux != null) {
          lightValue = '${status.lightLux} lx';
          lightHint = status.lightLabel;
        } else {
          lightValue = '—';
          lightHint = status.lightLabel.isEmpty ? 'In attesa' : status.lightLabel;
        }
        soilOk = status.soilOk;
        if (status.soilOk && status.soilPercent != null) {
          soilValue = '${status.soilPercent}%';
          soilHint = status.soilLabel;
        } else {
          soilValue = '—';
          soilHint = status.soilLabel.isEmpty ? 'In attesa' : status.soilLabel;
        }
        batteryOk = status.batteryOk;
        batteryPercent = status.batteryPercent;
        if (status.batteryOk && status.batteryPercent != null) {
          batteryValue = '${status.batteryPercent}%';
          final volts = status.batteryVolts;
          final voltText = volts == null ? '' : '${volts.toStringAsFixed(1).replaceAll('.', ',')} V · ';
          batteryHint = '$voltText${status.batteryLabel}';
        } else {
          batteryValue = '—';
          batteryHint = status.batteryLabel.isEmpty ? 'In attesa' : status.batteryLabel;
        }
      });
    } catch (_) {}
  }

  Future<void> _togglePatrol() async {
    if (!patrolActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Avviare la pattuglia?'),
          content: const Text('Gatto inizierà a camminare da solo e a guardare intorno.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Avvia')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
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

  @override
  Widget build(BuildContext context) {
    final sensors = [
      ('Umidità terreno', soilValue, soilHint, soilOk),
      ('Luce', lightValue, lightHint, lightOk),
      ('Temperatura', '—', 'In arrivo', false),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('CASA', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          patrolActive ? 'Gatto è in movimento' : 'Gatto è fermo',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark),
        ),
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
                    const Text('Pattuglia', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(patrolTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              const Icon(Icons.eco, color: Colors.white, size: 32),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _actionTile(
          icon: patrolActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
          label: patrolBusy
              ? 'Attendi...'
              : patrolActive
                  ? 'Ferma pattuglia'
                  : 'Avvia pattuglia',
          onTap: patrolBusy ? null : _togglePatrol,
          active: patrolActive,
          wide: true,
        ),
        if (tourStops.isNotEmpty) ...[
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.replay,
            label: tourBusy ? 'Attendi...' : 'Ripeti percorso (${tourStops.length})',
            onTap: tourBusy ? null : _playTour,
            wide: true,
          ),
        ],
        if (diagnosis.isNotEmpty) ...[
          const SizedBox(height: 14),
          _diagnosisCard(),
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
          childAspectRatio: 1.05,
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
                        color: item.$4 ? gattoGreen : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            _batteryTile(),
          ],
        ),
      ],
    );
  }

  Widget _batteryTile() {
    final percent = batteryPercent;
    final color = percent == null ? const Color(0xFF9CA3AF) : gattoBatteryColor(percent);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(gattoBatteryIcon(percent ?? 0), color: color, size: 18),
              const SizedBox(width: 6),
              const Text('Batteria', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ],
          ),
          const Spacer(),
          Text(batteryValue, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: gattoGreenDark)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent == null ? 0 : percent / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            batteryHint,
            style: TextStyle(
              color: batteryOk ? color : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosisCard() {
    Widget? photo;
    if (diagnosisImage.isNotEmpty) {
      try {
        photo = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(diagnosisImage),
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
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
          const Text('Ultima diagnosi', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          if (photo != null) ...[
            const SizedBox(height: 10),
            photo,
          ],
          const SizedBox(height: 8),
          Text(diagnosis, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
        ],
      ),
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
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? gattoGreen : const Color(0xFFDCFCE7)),
          ),
          child: Row(
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
          ),
        ),
      ),
    );
  }
}
