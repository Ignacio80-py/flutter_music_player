import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistName;
  final List<String> playlistSongs;
  final List<File> allSongs;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistName,
    required this.playlistSongs,
    required this.allSongs,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<String> _playlistSongs;

  @override
  void initState() {
    super.initState();
    _playlistSongs = List.from(widget.playlistSongs);
    // Limpiar canciones que ya no existen
    _cleanInvalidSongs();
  }

  void _cleanInvalidSongs() {
    final validPaths = widget.allSongs.map((f) => f.path).toSet();
    final originalLength = _playlistSongs.length;

    _playlistSongs.removeWhere((songPath) => !validPaths.contains(songPath));

    if (_playlistSongs.length != originalLength) {
      _savePlaylist();
    }
  }

  Future<void> _savePlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? playlistsString = prefs.getString('playlists');
      if (playlistsString != null) {
        final Map<String, dynamic> playlistsJson = jsonDecode(playlistsString);
        playlistsJson[widget.playlistName] = _playlistSongs;
        final String updatedPlaylistsString = jsonEncode(playlistsJson);
        await prefs.setString('playlists', updatedPlaylistsString);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSong(int index) {
    if (index >= 0 && index < _playlistSongs.length) {
      setState(() {
        _playlistSongs.removeAt(index);
      });
      _savePlaylist();
    }
  }

  Future<void> _showAddSongsDialog() async {
    if (widget.allSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay canciones disponibles para añadir'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<File> songsToAdd = widget.allSongs
        .where((song) => !_playlistSongs.contains(song.path))
        .toList();

    if (songsToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las canciones ya están en la playlist'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<File>? selectedSongs = await showDialog<List<File>>(
      context: context,
      builder: (BuildContext context) {
        return _AddSongsDialog(songsToAdd: songsToAdd);
      },
    );

    if (selectedSongs != null && selectedSongs.isNotEmpty) {
      setState(() {
        _playlistSongs.addAll(selectedSongs.map((song) => song.path));
      });
      _savePlaylist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.playlistName,
          style: const TextStyle(color: Colors.red),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      backgroundColor: Colors.black,
      body: _playlistSongs.isEmpty
          ? const Center(
              child: Text(
                'Playlist vacía.\n¡Añade canciones!',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _playlistSongs.length,
              itemBuilder: (context, index) {
                final String songPath = _playlistSongs[index];
                return ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.red),
                  title: Text(
                    songPath.split(Platform.pathSeparator).last,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _removeSong(index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSongsDialog,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AddSongsDialog extends StatefulWidget {
  final List<File> songsToAdd;

  const _AddSongsDialog({required this.songsToAdd});

  @override
  __AddSongsDialogState createState() => __AddSongsDialogState();
}

class __AddSongsDialogState extends State<_AddSongsDialog> {
  final List<File> _selectedSongs = [];

  void _toggleSelection(File song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Añadir Canciones',
        style: TextStyle(color: Colors.red),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.songsToAdd.isEmpty
            ? const Center(
                child: Text(
                  'No hay canciones disponibles',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.songsToAdd.length,
                itemBuilder: (context, index) {
                  final song = widget.songsToAdd[index];
                  final isSelected = _selectedSongs.contains(song);
                  return CheckboxListTile(
                    title: Text(
                      song.path.split(Platform.pathSeparator).last,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: isSelected,
                    activeColor: Colors.red,
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      _toggleSelection(song);
                    },
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          onPressed: _selectedSongs.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(_selectedSongs);
                },
          child: Text(
            'Añadir${_selectedSongs.isNotEmpty ? " (${_selectedSongs.length})" : ""}',
            style: TextStyle(
              color: _selectedSongs.isEmpty ? Colors.grey : Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}
