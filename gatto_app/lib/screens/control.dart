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
        else
          Column(
            children: [
              const Text('Pilotaggio manuale', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
              const SizedBox(height: 8),
              const Text('Tieni premuto un tasto per muoverlo. Lascia per fermarlo.', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              _pad(),
            ],
          ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
      ],
    );
  }

  Widget _pad() {
    Widget cell(IconData icon, String direction, {Color? color}) {
      return Listener(
        onPointerDown: (_) => _hold(direction),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: SizedBox(
          width: 64,
          height: 64,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: color ?? gattoGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Icon(icon),
          ),
        ),
      );
    }

    return Column(
      children: [
        cell(Icons.keyboard_arrow_up, 'forward'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            cell(Icons.keyboard_arrow_left, 'left'),
            const SizedBox(width: 10),
            cell(Icons.stop, 'stop', color: const Color(0xFFEF4444)),
            const SizedBox(width: 10),
            cell(Icons.keyboard_arrow_right, 'right'),
          ],
        ),
        const SizedBox(height: 10),
        cell(Icons.keyboard_arrow_down, 'backward'),
      ],
    );
  }
}
