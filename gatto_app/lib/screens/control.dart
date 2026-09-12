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
  bool autonomous = true;
  String? error;

  Future<void> _setMode(bool nextAutonomous) async {
    setState(() {
      autonomous = nextAutonomous;
      error = null;
    });
    try {
      await widget.api.setDriveMode(nextAutonomous ? 'autonomous' : 'manual');
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Percorso in corso', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
                SizedBox(height: 8),
                Text('G.A.T.T.O. sta ispezionando i vasi del balcone. Nessun intervento richiesto.'),
              ],
            ),
          )
        else ...[
          const Text('Cammina', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          const SizedBox(height: 6),
          const Text('Tieni premuto: avanza o indietreggia alzando le zampe.', style: TextStyle(color: Color(0xFF6B7280))),
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
        _cell(Icons.stop, 'stop', color: const Color(0xFFEF4444)),
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
