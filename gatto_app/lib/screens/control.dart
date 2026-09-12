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

  void _watchPatrol(bool enabled) {
    _poll?.cancel();
    _live?.cancel();
    if (!enabled) return;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _syncFromRobot());
    _live = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => cameraTick += 1);
    });
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

  @override
  Widget build(BuildContext context) {
    if (autonomous) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MOVIMENTO', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Gestione del robot', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Autonomo')),
                ButtonSegment(value: false, label: Text('Manuale')),
              ],
              selected: {autonomous},
              onSelectionChanged: (value) => _setMode(value.first),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 10),
            _liveView(),
            const SizedBox(height: 8),
            _tourBar(),
            const SizedBox(height: 8),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('MOVIMENTO', style: TextStyle(color: gattoAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Gestione del robot', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Autonomo')),
            ButtonSegment(value: false, label: Text('Manuale')),
          ],
          selected: {autonomous},
          onSelectionChanged: (value) => _setMode(value.first),
        ),
        const SizedBox(height: 16),
        _tourBar(),
        const SizedBox(height: 16),
        const Text('Cammina', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 6),
        const Text('Tieni premuto per muoverlo. Lascia per fermarlo.', style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 14),
        _pad(),
        const SizedBox(height: 22),
        const Text('Inclinati', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _cell(Icons.rotate_90_degrees_ccw, 'tilt_left', label: 'Sx'),
            const SizedBox(width: 12),
            _cell(Icons.horizontal_rule, 'level', label: 'Dritto', hold: false),
            const SizedBox(width: 12),
            _cell(Icons.rotate_90_degrees_cw, 'tilt_right', label: 'Dx'),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Altezza', style: TextStyle(fontWeight: FontWeight.w800, color: gattoGreenDark)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _cell(Icons.arrow_downward, 'down', label: 'Abbassa'),
            const SizedBox(width: 12),
            _cell(Icons.arrow_upward, 'up', label: 'Alza'),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
      ],
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

  Widget _liveView() {
    if (widget.api.host == null) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          widget.api.cameraUrl(cameraTick),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFFDCFCE7),
            alignment: Alignment.center,
            child: const Text('Camera in avvio...', style: TextStyle(color: Color(0xFF6B7280))),
          ),
        ),
      ),
    );
  }

  Widget _tourBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _smallBtn(tourRecording ? 'Stop insegna' : 'Insegna giro', _toggleRecord),
            _smallBtn('Salva fermata', _saveStop),
            _smallBtn('Ripeti giro', _playTour),
            _smallBtn('Cancella', _clearTour),
          ],
        ),
        if (tourStops.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tourPlaying ? 'Ripeto: ${tourStops.join(' → ')}' : 'Fermate: ${tourStops.join(' → ')}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ],
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
        _cell(Icons.keyboard_arrow_up, 'forward'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _cell(Icons.keyboard_arrow_left, 'left'),
            const SizedBox(width: 10),
            _cell(Icons.stop, 'stop', color: const Color(0xFFEF4444)),
            const SizedBox(width: 10),
            _cell(Icons.keyboard_arrow_right, 'right'),
          ],
        ),
        const SizedBox(height: 10),
        _cell(Icons.keyboard_arrow_down, 'backward'),
      ],
    );
  }

  Widget _cell(IconData icon, String direction, {Color? color, String? label, bool hold = true}) {
    final button = SizedBox(
      width: 72,
      height: 64,
      child: FilledButton(
        onPressed: hold ? () {} : () => _hold(direction),
        style: FilledButton.styleFrom(
          backgroundColor: color ?? gattoGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Icon(icon),
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
