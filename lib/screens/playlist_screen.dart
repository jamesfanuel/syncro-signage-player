import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models/playlist_model.dart';
import '../services/api_service.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Playlist> playlist = [];
  VideoPlayerController? _controller;
  int currentIndex = 0;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getInt('customer_id');
      final outletId = prefs.getInt('outlet_id');
      final screenId = prefs.getInt('screen_id');

      if (customerId == null || outletId == null || screenId == null) {
        throw Exception("License data tidak ditemukan");
      }

      final items = await ApiService().fetchPlaylist();

      if (items.isEmpty) throw Exception("Playlist kosong");

      setState(() {
        playlist = items;
        isLoading = false;
      });

      _initializeVideo(currentIndex);
    } catch (e) {
      debugPrint("Gagal memuat playlist: $e");
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  void _initializeVideo(int index) {
    _controller = VideoPlayerController.network(playlist[index].filePath)
      ..initialize().then((_) {
        setState(() {});
        _controller!.play();
      });

    _controller!
      ..setLooping(false)
      ..addListener(() {
        final controller = _controller;
        if (controller != null &&
            controller.value.position >= controller.value.duration &&
            !controller.value.isPlaying) {
          _playNextVideo();
        }
      });
  }

  void _playNextVideo() {
    currentIndex = (currentIndex + 1) % playlist.length;
    _controller?.dispose();
    _initializeVideo(currentIndex);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError || playlist.isEmpty || _controller == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Gagal memuat playlist',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    if (!_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: Text('Memuat video...')),
      );
    }

    return Scaffold(
      body: Center(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }
}
