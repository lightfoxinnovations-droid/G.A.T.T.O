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
    required this.driveMode,
    required this.patrolRunning,
    required this.patrolDistance,
    required this.patrolMessage,
    required this.patrolDiagnosis,
    required this.eyes,
    required this.tourRecording,
    required this.tourPlaying,
    required this.tourPaused,
    required this.tourStops,
  });

  final bool ok;
  final bool configured;
  final String homeSsid;
  final bool internet;
  final bool connectBusy;
  final bool connectOk;
  final String connectMessage;
  final String driveMode;
  final bool patrolRunning;
  final int patrolDistance;
  final String patrolMessage;
  final String patrolDiagnosis;
  final String eyes;
  final bool tourRecording;
  final bool tourPlaying;
  final bool tourPaused;
  final List<String> tourStops;

  factory RobotStatus.fromJson(Map<String, dynamic> json) {
    final connect = (json['connect'] as Map?) ?? {};
    final patrol = (json['patrol'] as Map?) ?? {};
    final tour = (json['tour'] as Map?) ?? {};
    return RobotStatus(
      ok: json['status'] == 'success',
      configured: json['configured'] == true,
      homeSsid: '${json['home_ssid'] ?? ''}',
      internet: json['internet'] == true,
      connectBusy: connect['busy'] == true,
      connectOk: connect['ok'] == true,
      connectMessage: '${connect['message'] ?? ''}',
      driveMode: '${json['drive_mode'] ?? 'manual'}',
      patrolRunning: patrol['running'] == true,
      patrolDistance: patrol['distance'] as int? ?? 0,
      patrolMessage: '${patrol['message'] ?? ''}',
      patrolDiagnosis: '${patrol['diagnosis'] ?? ''}',
      eyes: '${patrol['eyes'] ?? ''}',
      tourRecording: tour['recording'] == true,
      tourPlaying: tour['playing'] == true,
      tourPaused: tour['paused'] == true,
      tourStops: ((tour['stops'] as List?) ?? []).map((item) => '$item').toList(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.action,
    required this.image,
    required this.ts,
  });

  final int id;
  final String role;
  final String text;
  final String action;
  final String image;
  final int ts;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int? ?? 0,
      role: '${json['role'] ?? 'system'}',
      text: '${json['text'] ?? ''}',
      action: '${json['action'] ?? ''}',
      image: '${json['image'] ?? ''}',
      ts: json['ts'] as int? ?? 0,
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

  Future<void> setDriveMode(String mode) async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http
        .post(
          _uri('/api/mode'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mode': mode}),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Modalità non cambiata.');
    }
  }

  Future<void> move(String direction) async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http
        .post(
          _uri('/api/move'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'direction': direction}),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Movimento non inviato.');
    }
  }

  Future<List<ChatMessage>> patrolChat({int after = 0}) async {
    if (host == null) return [];
    final response = await http
        .get(_uri('/api/patrol/chat?after=$after'))
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['messages'] as List?) ?? [];
    return items
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> sendPatrolMessage(String message) async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http
        .post(
          _uri('/api/patrol/say'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Messaggio non inviato.');
    }
  }

  String cameraUrl([int tick = 0]) => 'http://$host/api/camera.jpg?t=$tick';

  Future<void> tourRecord(bool enabled) async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http
        .post(
          _uri('/api/tour/record'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode >= 400) {
      throw Exception('Registrazione non avviata.');
    }
  }

  Future<void> tourSave(String name) async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http
        .post(
          _uri('/api/tour/save'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode >= 400) {
      throw Exception('Fermata non salvata.');
    }
  }

  Future<void> tourPlay() async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http.post(_uri('/api/tour/play')).timeout(const Duration(seconds: 6));
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Giro non avviato.');
    }
  }

  Future<void> tourClear() async {
    if (host == null) return;
    await http.post(_uri('/api/tour/clear')).timeout(const Duration(seconds: 6));
  }

  Future<String> analyze() async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http.get(_uri('/api/analyze')).timeout(const Duration(seconds: 60));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] == 'success') return '${data['diagnosis']}';
    throw Exception(data['message'] ?? 'Analisi non riuscita');
  }
}
