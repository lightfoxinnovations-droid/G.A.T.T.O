import 'dart:convert';

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

@pragma('vm:entry-point')
void gattoBackground() {
  Workmanager().executeTask((task, input) async {
    await GattoNotify.init(requestPermission: false);
    await GattoNotify.pollRemote();
    return true;
  });
}

class GattoNotify {
  GattoNotify._();

  static final plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init({bool requestPermission = true}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'gatto_plants',
            'Piante',
            description: 'Avvisi quando una pianta sta male o ha bisogno di cura',
            importance: Importance.high,
          ),
        );
    if (requestPermission) {
      await Permission.notification.request();
    }
  }

  static Future<void> startBackground() async {
    await Workmanager().initialize(gattoBackground);
    await Workmanager().registerPeriodicTask(
      'gatto-ntfy',
      'gatto-ntfy',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
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
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gatto_plants',
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
      var lastId = since;
      for (final line in response.body.split('\n')) {
        if (line.trim().isEmpty) continue;
        final data = jsonDecode(line);
        if (data is! Map) continue;
        if ('${data['event']}' != 'message') continue;
        lastId = '${data['id']}';
        await showRaw(
          lastId.hashCode,
          '${data['title'] ?? 'G.A.T.T.O.'}',
          '${data['message'] ?? ''}',
        );
      }
      if (lastId != since) {
        await prefs.setString(_sinceKey, lastId);
      }
    } catch (_) {}
  }
}
