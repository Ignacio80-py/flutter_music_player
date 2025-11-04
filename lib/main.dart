import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'dart:io';
import 'dart:math';
import 'playlist_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'favorite_playlists_screen.dart';

void main() {
  runApp(const MyApp());
}

enum RepeatState { off, repeatAll, repeatOne }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final audioplayers.AudioPlayer _audioPlayer = audioplayers.AudioPlayer();
  List<File> _audioFiles = [];
  List<File> _originalAudioFiles = [];
  int _currentTrackIndex = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  RepeatState _repeatState = RepeatState.off;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _sleepTimer;
  Timer? _countdownTimer;
  Duration _sleepTimerRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadCurrentPlaylistState();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == audioplayers.PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          if (_repeatState == RepeatState.repeatOne) {
            _play();
          } else if (_repeatState == RepeatState.repeatAll) {
            _playNext();
          } else {
            if (_currentTrackIndex < _audioFiles.length - 1) {
              _playNext();
            } else {
              _isPlaying = false;
              _position = Duration.zero;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _originalAudioFiles = result.paths.map((path) => File(path!)).toList();
        _audioFiles = List.from(_originalAudioFiles);
        _currentTrackIndex = 0;
        if (_isShuffle) {
          _audioFiles.shuffle();
        }
      });
      if (_audioFiles.isNotEmpty) {
        _play();
      }
      _saveCurrentPlaylistState();
    }
  }

  Future<void> _play() async {
    if (_audioFiles.isNotEmpty && _currentTrackIndex >= 0 && _currentTrackIndex < _audioFiles.length) {
      await _audioPlayer.play(audioplayers.DeviceFileSource(_audioFiles[_currentTrackIndex].path));
    }
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
  }

  void _playNext() {
    if (_audioFiles.isEmpty) return;
    
    setState(() {
      if (_isShuffle) {
        // En modo shuffle, elegir una canción aleatoria diferente a la actual
        if (_audioFiles.length > 1) {
          int newIndex;
          do {
            newIndex = Random().nextInt(_audioFiles.length);
          } while (newIndex == _currentTrackIndex);
          _currentTrackIndex = newIndex;
        } else {
          // Si solo hay una canción, simplemente la reproduce (o no hace nada si ya está sonando)
          _currentTrackIndex = 0;
        }
      }
      else {
        _currentTrackIndex = (_currentTrackIndex + 1) % _audioFiles.length;
      }
    });
    _play();
  }

  void _playPrevious() {
    if (_audioFiles.isEmpty) return;
    
    setState(() {
      if (_isShuffle) {
        // En modo shuffle, elegir una canción aleatoria diferente a la actual
        if (_audioFiles.length > 1) {
          int newIndex;
          do {
            newIndex = Random().nextInt(_audioFiles.length);
          } while (newIndex == _currentTrackIndex);
          _currentTrackIndex = newIndex;
        } else {
          // Si solo hay una canción, simplemente la reproduce (o no hace nada si ya está sonando)
          _currentTrackIndex = 0;
        }
      }
      else {
        _currentTrackIndex = (_currentTrackIndex - 1 + _audioFiles.length) % _audioFiles.length;
      }
    });
    _play();
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
      
      if (_isShuffle) {
        // Guardar la canción que está sonando actualmente
        File? currentSong;
        if (_currentTrackIndex >= 0 && _currentTrackIndex < _audioFiles.length) {
          currentSong = _audioFiles[_currentTrackIndex];
        }
        
        // Mezclar la lista
        _audioFiles.shuffle();
        
        // Encontrar el nuevo índice de la canción actual
        if (currentSong != null) {
          _currentTrackIndex = _audioFiles.indexOf(currentSong);
          // Si no se encuentra (no debería pasar), poner en 0
          if (_currentTrackIndex == -1) {
            _currentTrackIndex = 0;
          }
        }
      }
      else {
        // Volver a la lista original
        File? currentSong;
        if (_currentTrackIndex >= 0 && _currentTrackIndex < _audioFiles.length) {
          currentSong = _audioFiles[_currentTrackIndex];
        }
        
        _audioFiles = List.from(_originalAudioFiles);
        
        // Encontrar el índice de la canción actual en la lista original
        if (currentSong != null) {
          _currentTrackIndex = _audioFiles.indexOf(currentSong);
          if (_currentTrackIndex == -1) {
            _currentTrackIndex = 0;
          }
        } else {
          _currentTrackIndex = 0;
        }
      }
    });
    _saveCurrentPlaylistState();
  }

  void _toggleRepeat() {
    setState(() {
      if (_repeatState == RepeatState.off) {
        _repeatState = RepeatState.repeatAll;
      } else if (_repeatState == RepeatState.repeatAll) {
        _repeatState = RepeatState.repeatOne;
      } else {
        _repeatState = RepeatState.off;
      }
      _saveCurrentPlaylistState();
    });
  }

  void _onPlaylistSelected(List<File> playlist) {
    setState(() {
      _audioFiles = playlist;
      _originalAudioFiles = List.from(playlist);
      _currentTrackIndex = 0;
      if (_isShuffle) {
        _audioFiles.shuffle();
      }
    });
    if (_audioFiles.isNotEmpty) {
      _play();
    }
    _saveCurrentPlaylistState();
  }

  void _openPlaylist() async {
    if (_audioFiles.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistScreen(
          audioFiles: _audioFiles,
          currentTrackIndex: _currentTrackIndex,
        ),
      ),
    );

    if (result != null && result is Map) {
      final int newIndex = result['index'];
      final List<File> newFiles = result['files'];

      // Verificar que el índice sea válido
      if (newIndex < 0 || newIndex >= newFiles.length) {
        // Si el índice no es válido, ajustarlo
        setState(() {
          _audioFiles = newFiles;
          _originalAudioFiles = List.from(newFiles);
          
          if (newFiles.isEmpty) {
            _currentTrackIndex = -1;
            _isPlaying = false;
            _duration = Duration.zero;
            _position = Duration.zero;
            _audioPlayer.stop();
          } else {
            // Ajustar el índice al rango válido
            _currentTrackIndex = 0;
            _play();
          }
        });
        _saveCurrentPlaylistState();
      } else {
        setState(() {
          _audioFiles = newFiles;
          _originalAudioFiles = List.from(newFiles);
          _currentTrackIndex = newIndex;
          
          if (_isShuffle && _audioFiles.isNotEmpty) {
            File currentSong = _audioFiles[_currentTrackIndex];
            _audioFiles.shuffle();
            _currentTrackIndex = _audioFiles.indexOf(currentSong);
            if (_currentTrackIndex == -1) {
              _currentTrackIndex = 0;
            }
          }
        });

        if (_audioFiles.isNotEmpty) {
          _play();
        }
        _saveCurrentPlaylistState();
      }
    }
  }

  void _openFavoritePlaylists() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritePlaylistsScreen(
          allSongs: _originalAudioFiles,
          onPlaylistSelected: _onPlaylistSelected,
        ),
      ),
    );
  }

  void _startSleepTimer(int minutes) {
    _cancelSleepTimer();
    setState(() {
      _sleepTimerRemaining = Duration(minutes: minutes);
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _pause();
        _cancelSleepTimer();
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_sleepTimerRemaining.inSeconds > 0) {
              _sleepTimerRemaining = _sleepTimerRemaining - const Duration(seconds: 1);
            } else {
              _countdownTimer?.cancel();
            }
          });
        }
      });
    });
  }

  void _cancelSleepTimer() {
    setState(() {
      _sleepTimer?.cancel();
      _countdownTimer?.cancel();
      _sleepTimer = null;
      _sleepTimerRemaining = Duration.zero;
    });
  }

  Future<void> _saveCurrentPlaylistState() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> audioFilePaths = _originalAudioFiles.map((file) => file.path).toList();
    await prefs.setStringList('currentAudioFiles', audioFilePaths);
    await prefs.setInt('currentTrackIndex', _currentTrackIndex);
    await prefs.setBool('isShuffle', _isShuffle);
    await prefs.setInt('repeatState', _repeatState.index);
  }

  Future<void> _loadCurrentPlaylistState() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? audioFilePaths = prefs.getStringList('currentAudioFiles');
    if (audioFilePaths != null && audioFilePaths.isNotEmpty) {
      setState(() {
        _originalAudioFiles = audioFilePaths.map((path) => File(path)).toList();
        _audioFiles = List.from(_originalAudioFiles);
        _currentTrackIndex = prefs.getInt('currentTrackIndex') ?? 0;
        _isShuffle = prefs.getBool('isShuffle') ?? false;
        _repeatState = RepeatState.values[prefs.getInt('repeatState') ?? 0];

        if (_isShuffle) {
          _audioFiles.shuffle();
          // Ensure current track index is valid after shuffle
          if (_originalAudioFiles.isNotEmpty && _currentTrackIndex >= 0 && _currentTrackIndex < _originalAudioFiles.length) {
            File currentSong = _originalAudioFiles[_currentTrackIndex];
            _currentTrackIndex = _audioFiles.indexOf(currentSong);
            if (_currentTrackIndex == -1) {
              _currentTrackIndex = 0;
            }
          } else {
            _currentTrackIndex = 0;
          }
        }
      });
      if (_audioFiles.isNotEmpty) {
        _play();
      }
    }
  }

  Future<void> _showTimerDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Sleep Timer'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                _startSleepTimer(15);
                Navigator.pop(context);
              },
              child: const Text('15 minutes'),
            ),
            SimpleDialogOption(
              onPressed: () {
                _startSleepTimer(30);
                Navigator.pop(context);
              },
              child: const Text('30 minutes'),
            ),
            SimpleDialogOption(
              onPressed: () {
                _startSleepTimer(60);
                Navigator.pop(context);
              },
              child: const Text('60 minutes'),
            ),
            if (_sleepTimer != null && _sleepTimer!.isActive)
              SimpleDialogOption(
                onPressed: () {
                  _cancelSleepTimer();
                  Navigator.pop(context);
                },
                child: const Text('Cancel Timer', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      },
    );
  }

  IconData _getRepeatIcon() {
    switch (_repeatState) {
      case RepeatState.repeatOne:
        return Icons.repeat_one;
      default:
        return Icons.repeat;
    }
  }

  Color _getRepeatIconColor() {
    return _repeatState == RepeatState.off ? Colors.red : Colors.green;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'NAME',
          style: TextStyle(color: Colors.red, fontSize: 40),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            IconButton(
              icon: const Icon(
                Icons.folder_open,
                color: Colors.red,
              ),
              iconSize: 80,
              onPressed: _pickFiles,
            ),
            const SizedBox(height: 90),
            GestureDetector(
              onTap: _audioFiles.isNotEmpty ? _openPlaylist : null,
              child: Text(
                _audioFiles.isNotEmpty && _currentTrackIndex >= 0 && _currentTrackIndex < _audioFiles.length
                    ? _audioFiles[_currentTrackIndex].path.split(Platform.pathSeparator).last
                    : 'No track selected',
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 90),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.red),
                      iconSize: 40,
                      onPressed: _audioFiles.isNotEmpty ? _playPrevious : null,
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.red),
                      iconSize: 40,
                      onPressed: _audioFiles.isNotEmpty ? (_isPlaying ? _pause : _play) : null,
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.red),
                      iconSize: 40,
                      onPressed: _audioFiles.isNotEmpty ? _playNext : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shuffle, color: _isShuffle ? Colors.green : Colors.red),
                      iconSize: 40,
                      onPressed: _audioFiles.isNotEmpty ? _toggleShuffle : null,
                    ),
                    IconButton(
                      icon: Icon(_getRepeatIcon(), color: _getRepeatIconColor()),
                      iconSize: 40,
                      onPressed: _audioFiles.isNotEmpty ? _toggleRepeat : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Slider(
                  min: 0,
                  max: _duration.inSeconds.toDouble(),
                  value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                  onChanged: _audioFiles.isNotEmpty
                      ? (value) async {
                          final position = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(position);
                        }
                      : null,
                  activeColor: Colors.red,
                  inactiveColor: Colors.grey,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: const TextStyle(color: Colors.white)),
                    Text(_formatDuration(_duration - _position), style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.timer, color: _sleepTimer != null && _sleepTimer!.isActive ? Colors.green : Colors.red),
                      iconSize: 40,
                      onPressed: _showTimerDialog,
                    ),
                    if (_sleepTimer != null && _sleepTimer!.isActive)
                      Text(
                        _formatDuration(_sleepTimerRemaining),
                        style: const TextStyle(color: Colors.green, fontSize: 16),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_play, color: Colors.red),
                  iconSize: 40,
                  onPressed: _openFavoritePlaylists,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'nano ©',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}