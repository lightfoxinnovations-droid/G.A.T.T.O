import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key, required this.api, required this.onReady});

  final RobotApi api;
  final VoidCallback onReady;

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int step = 0;
  bool looking = false;
  bool scanning = false;
  bool connecting = false;
  String? error;
  String? chosenSsid;
  List<WifiNetwork> networks = [];
  final password = TextEditingController();
  Timer? poller;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    poller?.cancel();
    password.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    await widget.api.requestWifiPermission();
    await widget.api.bindToWifi();
    await _lookForRobot();
    poller = Timer.periodic(const Duration(seconds: 3), (_) {
      if (step == 0) _lookForRobot();
    });
  }

  Future<void> _lookForRobot() async {
    if (looking) return;
    setState(() => looking = true);
    final found = await widget.api.locate();
    if (!mounted) return;
    setState(() => looking = false);
    if (!found) return;
    final status = await widget.api.status();
    if (!mounted) return;
    if (status != null && status.configured) {
      widget.onReady();
      return;
    }
    setState(() => step = 1);
    await _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    setState(() {
      scanning = true;
      error = null;
    });
    try {
      await widget.api.bindToWifi();
      final list = await widget.api.scan();
      if (!mounted) return;
      setState(() {
        networks = list;
        scanning = false;
        step = 2;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        scanning = false;
        error = 'Non riesco a leggere le reti. Resta collegato a G.A.T.T.O. e riprova.';
      });
    }
  }

  Future<void> _connect() async {
    if (chosenSsid == null) return;
    setState(() {
      connecting = true;
      error = null;
    });
    try {
      await widget.api.connectHome(chosenSsid!, password.text);
      final result = await widget.api.waitForConnect();
      if (!mounted) return;
      if (result.configured || result.connectOk) {
        setState(() {
          connecting = false;
          step = 3;
        });
        return;
      }
      setState(() {
        connecting = false;
        error = result.connectMessage.isEmpty
            ? 'Password errata o rete non raggiungibile.'
            : result.connectMessage;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        error = '$err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CONFIGURAZIONE', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 12)),
              const SizedBox(height: 6),
              Text(_title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: gattoGreenDark, height: 1.15)),
              const SizedBox(height: 10),
              Text(_subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              const SizedBox(height: 18),
              _dots(),
              const SizedBox(height: 18),
              Expanded(child: _body()),
              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                  child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                ),
              ],
              ..._actions(),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    switch (step) {
      case 1:
        return 'Cerco le reti di casa';
      case 2:
        return 'Scegli la rete di casa';
      case 3:
        return 'G.A.T.T.O. è pronto';
      default:
        return 'Collegati a G.A.T.T.O.';
    }
  }

  String get _subtitle {
    switch (step) {
      case 1:
        return 'Resta sulla rete G.A.T.T.O. Il robot sta guardando le Wi-Fi vicine.';
      case 2:
        return 'Queste sono le reti che il robot vede. Scegli quella di casa.';
      case 3:
        return 'La rete è impostata. Torna sulla Wi-Fi di casa dal telefono e apri l’app.';
      default:
        return 'Apri le impostazioni Wi-Fi e scegli la rete G.A.T.T.O. Password: gatto2026';
    }
  }

  Widget _dots() {
    return Row(
      children: List.generate(4, (index) {
        final active = index <= step;
        return Container(
          width: 28,
          height: 6,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: active ? gattoGreen : const Color(0xFFBBF7D0),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }

  Widget _body() {
    if (step == 0) {
      return ListView(
        children: [
          _card(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Apri il Wi-Fi del telefono'),
                SizedBox(height: 8),
                Text('2. Entra nella rete G.A.T.T.O.'),
                SizedBox(height: 8),
                Text('3. Password: gatto2026'),
                SizedBox(height: 8),
                Text('4. Torna qui: l’app riconosce il robot da sola.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (looking) const Text('Cerco G.A.T.T.O....', style: TextStyle(color: gattoGreenDark)),
        ],
      );
    }
    if (step == 1) {
      return const Center(child: CircularProgressIndicator(color: gattoGreen));
    }
    if (step == 2) {
      if (scanning) return const Center(child: CircularProgressIndicator(color: gattoGreen));
      return ListView(
        children: [
          for (final network in networks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: chosenSsid == network.ssid ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: chosenSsid == network.ssid ? gattoGreen : const Color(0xFFDCFCE7)),
                  ),
                  title: Text(network.ssid, style: const TextStyle(fontWeight: FontWeight.w700, color: gattoGreenDark)),
                  subtitle: Text(network.secured ? 'Protetta · ${network.signal}%' : 'Aperta · ${network.signal}%'),
                  onTap: () => setState(() => chosenSsid = network.ssid),
                ),
              ),
            ),
          if (chosenSsid != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password di $chosenSsid',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      );
    }
    return _card(
      child: const Text(
        'Da questo momento G.A.T.T.O. usa la rete di casa. Se riaccendi il robot, la procedura riparte da capo.',
        style: TextStyle(height: 1.45),
      ),
    );
  }

  List<Widget> _actions() {
    if (step == 0) {
      return [
        FilledButton(
          onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.wifi),
          child: const Text('Apri le impostazioni Wi-Fi'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _lookForRobot,
          child: const Text('Ho fatto, cerca G.A.T.T.O.'),
        ),
      ];
    }
    if (step == 2) {
      return [
        FilledButton(
          onPressed: chosenSsid == null || connecting ? null : _connect,
          child: Text(connecting ? 'Collegamento...' : 'Usa questa rete'),
        ),
        TextButton(onPressed: scanning ? null : _loadNetworks, child: const Text('Aggiorna elenco')),
      ];
    }
    if (step == 3) {
      return [
        FilledButton(onPressed: widget.onReady, child: const Text('Apri G.A.T.T.O.')),
      ];
    }
    return const [];
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF374151), fontSize: 15, height: 1.4),
        child: child,
      ),
    );
  }
}
