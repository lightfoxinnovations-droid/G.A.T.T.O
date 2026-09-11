import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';
import 'control.dart';
import 'history.dart';
import 'home.dart';
import 'sensors.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api, required this.onReset});

  final RobotApi api;
  final VoidCallback onReset;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(api: widget.api),
      SensorsPage(api: widget.api),
      ControlPage(api: widget.api),
      HistoryPage(api: widget.api),
    ];
    return Scaffold(
      backgroundColor: gattoBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/logo.png', width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('G.A.T.T.O.', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
                        Text('Collegato', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await widget.api.forget();
                      } catch (_) {}
                      widget.onReset();
                    },
                    child: const Text('Riconfigura'),
                  ),
                ],
              ),
            ),
            Expanded(child: pages[tab]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.thermostat_outlined), selectedIcon: Icon(Icons.thermostat), label: 'Sensori'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Controllo'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Storico'),
        ],
      ),
    );
  }
}
