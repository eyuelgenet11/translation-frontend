import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationSoundService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// Plays a short notification chime + vibration.
  /// Uses a locally bundled asset — no internet needed.
  static Future<void> playNotificationSound() async {
    try {
      // Haptic vibration (mobile only)
      HapticFeedback.vibrate();
      // Play local asset sound
      await _audioPlayer.play(AssetSource('sounds/notification_pop.mp3'));
    } catch (e) {
      debugPrint("Notification sound error: $e");
    }
  }

  /// Plays a longer success chime + heavy impact vibration.
  static Future<void> playSuccessSound() async {
    try {
      HapticFeedback.heavyImpact();
      await _audioPlayer.play(AssetSource('sounds/success_chime.mp3'));
    } catch (e) {
      debugPrint("Success sound error: $e");
    }
  }
}
