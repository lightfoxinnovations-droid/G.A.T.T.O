import 'package:flutter/material.dart';

import 'robot.dart';
import 'screens/shell.dart';
import 'screens/wizard.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GattoApp());
}

class GattoApp extends StatelessWidget {
  const GattoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G.A.T.T.O.',
      debugShowCheckedModeBanner: false,
      theme: gattoTheme(),
      home: const BootPage(),
    );
  }
}

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  final api = RobotApi();
  bool ready = false;
  bool checking = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await api.requestWifiPermission();
    await api.bindToWifi();
    final found = await api.locate();
    if (!found) {
      if (!mounted) return;
      setState(() {
        ready = false;
        checking = false;
      });
      return;
    }
    final status = await api.status();
    if (!mounted) return;
    setState(() {
      ready = status?.configured == true;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: gattoGreen),
              SizedBox(height: 16),
              Text('Cerco G.A.T.T.O.', style: TextStyle(color: gattoGreenDark, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }
    if (!ready) {
      return SetupWizard(
        api: api,
        onReady: () => setState(() => ready = true),
      );
    }
    return AppShell(
      api: api,
      onReset: () => setState(() => ready = false),
    );
  }
}
