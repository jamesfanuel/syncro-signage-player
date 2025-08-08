import 'package:flutter/material.dart';
import '../models/playlist_model.dart';

class PlaylistItem extends StatelessWidget {
  final Playlist playlist;

  const PlaylistItem({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(playlist.orderName),
      subtitle: Text('Play Date: ${playlist.playDate}'),
      trailing: Icon(Icons.play_arrow),
    );
  }
}
