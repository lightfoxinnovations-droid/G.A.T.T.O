import 'dart:async';

import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key, required this.api});

  final RobotApi api;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  bool autonomous = false;
  String? error;
  String patrolMessage = 'In attesa';
  int patrolDistance = 0;
  bool patrolRunning = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _syncFromRobot();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _watchPatrol(bool enabled) {
    _poll?.cancel();
    if (!enabled) return;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _syncFromRobot());
  }

  Future<void> _syncFromRobot() async {
    try {
      final status = await widget.api.status();
      if (!mounted || status == null) return;
      setState(() {
        autonomous = status.driveMode == 'autonomous';
        patrolRunning = status.patrolRunning;
        patrolDistance = status.patrolDistance;
        patrolMessage = status.patrolMessage.isEmpty ? 'In attesa' : status.patrolMessage;
      });
      if (autonomous && _poll == null) _watchPatrol(true);
    } catch (_) {}
  }

  Future<void> _setMode(bool nextAutonomous) async {
    setState(() {
      autonomous = nextAutonomous;
      error = null;
      patrolMessage = nextAutonomous ? 'Avvio pattuglia...' : 'Pattuglia ferma';
    });
    _watchPatrol(nextAutonomous);
    try {
      await widget.api.setDriveMode(nextAutonomous ? 'autonomous' : 'manual');
      await _syncFromRobot();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _hold(String direction) async {
    try {
      await widget.api.move(direction);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _release() async {
    try {
      await widget.api.move('stop');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('MOVIMENTO', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Gestione del robot', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Autonomo')),
            ButtonSegment(value: false, label: Text('Manuale')),
          ],
          selected: {autonomous},
          onSelectionChanged: (value) => _setMode(value.first),
        ),
        const SizedBox(height: 16),
        if (autonomous)
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
                Text(
                  patrolRunning ? 'Pattuglia in corso' : 'Pattuglia ferma',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark),
                ),
                const SizedBox(height: 8),
                Text(
                  patrolMessage,
                  style: const TextStyle(color: Color(0xFF4B5563), height: 1.45),
                ),
                const SizedBox(height: 10),
                Text(
                  patrolDistance > 0 ? 'Distanza: $patrolDistance cm' : 'Sensore in attesa',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La stessa IA delle piante guarda la camera e decide dove andare. L\'ultrasuono ferma solo se c\'è un ostacolo vicino. Passa a Manuale per fermarlo.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          )
        else ...[
          const Text('Cammina', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          const SizedBox(height: 6),
          const Text('Tieni premuto per muoverlo. Lascia per fermarlo.', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 14),
          _pad(),
          const SizedBox(height: 22),
          const Text('Inclinati', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _cell(Icons.rotate_90_degrees_ccw, 'tilt_left', label: 'Sx'),
              const SizedBox(width: 12),
              _cell(Icons.horizontal_rule, 'level', label: 'Dritto', hold: false),
              const SizedBox(width: 12),
              _cell(Icons.rotate_90_degrees_cw, 'tilt_right', label: 'Dx'),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Altezza', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _cell(Icons.arrow_downward, 'down', label: 'Abbassa'),
              const SizedBox(width: 12),
              _cell(Icons.arrow_upward, 'up', label: 'Alza'),
            ],
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
      ],
    );
  }

  Widget _pad() {
    return Column(
      children: [
        _cell(Icons.keyboard_arrow_up, 'forward'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _cell(Icons.keyboard_arrow_left, 'left'),
            const SizedBox(width: 10),
            _cell(Icons.stop, 'stop', color: const Color(0xFFEF4444)),
            const SizedBox(width: 10),
            _cell(Icons.keyboard_arrow_right, 'right'),
          ],
        ),
        const SizedBox(height: 10),
        _cell(Icons.keyboard_arrow_down, 'backward'),
      ],
    );
  }

  Widget _cell(IconData icon, String direction, {Color? color, String? label, bool hold = true}) {
    final button = SizedBox(
      width: 72,
      height: 64,
      child: FilledButton(
        onPressed: hold ? () {} : () => _hold(direction),
        style: FilledButton.styleFrom(
          backgroundColor: color ?? gattoGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Icon(icon),
      ),
    );
    final body = hold
        ? Listener(
            onPointerDown: (_) => _hold(direction),
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: button,
          )
        : button;
    if (label == null) return body;
    return Column(
      children: [
        body,
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
