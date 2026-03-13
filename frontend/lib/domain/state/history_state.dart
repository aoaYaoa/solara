import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_entry.dart';
import '../models/song.dart';
import '../../services/providers.dart';

const int _kMaxHistory = 200;

class HistoryState {
  final List<HistoryEntry> entries;

  const HistoryState({this.entries = const []});

  HistoryState copyWith({List<HistoryEntry>? entries}) =>
      HistoryState(entries: entries ?? this.entries);
}

class HistoryStateNotifier extends StateNotifier<HistoryState> {
  HistoryStateNotifier() : super(const HistoryState());

  void addEntry(Song song) {
    final now = DateTime.now();
    // 去重：移除同一首歌的旧记录
    final filtered =
        state.entries
            .where(
              (e) => !(e.song.id == song.id && e.song.source == song.source),
            )
            .toList();
    final updated = [HistoryEntry(song: song, playedAt: now), ...filtered];
    // 最多保留 200 条
    state = state.copyWith(
      entries:
          updated.length > _kMaxHistory
              ? updated.sublist(0, _kMaxHistory)
              : updated,
    );
  }

  void removeEntry(HistoryEntry entry) {
    state = state.copyWith(
      entries:
          state.entries
              .where(
                (e) =>
                    !(e.song.id == entry.song.id &&
                        e.playedAt == entry.playedAt),
              )
              .toList(),
    );
  }

  void clear() {
    state = const HistoryState();
  }

  void loadEntries(List<HistoryEntry> entries) {
    state = state.copyWith(entries: entries);
  }
}

final historyStateProvider =
    StateNotifierProvider<HistoryStateNotifier, HistoryState>((ref) {
      final notifier = HistoryStateNotifier();
      // 持久化加载在 PersistentStateService 中触发
      ref.read(persistentStateProvider).loadHistory(notifier);
      return notifier;
    });
