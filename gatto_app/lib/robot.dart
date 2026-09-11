import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';

const hotspotSsid = 'G.A.T.T.O.';
const hotspotPassword = 'gatto2026';
const hotspotHost = '192.168.4.1:5000';
const fallbackLanHost = '10.0.0.110:5000';

class RobotStatus {
  const RobotStatus({
    required this.ok,
    required this.configured,
    required this.homeSsid,
    required this.internet,
    required this.connectBusy,
    required this.connectOk,
    required this.connectMessage,
  });

  final bool ok;
  final bool configured;
  final String homeSsid;
  final bool internet;
  final bool connectBusy;
  final bool connectOk;
  final String connectMessage;

  factory RobotStatus.fromJson(Map<String, dynamic> json) {
    final connect = (json['connect'] as Map?) ?? {};
    return RobotStatus(
      ok: json['status'] == 'success',
      configured: json['configured'] == true,
      homeSsid: '${json['home_ssid'] ?? ''}',
      internet: json['internet'] == true,
      connectBusy: connect['busy'] == true,
      connectOk: connect['ok'] == true,
      connectMessage: '${connect['message'] ?? ''}',
    );
  }
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.secured,
  });

  final String ssid;
  final int signal;
  final bool secured;
}

class RobotApi {
  RobotApi();

  String? host;

  Uri _uri(String path) => Uri.parse('http://$host$path');

  Future<void> persistHost() async {
    if (host == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gatto-host', host!);
  }

  Future<String?> lastHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gatto-host');
  }

  Future<bool> _tryHost(String candidate) async {
    try {
      final response = await http
          .get(Uri.parse('http://$candidate/api/status'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        host = candidate;
        await persistHost();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> locate() async {
    final saved = await lastHost();
    final candidates = <String>[
      hotspotHost,
      if (saved != null && saved.isNotEmpty) saved,
      fallbackLanHost,
    ];
    for (final candidate in candidates.toSet()) {
      if (await _tryHost(candidate)) return true;
    }
    return false;
  }

  Future<String?> currentSsid() async {
    try {
      return await NetworkInfo().getWifiName();
    } catch (_) {
      return null;
    }
  }

  bool isHotspotSsid(String? name) {
    final clean = (name ?? '').replaceAll('"', '');
    return clean == hotspotSsid;
  }

  Future<void> bindToWifi() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(true);
    } catch (_) {}
  }

  Future<void> releaseWifi() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(false);
    } catch (_) {}
  }

  Future<bool> requestWifiPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  Future<RobotStatus?> status() async {
    if (host == null) return null;
    final response = await http.get(_uri('/api/status')).timeout(const Duration(seconds: 6));
    return RobotStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<WifiNetwork>> scan() async {
    if (host == null) return [];
    final response = await http.get(_uri('/api/wifi/scan')).timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['networks'] as List?) ?? [];
    return items
        .map((item) => WifiNetwork(
              ssid: '${item['ssid']}',
              signal: item['signal'] as int? ?? 0,
              secured: item['secured'] == true,
            ))
        .toList();
  }

  Future<void> connectHome(String ssid, String password) async {
    if (host == null) throw Exception('Robot non raggiunto.');
    final response = await http
        .post(
          _uri('/api/wifi/connect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'ssid': ssid, 'password': password}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Connessione non avviata.');
    }
  }

  Future<RobotStatus> waitForConnect() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final current = await status();
      if (current == null) continue;
      if (!current.connectBusy && (current.connectOk || current.configured)) {
        return current;
      }
      if (!current.connectBusy && current.connectMessage.isNotEmpty && !current.connectOk) {
        return current;
      }
    }
    throw Exception('Tempo scaduto. Riprova.');
  }

  Future<void> forget() async {
    if (host == null) return;
    await http.post(_uri('/api/wifi/forget')).timeout(const Duration(seconds: 12));
    host = hotspotHost;
    await persistHost();
  }

  Future<String> analyze() async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http.get(_uri('/api/analyze')).timeout(const Duration(seconds: 60));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] == 'success') return '${data['diagnosis']}';
    throw Exception(data['message'] ?? 'Analisi non riuscita');
  }
}
