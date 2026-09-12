import 'dart:async';

import 'package:flutter/material.dart';

import '../notify.dart';
import '../robot.dart';
import '../theme.dart';
import 'control.dart';
import 'history.dart';
import 'home.dart';
import 'settings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api, required this.onReset});

  final RobotApi api;
  final VoidCallback onReset;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  bool linked = false;
  String linkLabel = 'In cerca...';
  Timer? _poll;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      HomePage(api: widget.api),
      ControlPage(api: widget.api),
      HistoryPage(api: widget.api),
    ];
    _ping();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _ping());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _ping() async {
    try {
      final status = await widget.api.status();
      if (!mounted) return;
      if (status == null) {
        setState(() {
          linked = false;
          linkLabel = 'Senza rete';
        });
        await GattoNotify.pollRemote();
        return;
      }
      setState(() {
        linked = true;
        if (status.homeSsid.isNotEmpty && status.internet) {
          linkLabel = 'Collegato · ${status.homeSsid}';
        } else if (status.internet) {
          linkLabel = 'Collegato';
        } else {
          linkLabel = 'Collegato, senza internet';
        }
      });
      await GattoNotify.rememberTopic(status.pushTopic, status.pushServer);
      final seen = await GattoNotify.lastSeenId();
      if (status.alertsLatestId > seen) {
        try {
          final items = await widget.api.alerts();
          await GattoNotify.pushNew(items);
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        linked = false;
        linkLabel = 'Senza rete';
      });
      await GattoNotify.pollRemote();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          api: widget.api,
          onReset: widget.onReset,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('G.A.T.T.O.', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
                        Text(
                          linkLabel,
                          style: TextStyle(
                            color: linked ? gattoGreen : const Color(0xFFD97706),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Impostazioni',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, color: gattoGreenDark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: tab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Controllo'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Archivio'),
        ],
      ),
    );
  }
}
