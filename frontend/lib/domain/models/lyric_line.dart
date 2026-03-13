class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({
    required this.time,
    required this.text,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      time: Duration(milliseconds: json['timeMs'] is int ? json['timeMs'] as int : int.tryParse(json['timeMs']?.toString() ?? '') ?? 0),
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeMs': time.inMilliseconds,
      'text': text,
    };
  }
}
