import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

enum AppSound {
  mainShot,
  droneShot,
  victory,
  defeat,
  ice,
  laser,
  checkpoint,
  respawn,
}

/// Owns the single music channel and reusable players for short effects.
class AppAudio {
  AppAudio._();
  static final AppAudio instance = AppAudio._();

  static const menuTrack = 'musica de fondo antes de jugar algun juego.mp3';
  static String astroTrack(int level) => 'Nivel${level}Avion.mp3';

  final AudioPlayer _music = AudioPlayer();
  final Map<AppSound, AudioPlayer> _effects = {};
  final Map<AppSound, DateTime> _lastPlayed = {};
  final Map<Object, String?> _owners = {};
  Future<void> _musicQueue = Future.value();
  String? _currentTrack;
  bool _appActive = true;
  bool _gamePaused = false;
  bool _disposed = false;

  static const _files = <AppSound, String>{
    AppSound.mainShot: 'laser shot game sfx.mp3',
    AppSound.droneShot: 'Disparo del drone.mp3',
    AppSound.victory: 'victory sound.mp3',
    AppSound.defeat: 'arcadederrota.mp3',
    AppSound.ice: 'sonidoHieloBolita.mp3',
    AppSound.laser: 'LazerZapBolita.mp3',
    AppSound.checkpoint: 'cuandollegaaunpuntodepartidanuevo.mp3',
    AppSound.respawn: 'PeloticaRevivida.mp3',
  };
  static const _volumes = <AppSound, double>{
    AppSound.mainShot: 0.17,
    AppSound.droneShot: 0.14,
    AppSound.victory: 0.65,
    AppSound.defeat: 0.65,
    AppSound.ice: 0.35,
    AppSound.laser: 0.6,
    AppSound.checkpoint: 0.5,
    AppSound.respawn: 0.5,
  };

  void claimMusic(Object owner, String track) {
    if (_disposed) return;
    _owners.remove(owner);
    _owners[owner] = track;
    _syncMusic();
  }

  void claimSilence(Object owner) {
    if (_disposed) return;
    _owners.remove(owner);
    _owners[owner] = null;
    _syncMusic();
  }

  void releaseMusic(Object owner) {
    _owners.remove(owner);
    _gamePaused = false;
    _syncMusic();
  }

  void setGamePaused(bool paused) {
    _gamePaused = paused;
    _syncMusic();
    if (paused) {
      for (final player in _effects.values) {
        unawaited(player.stop());
      }
    }
  }

  void setAppActive(bool active) {
    _appActive = active;
    _syncMusic();
    if (!active) {
      for (final player in _effects.values) {
        unawaited(player.stop());
      }
    }
  }

  void _syncMusic() {
    _musicQueue = _musicQueue
        .then((_) async {
          if (_disposed) return;
          final track = _owners.values.lastOrNull;
          if (track == null || !_appActive || _gamePaused) {
            await _music.pause();
            return;
          }
          if (track != _currentTrack) {
            await _music.stop();
            _currentTrack = track;
            await _music.setReleaseMode(ReleaseMode.loop);
            await _music.play(AssetSource('audio/$track'), volume: 0.25);
          } else {
            await _music.resume();
          }
        })
        .catchError((Object _) {});
  }

  void play(AppSound sound) {
    if (_disposed ||
        !_appActive ||
        (_gamePaused &&
            sound != AppSound.victory &&
            sound != AppSound.defeat)) {
      return;
    }
    final now = DateTime.now();
    final cooldown = switch (sound) {
      AppSound.mainShot => const Duration(milliseconds: 650),
      AppSound.droneShot => const Duration(milliseconds: 750),
      _ => const Duration(milliseconds: 120),
    };
    final last = _lastPlayed[sound];
    if (last != null && now.difference(last) < cooldown) return;
    _lastPlayed[sound] = now;
    final player = _effects.putIfAbsent(sound, AudioPlayer.new);
    unawaited(
      player
          .play(AssetSource('audio/${_files[sound]}'), volume: _volumes[sound]!)
          .catchError((Object _) {}),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _musicQueue;
    await _music.dispose();
    for (final player in _effects.values) {
      await player.dispose();
    }
    _effects.clear();
    _owners.clear();
  }
}
