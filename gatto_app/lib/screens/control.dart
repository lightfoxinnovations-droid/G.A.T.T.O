import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../robot.dart';
import '../theme.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key, required this.api});

  final RobotApi api;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  bool autonomous = false;
  String? error;
  String patrolMessage = 'In attesa';
  int patrolDistance = 0;
  String lightText = '';
  bool patrolRunning = false;
  bool sending = false;
  bool scanning = false;
  String diagnosis = '';
  String diagnosisImage = '';
  bool tourRecording = false;
  bool tourPlaying = false;
  List<String> tourStops = [];
  int lastChatId = 0;
  int cameraTick = 0;
  final messages = <ChatMessage>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  Timer? _poll;
  Timer? _live;

  @override
  void initState() {
    super.initState();
    _watchLive();
    _syncFromRobot();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _live?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _watchLive() {
    _live?.cancel();
    _live = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => cameraTick += 1);
    });
  }

  void _watchPatrol(bool enabled) {
    _poll?.cancel();
    if (!enabled) return;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _syncFromRobot());
  }

  Future<void> _syncFromRobot() async {
    try {
      final status = await widget.api.status();
      if (!mounted || status == null) return;
      setState(() {
        autonomous = status.driveMode == 'autonomous';
        patrolRunning = status.patrolRunning;
        patrolDistance = status.patrolDistance;
        patrolMessage = status.patrolMessage.isEmpty ? 'In attesa' : status.patrolMessage;
        tourRecording = status.tourRecording;
        tourPlaying = status.tourPlaying;
        tourStops = status.tourStops;
        lightText = status.lightOk && status.lightLux != null
            ? '${status.lightLux} lx · ${status.lightLabel}'
            : '';
        if (!scanning && status.patrolDiagnosis.isNotEmpty) {
          diagnosis = status.patrolDiagnosis;
          diagnosisImage = status.patrolDiagnosisImage;
        }
      });
      if (autonomous) {
        if (_poll == null) _watchPatrol(true);
        await _loadChat();
      }
    } catch (_) {}
  }

  Future<void> _loadChat() async {
    try {
      final incoming = await widget.api.patrolChat(after: lastChatId);
      if (!mounted || incoming.isEmpty) return;
      setState(() {
        for (final item in incoming) {
          if (messages.any((old) => old.id == item.id)) continue;
          messages.add(item);
          if (item.id > lastChatId) lastChatId = item.id;
        }
      });
      _jumpToEnd();
    } catch (_) {}
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _setMode(bool nextAutonomous) async {
    if (nextAutonomous && !autonomous) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Avviare la pattuglia?'),
          content: const Text('Gatto inizierà a camminare da solo e a guardare intorno.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Avvia')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      autonomous = nextAutonomous;
      error = null;
      patrolMessage = nextAutonomous ? 'Avvio pattuglia...' : 'Pattuglia ferma';
      if (nextAutonomous) {
        messages.clear();
        lastChatId = 0;
      }
    });
    _watchPatrol(nextAutonomous);
    try {
      await widget.api.setDriveMode(nextAutonomous ? 'autonomous' : 'manual');
      await _syncFromRobot();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.api.sendPatrolMessage(text);
      input.clear();
      await _loadChat();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _hold(String direction) async {
    try {
      await widget.api.move(direction);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _release() async {
    try {
      await widget.api.move('stop');
    } catch (_) {}
  }

  Future<void> _scanPlant() async {
    setState(() {
      scanning = true;
      diagnosis = 'Scansione in corso...';
      error = null;
    });
    try {
      final result = await widget.api.analyze();
      if (!mounted) return;
      setState(() {
        diagnosis = result.diagnosis;
        diagnosisImage = result.image;
        scanning = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        diagnosis = '$err';
        scanning = false;
      });
    }
  }

  Widget _headPad() {
    return Column(
      children: [
        _cell(Icons.keyboard_arrow_up, 'head_up', label: 'Su', hold: false, compact: true, outlined: true),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _cell(Icons.keyboard_arrow_left, 'head_left', label: 'Sinistra', hold: false, compact: true, outlined: true),
            const SizedBox(width: 8),
            _cell(Icons.center_focus_strong, 'head_center', label: 'Centro', hold: false, compact: true, outlined: true),
            const SizedBox(width: 8),
            _cell(Icons.keyboard_arrow_right, 'head_right', label: 'Destra', hold: false, compact: true, outlined: true),
          ],
        ),
        const SizedBox(height: 8),
        _cell(Icons.keyboard_arrow_down, 'head_down', label: 'Giù', hold: false, compact: true, outlined: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (autonomous) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeSwitch(),
            const SizedBox(height: 8),
            Text(
              [
                if (patrolRunning)
                  patrolDistance > 0 ? '$patrolMessage · $patrolDistance cm' : patrolMessage
                else
                  'Pattuglia ferma',
                if (lightText.isNotEmpty) lightText,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 8),
            _liveView(height: 168),
            const SizedBox(height: 6),
            _tourBar(),
            const SizedBox(height: 6),
            Expanded(child: _chat()),
            const SizedBox(height: 8),
            _composer(),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _modeSwitch(),
          const SizedBox(height: 10),
          _liveView(height: 176),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: scanning ? null : _scanPlant,
            child: Text(scanning ? 'Analisi in corso, attendi...' : 'Scansiona pianta'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (diagnosis.isNotEmpty) ...[
                  _diagnosisBox(),
                  const SizedBox(height: 16),
                ],
                const Text('Testa', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
                const SizedBox(height: 4),
                const Text('Un tocco per inquadrare. La camera resta qui sopra.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 10),
                _headPad(),
                const SizedBox(height: 18),
                const Text('Cammina', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
                const SizedBox(height: 4),
                const Text('Tieni premuto. Lascia per fermarlo.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 10),
                _pad(),
                const SizedBox(height: 8),
                _tourBar(),
                _poseBar(),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Autonomo')),
        ButtonSegment(value: false, label: Text('Manuale')),
      ],
      selected: {autonomous},
      onSelectionChanged: (value) => _setMode(value.first),
    );
  }

  Future<void> _toggleRecord() async {
    try {
      await widget.api.tourRecord(!tourRecording);
      await _syncFromRobot();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _saveStop() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final field = TextEditingController(text: 'Fermata ${tourStops.length + 1}');
        return AlertDialog(
          title: const Text('Salva fermata'),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nome pianta o vaso'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(context, field.text.trim()), child: const Text('Salva')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.api.tourSave(name);
      await _syncFromRobot();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _playTour() async {
    try {
      await widget.api.tourPlay();
      await _syncFromRobot();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Future<void> _clearTour() async {
    try {
      await widget.api.tourClear();
      await _syncFromRobot();
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  Widget _liveView({double? height}) {
    if (widget.api.host == null) {
      return const SizedBox.shrink();
    }
    final image = Image.network(
      widget.api.cameraUrl(cameraTick),
      fit: BoxFit.cover,
      width: double.infinity,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Container(
        color: const Color(0xFFDCFCE7),
        alignment: Alignment.center,
        child: const Text('Camera in avvio...', style: TextStyle(color: Color(0xFF6B7280))),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: height == null
          ? AspectRatio(aspectRatio: 16 / 9, child: image)
          : SizedBox(height: height, width: double.infinity, child: image),
    );
  }

  Widget _diagnosisBox() {
    Widget? photo;
    if (diagnosisImage.isNotEmpty) {
      try {
        photo = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(diagnosisImage),
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ultima diagnosi', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
          if (photo != null) ...[
            const SizedBox(height: 10),
            photo,
          ],
          const SizedBox(height: 8),
          Text(diagnosis, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
        ],
      ),
    );
  }

  Widget _tourBar() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('Giro dell\'orto', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
        subtitle: Text(
          tourStops.isEmpty
              ? 'Insegna un percorso da ripetere'
              : tourPlaying
                  ? 'Ripeto: ${tourStops.join(' → ')}'
                  : 'Fermate: ${tourStops.join(' → ')}',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _smallBtn(tourRecording ? 'Stop' : 'Insegna il percorso', _toggleRecord),
                _smallBtn('Salva fermata', _saveStop),
                _smallBtn('Ripeti', _playTour),
                _smallBtn('Cancella', _clearTour),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _poseBar() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Posa', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
        subtitle: const Text('Inclinazione e altezza del corpo', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        children: [
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _cell(Icons.rotate_90_degrees_ccw, 'tilt_left', label: 'Sinistra', compact: true),
              const SizedBox(width: 10),
              _cell(Icons.horizontal_rule, 'level', label: 'Dritto', hold: false, compact: true),
              const SizedBox(width: 10),
              _cell(Icons.rotate_90_degrees_cw, 'tilt_right', label: 'Destra', compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _cell(Icons.arrow_downward, 'down', label: 'Abbassa', compact: true),
              const SizedBox(width: 12),
              _cell(Icons.arrow_upward, 'up', label: 'Alza', compact: true),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, VoidCallback onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      child: Text(label),
    );
  }

  Widget _chat() {
    if (messages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCFCE7)),
        ),
        child: const Text(
          'Qui vedi le foto che scatta e il ragionamento dell\'IA. Puoi scriverle un ordine, per esempio «vai verso il vaso a destra».',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: messages.length,
        itemBuilder: (context, index) => _bubble(messages[index]),
      ),
    );
  }

  Widget _bubble(ChatMessage item) {
    final mine = item.role == 'user';
    final system = item.role == 'system';
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final color = mine
        ? gattoGreen
        : system
            ? const Color(0xFFF3F4F6)
            : const Color(0xFFECFDF5);
    final textColor = mine ? Colors.white : gattoGreenDark;
    Widget? photo;
    if (item.image.isNotEmpty) {
      try {
        photo = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(item.image),
            width: 220,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine
                    ? 'Tu'
                    : system
                        ? 'G.A.T.T.O.'
                        : item.action.isEmpty
                            ? 'IA'
                            : 'IA · ${item.action}',
                style: TextStyle(
                  color: mine ? Colors.white70 : const Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (photo != null) ...[
                const SizedBox(height: 8),
                photo,
              ],
              if (item.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.text, style: TextStyle(color: textColor, height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: input,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Ordine per l\'IA...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDCFCE7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDCFCE7)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: sending ? null : _send,
          style: FilledButton.styleFrom(
            minimumSize: const Size(52, 52),
            padding: EdgeInsets.zero,
          ),
          child: const Icon(Icons.send),
        ),
      ],
    );
  }

  Widget _pad() {
    return Column(
      children: [
        _cell(Icons.keyboard_arrow_up, 'forward', label: 'Avanti'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _cell(Icons.keyboard_arrow_left, 'left', label: 'Sinistra'),
            const SizedBox(width: 10),
            _cell(Icons.stop, 'stop', color: const Color(0xFFEF4444), label: 'Stop'),
            const SizedBox(width: 10),
            _cell(Icons.keyboard_arrow_right, 'right', label: 'Destra'),
          ],
        ),
        const SizedBox(height: 8),
        _cell(Icons.keyboard_arrow_down, 'backward', label: 'Indietro'),
      ],
    );
  }

  Widget _cell(
    IconData icon,
    String direction, {
    Color? color,
    String? label,
    bool hold = true,
    bool compact = false,
    bool outlined = false,
  }) {
    final width = compact ? 64.0 : 80.0;
    final height = compact ? 52.0 : 68.0;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final button = SizedBox(
      width: width,
      height: height,
      child: outlined
          ? OutlinedButton(
              onPressed: hold ? () {} : () => _hold(direction),
              style: OutlinedButton.styleFrom(
                foregroundColor: gattoGreenDark,
                side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
                shape: shape,
                padding: EdgeInsets.zero,
              ),
              child: Icon(icon, size: compact ? 22 : 26),
            )
          : FilledButton(
              onPressed: hold ? () {} : () => _hold(direction),
              style: FilledButton.styleFrom(
                backgroundColor: color ?? gattoGreen,
                shape: shape,
                padding: EdgeInsets.zero,
              ),
              child: Icon(icon, size: compact ? 22 : 28),
            ),
    );
    final body = hold
        ? Listener(
            onPointerDown: (_) => _hold(direction),
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: button,
          )
        : button;
    if (label == null) return body;
    return Column(
      children: [
        body,
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
