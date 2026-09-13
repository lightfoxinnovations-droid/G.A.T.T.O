import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'battery.dart';

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
    required this.patrolDiagnosisImage,
    required this.eyes,
    required this.tourRecording,
    required this.tourPlaying,
    required this.tourPaused,
    required this.tourStops,
    required this.lightOk,
    required this.lightLux,
    required this.lightLabel,
    required this.batteryOk,
    required this.batteryVolts,
    required this.batteryPercent,
    required this.batteryLabel,
    required this.alertsLatestId,
    required this.alertsCount,
    required this.pushServer,
    required this.pushTopic,
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
  final String patrolDiagnosisImage;
  final String eyes;
  final bool tourRecording;
  final bool tourPlaying;
  final bool tourPaused;
  final List<String> tourStops;
  final bool lightOk;
  final int? lightLux;
  final String lightLabel;
  final bool batteryOk;
  final double? batteryVolts;
  final int? batteryPercent;
  final String batteryLabel;
  final int alertsLatestId;
  final int alertsCount;
  final String pushServer;
  final String pushTopic;

  factory RobotStatus.fromJson(Map<String, dynamic> json) {
    final connect = (json['connect'] as Map?) ?? {};
    final patrol = (json['patrol'] as Map?) ?? {};
    final tour = (json['tour'] as Map?) ?? {};
    final light = (json['light'] as Map?) ?? {};
    final battery = (json['battery'] as Map?) ?? {};
    final alerts = (json['alerts'] as Map?) ?? {};
    final push = (json['push'] as Map?) ?? {};
    final volts = battery['volts'] is num ? (battery['volts'] as num).toDouble() : null;
    final packOk = gattoPackOk(volts) && battery['ok'] == true;
    final percent = packOk ? gattoPackPercent(volts!) : null;
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
      patrolDiagnosisImage: '${patrol['diagnosis_image'] ?? ''}',
      eyes: '${patrol['eyes'] ?? ''}',
      tourRecording: tour['recording'] == true,
      tourPlaying: tour['playing'] == true,
      tourPaused: tour['paused'] == true,
      tourStops: ((tour['stops'] as List?) ?? []).map((item) => '$item').toList(),
      lightOk: light['ok'] == true,
      lightLux: light['lux'] is num ? (light['lux'] as num).round() : null,
      lightLabel: '${light['label'] ?? 'Non collegato'}',
      batteryOk: packOk,
      batteryVolts: packOk ? volts : null,
      batteryPercent: percent,
      batteryLabel: packOk ? gattoPackLabel(percent!) : '${battery['label'] ?? 'Non collegato'}',
      alertsLatestId: alerts['latest_id'] as int? ?? 0,
      alertsCount: alerts['count'] as int? ?? 0,
      pushServer: '${push['server'] ?? 'https://ntfy.sh'}',
      pushTopic: '${push['topic'] ?? ''}',
    );
  }
}

class PlantAlert {
  const PlantAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.body,
    required this.text,
    required this.image,
    required this.ts,
  });

  final int id;
  final String severity;
  final String title;
  final String body;
  final String text;
  final String image;
  final int ts;

  factory PlantAlert.fromJson(Map<String, dynamic> json) {
    return PlantAlert(
      id: json['id'] as int? ?? 0,
      severity: '${json['severity'] ?? 'attenzione'}',
      title: '${json['title'] ?? 'Avviso pianta'}',
      body: '${json['body'] ?? ''}',
      text: '${json['text'] ?? ''}',
      image: '${json['image'] ?? ''}',
      ts: json['ts'] as int? ?? 0,
    );
  }
}

class Inspection {
  const Inspection({
    required this.id,
    required this.severity,
    required this.name,
    required this.key,
    required this.title,
    required this.text,
    required this.hasImage,
    required this.ts,
  });

  final int id;
  final String severity;
  final String name;
  final String key;
  final String title;
  final String text;
  final bool hasImage;
  final int ts;

  factory Inspection.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? 'una pianta'}';
    return Inspection(
      id: json['id'] as int? ?? 0,
      severity: '${json['severity'] ?? 'ok'}',
      name: name,
      key: '${json['key'] ?? plantKey(name)}',
      title: '${json['title'] ?? 'Ispezione'}',
      text: '${json['text'] ?? ''}',
      hasImage: json['has_image'] == true,
      ts: json['ts'] as int? ?? 0,
    );
  }
}

class PlantCompare {
  const PlantCompare({
    required this.key,
    required this.name,
    required this.count,
    required this.latest,
    this.previous,
    required this.trend,
    required this.trendText,
    required this.compareLabel,
  });

  final String key;
  final String name;
  final int count;
  final Inspection latest;
  final Inspection? previous;
  final String trend;
  final String trendText;
  final String compareLabel;

  factory PlantCompare.fromJson(Map<String, dynamic> json) {
    final latest = Inspection.fromJson(Map<String, dynamic>.from(json['latest'] as Map? ?? {}));
    final prevRaw = json['previous'];
    return PlantCompare(
      key: '${json['key'] ?? latest.key}',
      name: '${json['name'] ?? latest.name}',
      count: json['count'] as int? ?? 1,
      latest: latest,
      previous: prevRaw is Map ? Inspection.fromJson(Map<String, dynamic>.from(prevRaw)) : null,
      trend: '${json['trend'] ?? 'new'}',
      trendText: '${json['trend_text'] ?? 'Prima ispezione'}',
      compareLabel: '${json['compare_label'] ?? ''}',
    );
  }
}

String plantKey(String name) {
  final raw = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zàèéìòù0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (raw.isEmpty || raw == 'una pianta' || raw == 'non sicuro' || raw == 'sconosciuta') {
    return 'sconosciuta';
  }
  return raw.split(' ').take(3).join(' ');
}

int severityScore(String severity) {
  return switch (severity) {
    'ok' => 2,
    'attenzione' => 1,
    'male' => 0,
    _ => 1,
  };
}

String compareWhen(int latestTs, int previousTs) {
  final days = ((latestTs - previousTs) / 86400).floor().clamp(0, 9999);
  final hours = ((latestTs - previousTs) / 3600).floor().clamp(0, 9999);
  if (days >= 2) return '$days giorni fa';
  if (days == 1) return 'ieri';
  if (hours >= 2) return '$hours ore fa';
  return 'visita precedente';
}

Inspection? pickPrevious(List<Inspection> visits) {
  if (visits.length < 2) return null;
  final latest = visits.first;
  final older = visits.skip(1).where((item) => latest.ts - item.ts >= 20 * 3600).toList();
  if (older.isEmpty) return visits[1];
  final target = latest.ts - 7 * 86400;
  older.sort((a, b) => (a.ts - target).abs().compareTo((b.ts - target).abs()));
  return older.first;
}

List<PlantCompare> groupPlants(List<Inspection> items) {
  final groups = <String, List<Inspection>>{};
  for (final item in items) {
    groups.putIfAbsent(item.key, () => []).add(item);
  }
  final plants = <PlantCompare>[];
  for (final entry in groups.entries) {
    final visits = [...entry.value]..sort((a, b) => b.ts.compareTo(a.ts));
    final latest = visits.first;
    final previous = pickPrevious(visits);
    late final String trend;
    late final String trendText;
    var label = '';
    if (previous == null) {
      trend = 'new';
      trendText = 'Prima ispezione';
    } else {
      label = compareWhen(latest.ts, previous.ts);
      final now = severityScore(latest.severity);
      final then = severityScore(previous.severity);
      if (now > then) {
        trend = 'better';
        trendText = 'Meglio rispetto a $label';
      } else if (now < then) {
        trend = 'worse';
        trendText = 'Peggio rispetto a $label';
      } else {
        trend = 'same';
        trendText = 'Come $label';
      }
    }
    plants.add(PlantCompare(
      key: entry.key,
      name: latest.name,
      count: visits.length,
      latest: latest,
      previous: previous,
      trend: trend,
      trendText: trendText,
      compareLabel: label,
    ));
  }
  plants.sort((a, b) => b.latest.ts.compareTo(a.latest.ts));
  return plants;
}

class AnalyzeResult {
  const AnalyzeResult({required this.diagnosis, required this.image});

  final String diagnosis;
  final String image;
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

  Future<void> markConfigured(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gatto-configured', value);
  }

  Future<bool> wasConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('gatto-configured') ?? false;
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
    await markConfigured(false);
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

  Future<AnalyzeResult> analyze() async {
    if (host == null) throw Exception('Collega prima G.A.T.T.O.');
    final response = await http.get(_uri('/api/analyze')).timeout(const Duration(seconds: 60));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] == 'success') {
      return AnalyzeResult(
        diagnosis: '${data['diagnosis']}',
        image: '${data['image'] ?? ''}',
      );
    }
    throw Exception(data['message'] ?? 'Analisi non riuscita');
  }

  Future<List<PlantAlert>> alerts() async {
    if (host == null) return [];
    final response = await http.get(_uri('/api/alerts')).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['alerts'] as List?) ?? [];
    return items
        .whereType<Map>()
        .map((item) => PlantAlert.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String? archivePhotoUrl(int id) {
    if (host == null || id <= 0) return null;
    return 'http://$host/api/archive/$id.jpg';
  }

  Future<List<Inspection>> archive() async {
    final pack = await archivePack();
    return pack.$1;
  }

  Future<(List<Inspection>, List<PlantCompare>)> archivePack() async {
    if (host == null) return (<Inspection>[], <PlantCompare>[]);
    final response = await http.get(_uri('/api/archive')).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = ((data['inspections'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => Inspection.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final plantsRaw = (data['plants'] as List?) ?? [];
    final plants = plantsRaw.whereType<Map>().isNotEmpty
        ? plantsRaw.whereType<Map>().map((item) => PlantCompare.fromJson(Map<String, dynamic>.from(item))).toList()
        : groupPlants(items);
    return (items, plants);
  }
}
