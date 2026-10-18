import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Siren + vibration. The siren plays on the Android *alarm* audio channel so
/// it is loud even when the phone is on silent or vibrate.
class AlertService {
  late final AudioPlayer _player = AudioPlayer();
  bool _sirenOn = false;

  bool get sirenOn => _sirenOn;

  Future<void> startSiren() async {
    if (_sirenOn) return;
    _sirenOn = true;
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(AssetSource('siren.wav'));
  }

  Future<void> stopSiren() async {
    if (!_sirenOn) return;
    _sirenOn = false;
    await _player.stop();
  }

  /// Strong repeating vibration until [stopVibration] is called.
  Future<void> startVibration() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: const [0, 700, 350, 700, 350], repeat: 0);
    }
  }

  Future<void> stopVibration() => Vibration.cancel();

  /// One short tick, used to tell her that someone responded.
  Future<void> buzz() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 300);
    }
  }

  Future<void> stopAll() async {
    await stopSiren();
    await stopVibration();
  }
}
