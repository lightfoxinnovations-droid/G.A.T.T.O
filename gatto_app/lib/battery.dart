import 'package:flutter/material.dart';

import 'theme.dart';

/// Curva del pacco 2S di Gatto (~7,4 V), non del 5 V del Raspberry.
int gattoPackPercent(double volts) {
  const points = <(double, int)>[
    (6.20, 0),
    (6.50, 5),
    (6.80, 12),
    (7.00, 22),
    (7.20, 35),
    (7.40, 50),
    (7.60, 68),
    (7.80, 82),
    (8.00, 92),
    (8.40, 100),
  ];
  if (volts <= points.first.$1) return 0;
  if (volts >= points.last.$1) return 100;
  for (var i = 0; i < points.length - 1; i++) {
    final (v0, p0) = points[i];
    final (v1, p1) = points[i + 1];
    if (volts <= v1) {
      return (p0 + (p1 - p0) * (volts - v0) / (v1 - v0)).round();
    }
  }
  return 100;
}

String gattoPackLabel(int percent) {
  if (percent >= 70) return 'Carica';
  if (percent >= 40) return 'Buona';
  if (percent >= 20) return 'Media';
  if (percent >= 8) return 'Bassa';
  return 'Scarica';
}

bool gattoPackOk(double? volts) {
  return volts != null && volts >= 5.4 && volts <= 9.2;
}

IconData gattoBatteryIcon(int percent) {
  if (percent >= 90) return Icons.battery_full;
  if (percent >= 70) return Icons.battery_6_bar;
  if (percent >= 50) return Icons.battery_5_bar;
  if (percent >= 30) return Icons.battery_3_bar;
  if (percent >= 15) return Icons.battery_2_bar;
  return Icons.battery_alert;
}

Color gattoBatteryColor(int percent) {
  if (percent >= 40) return gattoGreen;
  if (percent >= 15) return const Color(0xFFD97706);
  return const Color(0xFFB91C1C);
}
