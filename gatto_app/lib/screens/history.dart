import 'dart:async';

import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

enum _ArchiveFilter { plants, all, alerts }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.api});

  final RobotApi api;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Inspection> items = [];
  List<PlantCompare> plants = [];
  _ArchiveFilter filter = _ArchiveFilter.plants;
  bool loaded = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pack = await widget.api.archivePack();
      if (!mounted) return;
      setState(() {
        items = pack.$1;
        plants = pack.$2.isNotEmpty ? pack.$2 : groupPlants(pack.$1);
        loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loaded = true);
    }
  }

  List<Inspection> get visibleItems {
    if (filter == _ArchiveFilter.alerts) {
      return items.where((item) => item.severity != 'ok').toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('ARCHIVIO', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Confronto nel tempo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 8),
        const Text(
          'Per ogni pianta confronti l\'ultima visita con quella di una settimana fa: vedi se sta meglio o peggio.',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            _chip('Piante (${plants.length})', _ArchiveFilter.plants, const Color(0xFFDCFCE7), gattoGreenDark),
            _chip('Tutte (${items.length})', _ArchiveFilter.all, const Color(0xFFE5E7EB), const Color(0xFF374151)),
            _chip(
              'Avvisi (${items.where((item) => item.severity != 'ok').length})',
              _ArchiveFilter.alerts,
              const Color(0xFFFEF3C7),
              const Color(0xFF92400E),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!loaded)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator(color: gattoGreen)),
          )
        else if (filter == _ArchiveFilter.plants)
          if (plants.isEmpty) _empty('Nessuna pianta ancora', 'Quando Gatto analizza una pianta due volte, qui compare il confronto.')
          else
            for (final plant in plants) _plantCard(plant)
        else if (visibleItems.isEmpty)
          _empty(
            filter == _ArchiveFilter.alerts ? 'Nessun avviso' : 'Archivio vuoto',
            filter == _ArchiveFilter.alerts
                ? 'Quando una pianta sta male o ha bisogno di te, la vedi anche qui.'
                : 'Quando Gatto analizza una pianta, foto e diagnosi restano in questo elenco.',
          )
        else
          for (final item in visibleItems) _visitCard(item),
      ],
    );
  }

  Widget _chip(String label, _ArchiveFilter value, Color selectedColor, Color selectedText) {
    final on = filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => filter = value),
      selectedColor: selectedColor,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: on ? selectedText : const Color(0xFF4B5563),
      ),
    );
  }

  Widget _empty(String title, String body) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: gattoGreenDark)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
        ],
      ),
    );
  }

  Widget _plantCard(PlantCompare plant) {
    final tone = _tone(plant.latest.severity);
    final trend = _trendTone(plant.trend);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlantComparePage(api: widget.api, plant: plant),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.$1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tone.$3, color: tone.$2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(plant.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: gattoGreenDark)),
                ),
                Text('${plant.count} visite', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(plant.trendText, style: TextStyle(color: trend.$1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _miniShot(plant.latest, 'Oggi', plant.latest.severity)),
                const SizedBox(width: 8),
                Expanded(
                  child: plant.previous == null
                      ? _missingShot('Ancora niente da confrontare')
                      : _miniShot(plant.previous!, plant.compareLabel.isEmpty ? 'Prima' : plant.compareLabel, plant.previous!.severity),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tocca per il confronto completo',
              style: TextStyle(color: gattoGreen.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniShot(Inspection item, String label, String severity) {
    final url = item.hasImage ? widget.api.archivePhotoUrl(item.id) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url == null
              ? Container(
                  height: 110,
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
                )
              : Image.network(
                  url,
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => Container(
                    height: 110,
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(_tone(severity).$4, style: TextStyle(color: _tone(severity).$2, fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }

  Widget _missingShot(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Prima', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        ),
      ],
    );
  }

  Widget _visitCard(Inspection item) {
    final tone = _tone(item.severity);
    final photoUrl = item.hasImage ? widget.api.archivePhotoUrl(item.id) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.$1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tone.$3, color: tone.$2),
              const SizedBox(width: 8),
              Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark))),
              Text(_stamp(item.ts), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(tone.$4, style: TextStyle(color: tone.$2, fontWeight: FontWeight.w700, fontSize: 12)),
          if (photoUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photoUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (item.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.text, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class PlantComparePage extends StatelessWidget {
  const PlantComparePage({super.key, required this.api, required this.plant});

  final RobotApi api;
  final PlantCompare plant;

  @override
  Widget build(BuildContext context) {
    final trend = _trendTone(plant.trend);
    return Scaffold(
      backgroundColor: gattoBg,
      appBar: AppBar(
        title: Text(plant.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: trend.$2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plant.trendText, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: trend.$1)),
                const SizedBox(height: 6),
                Text(
                  plant.previous == null
                      ? 'Serve almeno un’altra visita per capire se è migliorata.'
                      : 'Oggi rispetto a ${plant.compareLabel}.',
                  style: const TextStyle(color: Color(0xFF6B7280), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _side(api, plant.latest, 'Oggi', _stamp(plant.latest.ts)),
          const SizedBox(height: 12),
          if (plant.previous != null)
            _side(api, plant.previous!, plant.compareLabel.isEmpty ? 'Prima' : plant.compareLabel, _stamp(plant.previous!.ts))
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Ancora nessuna visita precedente. Dopo il prossimo controllo potrai confrontare foto e stato.',
                style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _side(RobotApi api, Inspection item, String label, String when) {
    final tone = _tone(item.severity);
    final url = item.hasImage ? api.archivePhotoUrl(item.id) : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.$1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: gattoGreenDark))),
              Text(when, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(tone.$4, style: TextStyle(color: tone.$2, fontWeight: FontWeight.w800)),
          if (url != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (item.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.text, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          ],
        ],
      ),
    );
  }
}

(Color, Color, IconData, String) _tone(String severity) {
  return switch (severity) {
    'male' => (const Color(0xFFFECACA), const Color(0xFFB91C1C), Icons.warning_amber_rounded, 'Sta male'),
    'attenzione' => (const Color(0xFFFDE68A), const Color(0xFFD97706), Icons.eco_outlined, 'Attenzione'),
    _ => (const Color(0xFFDCFCE7), gattoGreen, Icons.check_circle_outline, 'Sta bene'),
  };
}

(Color, Color) _trendTone(String trend) {
  return switch (trend) {
    'better' => (gattoGreen, const Color(0xFFDCFCE7)),
    'worse' => (const Color(0xFFB91C1C), const Color(0xFFFECACA)),
    'same' => (const Color(0xFFD97706), const Color(0xFFFEF3C7)),
    _ => (const Color(0xFF6B7280), const Color(0xFFE5E7EB)),
  };
}

String _stamp(int ts) {
  final when = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  return '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
}
