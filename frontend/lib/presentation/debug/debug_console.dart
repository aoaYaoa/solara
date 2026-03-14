import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/debug_log_bus.dart';

class DebugConsole extends StatefulWidget {
  const DebugConsole({super.key});

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final List<String> logs = [];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DebugLogBus.stream.listen((event) {
      if (!mounted) return;
      setState(() {
        logs.add(event);
        if (logs.length > 200) {
          logs.removeRange(0, logs.length - 200);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.black.withOpacity(0.85),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Text(
            log,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          );
        },
      ),
    );
  }
}
