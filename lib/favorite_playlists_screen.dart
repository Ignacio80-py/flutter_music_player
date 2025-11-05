import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'playlist_detail_screen.dart';

class FavoritePlaylistsScreen extends StatefulWidget {
  final List<File> allSongs;
  final Function(List<File>) onPlaylistSelected;

  const FavoritePlaylistsScreen({
    super.key,
    required this.allSongs,
    required this.onPlaylistSelected,
  });

  @override
  State<FavoritePlaylistsScreen> createState() =>
      _FavoritePlaylistsScreenState();
}

class _FavoritePlaylistsScreenState extends State<FavoritePlaylistsScreen> {
  Map<String, List<String>> _playlists = {};
  final TextEditingController _playlistNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? playlistsString = prefs.getString('playlists');
    if (playlistsString != null) {
      try {
        final Map<String, dynamic> playlistsJson = jsonDecode(playlistsString);
        final Map<String, List<String>> cleanedPlaylists = {};
        bool needsSave = false;

        playlistsJson.forEach((key, value) {
          final List<String> songPaths = List<String>.from(value);
          final List<String> existingSongPaths = [];
          for (final path in songPaths) {
            if (File(path).existsSync()) {
              existingSongPaths.add(path);
            } else {
              needsSave = true;
            }
          }
          cleanedPlaylists[key] = existingSongPaths;
        });

        setState(() {
          _playlists = cleanedPlaylists;
        });

        if (needsSave) {
          await _savePlaylists();
        }

      } on FormatException {
        // If the data is corrupted, reset the playlists
        setState(() {
          _playlists = {};
        });
        await _savePlaylists();
      }
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final String playlistsString = jsonEncode(_playlists);
    await prefs.setString('playlists', playlistsString);
  }

  Future<void> _showCreatePlaylistDialog() async {
    _playlistNameController.clear();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Crear Nueva Lista'),
          content: TextField(
            controller: _playlistNameController,
            decoration: const InputDecoration(hintText: "Nombre Lista"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Crear', style: TextStyle(color: Colors.red)),
              onPressed: () {
                final String name = _playlistNameController.text;
                if (name.isNotEmpty && !_playlists.containsKey(name)) {
                  setState(() {
                    _playlists[name] = [];
                  });
                  _savePlaylists();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _openPlaylistDetail(String playlistName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(
          playlistName: playlistName,
          playlistSongs: _playlists[playlistName]!,
          allSongs: widget.allSongs,
        ),
      ),
    );
    _loadPlaylists();
  }

  void _playPlaylist(String playlistName) {
    final List<String> songPaths = _playlists[playlistName]!;
    final List<File> playlistFiles = songPaths
        .map((path) => File(path))
        .toList();
    widget.onPlaylistSelected(playlistFiles);
    Navigator.of(context).pop();
  }

  Future<void> _showDeleteConfirmationDialog(String playlistName) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Lista'),
          content: Text('Esta seguro de eliminar la lista "$playlistName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                _deletePlaylist(playlistName);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePlaylist(String playlistName) {
    setState(() {
      _playlists.remove(playlistName);
    });
    _savePlaylists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listas Favoritas'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _playlists.isEmpty
          ? const Center(
              child: Text(
                'No hay listas. Crea una nueva!',
                style: TextStyle(color: Colors.white),
              ),
            )
          : ListView.builder(
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final String playlistName = _playlists.keys.elementAt(index);
                return ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () => _playPlaylist(playlistName),
                  ),
                  title: Text(
                    playlistName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => _openPlaylistDetail(playlistName),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        _showDeleteConfirmationDialog(playlistName),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
    );
  }
}
