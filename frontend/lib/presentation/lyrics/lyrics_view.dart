import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/player_controller.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final lines = state.lyrics;

    ref.listen(playerControllerProvider, (prev, next) {
      if (next.currentLyricIndex != prev?.currentLyricIndex && next.currentLyricIndex >= 0) {
        final target = next.currentLyricIndex * 36.0;
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    if (lines.isEmpty) {
      return const Center(child: Text('No lyrics'));
    }

    return ListView.builder(
      controller: controller,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final active = index == state.currentLyricIndex;
        return ListTile(
          title: Text(
            line.text,
            style: TextStyle(
              fontSize: active ? 18 : 14,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => ref.read(playerControllerProvider.notifier).seekTo(line.time),
        );
      },
    );
  }
}
