import 'dart:io';
import 'package:flutter/material.dart';

class PlaylistScreen extends StatefulWidget {
  final List<File> audioFiles;
  final int currentTrackIndex;

  const PlaylistScreen({
    super.key,
    required this.audioFiles,
    required this.currentTrackIndex,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late List<File> _audioFiles;
  late int _currentTrackIndex;

  @override
  void initState() {
    super.initState();
    _audioFiles = List.from(widget.audioFiles);
    _currentTrackIndex = widget.currentTrackIndex;
  }

  void _deleteTrack(int index) {
    setState(() {
      _audioFiles.removeAt(index);
      
      // Ajustar el índice de la canción actual
      if (index < _currentTrackIndex) {
        // Si eliminamos una canción antes de la actual, decrementar el índice
        _currentTrackIndex--;
      } else if (index == _currentTrackIndex) {
        // Si eliminamos la canción actual
        if (_audioFiles.isEmpty) {
          // Si no quedan canciones, índice a -1
          _currentTrackIndex = -1;
        } else if (_currentTrackIndex >= _audioFiles.length) {
          // Si el índice queda fuera de rango, ajustar
          _currentTrackIndex = _audioFiles.length - 1;
        }
        // Si el índice está dentro del rango, mantenerlo (se reproducirá la siguiente)
      }
      // Si eliminamos una canción después de la actual, no hacer nada
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      backgroundColor: Colors.black,
      body: _audioFiles.isEmpty
          ? const Center(
              child: Text(
                'Playlist vacía',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) {
                  return;
                }
                Navigator.pop(context, {
                  'index': _currentTrackIndex,
                  'files': _audioFiles,
                });
              },
              child: ListView.builder(
                itemCount: _audioFiles.length,
                itemBuilder: (context, index) {
                  final isPlaying = index == _currentTrackIndex;
                  return ListTile(
                    title: Text(
                      _audioFiles[index].path.split(Platform.pathSeparator).last,
                      style: TextStyle(
                        color: isPlaying ? Colors.green : Colors.white,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    leading: isPlaying
                        ? const Icon(Icons.music_note, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _currentTrackIndex = index;
                      });
                      Navigator.pop(context, {
                        'index': index,
                        'files': _audioFiles,
                      });
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTrack(index),
                    ),
                  );
                },
              ),
            ),
    );
  }
}