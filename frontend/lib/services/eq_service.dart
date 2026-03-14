import '../main.dart' show sharedEqualizer;

class EqPreset {
  final String id;
  final String label;
  // Gain values in dB for each band (length must match device band count)
  final List<double> gains;

  const EqPreset({required this.id, required this.label, required this.gains});
}

class EqService {
  static const List<EqPreset> presets = [
    EqPreset(id: 'flat',    label: '默认',   gains: [0, 0, 0, 0, 0]),
    EqPreset(id: 'pop',     label: '流行',   gains: [2, 1, -1, 1, 2]),
    EqPreset(id: 'rock',    label: '摇滚',   gains: [4, 1, -2, 1, 4]),
    EqPreset(id: 'vocal',   label: '人声',   gains: [-2, 2, 4, 2, -2]),
    EqPreset(id: 'bass',    label: '低音增强', gains: [6, 4, 0, -1, -2]),
    EqPreset(id: 'soft',    label: '轻音乐',  gains: [-1, 2, 3, 2, 1]),
  ];

  static EqPreset? findById(String id) {
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Apply a preset to the shared AndroidEqualizer.
  /// Does nothing on non-Android platforms.
  static Future<void> applyPreset(String presetId) async {
    final eq = sharedEqualizer;
    if (eq == null) return;
    final preset = findById(presetId);
    if (preset == null) return;
    try {
      final params = await eq.parameters;
      final bands = params.bands;
      for (var i = 0; i < bands.length && i < preset.gains.length; i++) {
        bands[i].setGain(preset.gains[i]);
      }
      await eq.setEnabled(presetId != 'flat');
    } catch (e) {
      // Silently ignore EQ errors (device may not support it)
    }
  }
}
