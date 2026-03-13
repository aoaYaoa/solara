import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/services/lyric_parser.dart';

void main() {
  test('LyricParser parses lrc', () {
    const raw = '[00:12.34]Hello\n[00:05.00]Start';
    final lines = LyricParser.parse(raw);
    expect(lines.length, 2);
    expect(lines.first.text, 'Start');
    expect(lines.last.text, 'Hello');
  });
}
