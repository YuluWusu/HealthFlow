import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ quản lý âm thanh của ứng dụng
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;

  static const String _keySoundEnabled = 'sound_enabled';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
    } catch (e) {
      debugPrint('Error init AudioService: $e');
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving sound setting: $e');
    }
  }

  Future<void> playTap() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/tap.mp3'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> playSlide() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/slide-popup-close.mp3'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> playSuccess() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/finish-success-achieve.mp3'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> playDing() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/ding-notification.mp3'), volume: 0.5);
    } catch (_) {}
  }
}
