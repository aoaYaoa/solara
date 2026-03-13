import '../domain/models/lyric_line.dart';

class LyricParser {
  static final RegExp _lineExp = RegExp(r"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)");

  static List<LyricLine> parse(String raw) {
    final lines = <LyricLine>[];
    for (final line in raw.split('\n')) {
      final match = _lineExp.firstMatch(line.trim());
      if (match == null) continue;
      final min = int.tryParse(match.group(1) ?? '') ?? 0;
      final sec = int.tryParse(match.group(2) ?? '') ?? 0;
      final ms = int.tryParse((match.group(3) ?? '0').padRight(3, '0')) ?? 0;
      final text = (match.group(4) ?? '').trim();
      final time = Duration(minutes: min, seconds: sec, milliseconds: ms);
      lines.add(LyricLine(time: time, text: text));
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}
