import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'robot.dart';

const _topicKey = 'gatto-ntfy-topic';
const _serverKey = 'gatto-ntfy-server';
const _sinceKey = 'gatto-ntfy-since';
const _alertKey = 'gatto-last-alert';
const _shownKey = 'gatto-shown';
const _listenChannel = 'gatto_listen';
const _plantChannel = 'gatto_plants';

@pragma('vm:entry-point')
void gattoBackground() {
  Workmanager().executeTask((task, input) async {
    await GattoNotify.init(requestPermission: false);
    await GattoNotify.pollRemote();
    return true;
  });
}

@pragma('vm:entry-point')
void gattoListen(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await GattoNotify.init(requestPermission: false);
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'G.A.T.T.O.',
      content: 'In ascolto per gli avvisi delle piante',
    );
  }
  service.on('stop').listen((_) async {
    await service.stopSelf();
  });
  await GattoNotify.listenRemote(running: () async {
    if (service is AndroidServiceInstance) {
      return service.isForegroundService();
    }
    return true;
  });
}

class GattoNotify {
  GattoNotify._();

  static final plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init({bool requestPermission = true}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _plantChannel,
        'Piante',
        description: 'Avvisi quando una pianta sta male o ha bisogno di cura',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _listenChannel,
        'Ascolto G.A.T.T.O.',
        description: 'Resta attivo per ricevere gli avvisi a app chiusa',
        importance: Importance.low,
      ),
    );
    if (requestPermission) {
      await Permission.notification.request();
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  static Future<void> startBackground() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: gattoListen,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _listenChannel,
        initialNotificationTitle: 'G.A.T.T.O.',
        initialNotificationContent: 'In ascolto per gli avvisi delle piante',
        foregroundServiceNotificationId: 7,
        foregroundServiceTypes: [
          AndroidForegroundType.dataSync,
          AndroidForegroundType.remoteMessaging,
        ],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    await service.startService();
    try {
      await Workmanager().initialize(gattoBackground);
      await Workmanager().registerPeriodicTask(
        'gatto-ntfy',
        'gatto-ntfy',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  static Future<int> lastSeenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_alertKey) ?? 0;
  }

  static Future<void> markSeen(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_alertKey, id);
  }

  static Future<void> rememberTopic(String topic, String server) async {
    if (topic.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_topicKey, topic);
    await prefs.setString(_serverKey, server.isEmpty ? 'https://ntfy.sh' : server);
    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (_) {}
  }

  static Future<bool> hasRemote() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_topicKey) ?? '').isNotEmpty;
  }

  static Future<bool> _alreadyShown(String key) async {
    if (key.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_shownKey) ?? [];
    if (raw.contains(key)) return true;
    raw.add(key);
    while (raw.length > 50) {
      raw.removeAt(0);
    }
    await prefs.setStringList(_shownKey, raw);
    return false;
  }

  static Future<void> showRaw(int id, String title, String body) async {
    final key = '$title|$body';
    if (await _alreadyShown(key)) return;
    await plugin.show(
      id == 7 ? id + 1000 : id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _plantChannel,
          'Piante',
          channelDescription: 'Avvisi quando una pianta sta male o ha bisogno di cura',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> show(PlantAlert alert) async {
    await showRaw(alert.id, alert.title, alert.body);
  }

  static Future<int> pushNew(List<PlantAlert> alerts) async {
    if (alerts.isEmpty) return await lastSeenId();
    final seen = await lastSeenId();
    final fresh = alerts.where((item) => item.id > seen).toList();
    for (final alert in fresh.reversed) {
      await show(alert);
    }
    final latest = alerts.first.id;
    if (latest > seen) await markSeen(latest);
    return latest;
  }

  static Future<void> _handleNtfyLine(String line, SharedPreferences prefs) async {
    if (line.trim().isEmpty) return;
    final data = jsonDecode(line);
    if (data is! Map) return;
    if ('${data['event']}' != 'message') return;
    final lastId = '${data['id']}';
    await showRaw(
      lastId.hashCode,
      '${data['title'] ?? 'G.A.T.T.O.'}',
      '${data['message'] ?? ''}',
    );
    await prefs.setString(_sinceKey, lastId);
  }

  static Future<void> pollRemote() async {
    final prefs = await SharedPreferences.getInstance();
    final topic = prefs.getString(_topicKey) ?? '';
    if (topic.isEmpty) return;
    final server = prefs.getString(_serverKey) ?? 'https://ntfy.sh';
    final since = prefs.getString(_sinceKey) ?? '45m';
    final uri = Uri.parse('$server/$topic/json').replace(queryParameters: {
      'poll': '1',
      'since': since,
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode >= 400) return;
      for (final line in response.body.split('\n')) {
        await _handleNtfyLine(line, prefs);
      }
    } catch (_) {}
  }

  static Future<void> listenRemote({Future<bool> Function()? running}) async {
    var wait = 2;
    while (running == null || await running()) {
      final prefs = await SharedPreferences.getInstance();
      final topic = prefs.getString(_topicKey) ?? '';
      if (topic.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 8));
        continue;
      }
      final server = prefs.getString(_serverKey) ?? 'https://ntfy.sh';
      final since = prefs.getString(_sinceKey) ?? '10s';
      final uri = Uri.parse('$server/$topic/json').replace(queryParameters: {'since': since});
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        request.headers['Accept'] = 'application/x-ndjson';
        final response = await client.send(request);
        if (response.statusCode >= 400) {
          throw Exception('ntfy ${response.statusCode}');
        }
        wait = 2;
        var buffer = '';
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (running != null && !await running()) return;
          buffer += chunk;
          var cut = buffer.indexOf('\n');
          while (cut >= 0) {
            await _handleNtfyLine(buffer.substring(0, cut), prefs);
            buffer = buffer.substring(cut + 1);
            cut = buffer.indexOf('\n');
          }
        }
      } catch (_) {
        await Future<void>.delayed(Duration(seconds: wait));
        wait = (wait * 2).clamp(2, 30);
      } finally {
        client.close();
      }
    }
  }
}
