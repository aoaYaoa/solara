import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/user_playlist.dart';
import '../../services/providers.dart';

class PlaylistState {
  final List<UserPlaylist> playlists;

  const PlaylistState({this.playlists = const []});

  PlaylistState copyWith({List<UserPlaylist>? playlists}) =>
      PlaylistState(playlists: playlists ?? this.playlists);
}

class PlaylistStateNotifier extends StateNotifier<PlaylistState> {
  PlaylistStateNotifier() : super(const PlaylistState());

  void loadPlaylists(List<UserPlaylist> playlists) {
    state = state.copyWith(playlists: playlists);
  }

  UserPlaylist createPlaylist({required String name, String? description}) {
    final now = DateTime.now();
    final playlist = UserPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      description: description,
      songs: const [],
      createdAt: now,
      updatedAt: now,
    );
    state = state.copyWith(playlists: [...state.playlists, playlist]);
    return playlist;
  }

  void deletePlaylist(String id) {
    state = state.copyWith(
      playlists: state.playlists.where((p) => p.id != id).toList(),
    );
  }

  void renamePlaylist(String id, String newName) {
    state = state.copyWith(
      playlists:
          state.playlists.map((p) {
            if (p.id != id) return p;
            return p.copyWith(name: newName, updatedAt: DateTime.now());
          }).toList(),
    );
  }

  void addSongToPlaylist(String playlistId, Song song) {
    state = state.copyWith(
      playlists:
          state.playlists.map((p) {
            if (p.id != playlistId) return p;
            if (p.songs.any((s) => s.id == song.id && s.source == song.source))
              return p;
            return p.copyWith(
              songs: [...p.songs, song],
              updatedAt: DateTime.now(),
            );
          }).toList(),
    );
  }

  void removeSongFromPlaylist(String playlistId, Song song) {
    state = state.copyWith(
      playlists:
          state.playlists.map((p) {
            if (p.id != playlistId) return p;
            return p.copyWith(
              songs:
                  p.songs
                      .where(
                        (s) => !(s.id == song.id && s.source == song.source),
                      )
                      .toList(),
              updatedAt: DateTime.now(),
            );
          }).toList(),
    );
  }

  void reorderSong(String playlistId, int oldIndex, int newIndex) {
    state = state.copyWith(
      playlists:
          state.playlists.map((p) {
            if (p.id != playlistId) return p;
            final songs = [...p.songs];
            final song = songs.removeAt(oldIndex);
            songs.insert(newIndex, song);
            return p.copyWith(songs: songs, updatedAt: DateTime.now());
          }).toList(),
    );
  }
}

final playlistStateProvider =
    StateNotifierProvider<PlaylistStateNotifier, PlaylistState>((ref) {
      final notifier = PlaylistStateNotifier();
      ref.read(persistentStateProvider).loadPlaylists(notifier);
      return notifier;
    });
