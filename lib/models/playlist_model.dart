class Playlist {
  final String filePath;

  Playlist({
    required this.filePath
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      filePath: json['file_path'],
    );
  }
}
