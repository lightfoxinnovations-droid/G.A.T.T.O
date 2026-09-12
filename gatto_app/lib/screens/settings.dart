import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../notify.dart';
import '../robot.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.api, required this.onReset, this.onBack});

  final RobotApi api;
  final VoidCallback onReset;
  final VoidCallback? onBack;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool scanning = false;
  bool connecting = false;
  bool resetting = false;
  String homeSsid = '';
  bool internet = false;
  bool remoteAlerts = false;
  String? error;
  String? chosenSsid;
  List<WifiNetwork> networks = [];
  final password = TextEditingController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadRemote();
    _loadStatus();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    password.dispose();
    super.dispose();
  }

  Future<void> _loadRemote() async {
    final remote = await GattoNotify.hasRemote();
    if (!mounted) return;
    setState(() => remoteAlerts = remote);
  }

  Future<void> _loadStatus() async {
    try {
      final status = await widget.api.status();
      if (!mounted || status == null) return;
      await GattoNotify.rememberTopic(status.pushTopic, status.pushServer);
      final remote = await GattoNotify.hasRemote();
      if (!mounted) return;
      setState(() {
        homeSsid = status.homeSsid;
        internet = status.internet;
        remoteAlerts = remote;
      });
    } catch (_) {}
  }

  Future<void> _loadNetworks() async {
    setState(() {
      scanning = true;
      error = null;
    });
    try {
      final list = await widget.api.scan();
      if (!mounted) return;
      setState(() {
        networks = list;
        scanning = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        scanning = false;
        error = 'Non riesco a leggere le reti. Resta collegato al robot e riprova.';
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
          homeSsid = result.homeSsid.isEmpty ? chosenSsid! : result.homeSsid;
          internet = result.internet;
          chosenSsid = null;
          password.clear();
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

  Future<void> _reset() async {
    setState(() => resetting = true);
    try {
      await widget.api.forget();
    } catch (_) {}
    if (!mounted) return;
    widget.onBack?.call();
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.onBack == null) ...[
          const Text('IMPOSTAZIONI', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text('Wi-Fi e robot', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        ],
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rete di casa', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
              const SizedBox(height: 8),
              Text(
                homeSsid.isEmpty ? 'Nessuna rete salvata' : homeSsid,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: gattoGreenDark),
              ),
              const SizedBox(height: 6),
              Text(
                internet ? 'Internet disponibile' : 'Senza internet',
                style: TextStyle(
                  color: internet ? gattoGreen : const Color(0xFFD97706),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifiche a distanza', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
              const SizedBox(height: 8),
              Text(
                remoteAlerts
                    ? 'Attive. Se sei fuori casa o il telefono era spento, l\'avviso arriva appena c\'è internet.'
                    : 'Apri l\'app una volta a casa, collegato a Gatto: poi gli avvisi ti raggiungono anche lontano.',
                style: const TextStyle(color: Color(0xFF4B5563), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('CAMBIA RETE', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 8),
        const Text(
          'Il robot cerca le Wi-Fi vicine. Scegli quella di casa e inserisci la password.',
          style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: scanning ? null : _loadNetworks,
          child: Text(scanning ? 'Cerco reti...' : 'Cerca reti Wi-Fi'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.wifi),
          child: const Text('Apri il Wi-Fi del telefono'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
            child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
          ),
        ],
        if (networks.isNotEmpty) ...[
          const SizedBox(height: 14),
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
        ],
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
          const SizedBox(height: 10),
          FilledButton(
            onPressed: connecting ? null : _connect,
            child: Text(connecting ? 'Collegamento...' : 'Usa questa rete'),
          ),
        ],
        const SizedBox(height: 28),
        const Text('ROBOT', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 8),
        const Text(
          'Riconfigura cancella la rete salvata e riparte dal collegamento all’hotspot G.A.T.T.O.',
          style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: resetting ? null : _reset,
          child: Text(resetting ? 'Attendi...' : 'Riconfigura G.A.T.T.O.'),
        ),
      ],
    );
    if (widget.onBack == null) return body;
    return Scaffold(
      backgroundColor: gattoBg,
      appBar: AppBar(
        title: const Text('Impostazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: body,
    );
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
      child: child,
    );
  }
}
