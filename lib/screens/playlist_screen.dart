import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  VideoPlayerController? _nextController;
  int currentIndex = 0;
  bool isLoading = true;
  bool hasError = false;
  double downloadProgress = 0.0;

  bool showReloadButton = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      setState(() => showReloadButton = false);
    });
  }

  Future<void> _loadPlaylist() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      final items = await ApiService().fetchPlaylist((progress) {
        setState(() {
          downloadProgress = progress;
        });
      });

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
    _controller = _createController(index)
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {});
        _controller!.play();
        _preloadNext(index);
      })
      ..addListener(() {
        final controller = _controller;
        if (controller != null &&
            controller.value.isInitialized &&
            controller.value.position >= controller.value.duration &&
            !controller.value.isPlaying) {
          _playNextVideo();
        }
      });
  }

  VideoPlayerController _createController(int index) {
    return kIsWeb
        ? VideoPlayerController.network(playlist[index].filePath)
        : VideoPlayerController.file(File(playlist[index].filePath));
  }

  void _preloadNext(int index) {
    int nextIndex = (index + 1) % playlist.length;
    _nextController = _createController(nextIndex)..initialize();
  }

  void _playNextVideo() async {
    currentIndex = (currentIndex + 1) % playlist.length;

    if (_nextController != null && _nextController!.value.isInitialized) {
      final oldController = _controller;
      _controller = _nextController;
      _nextController = null;
      await oldController?.dispose();
      setState(() {});
      _controller!.play();
      _preloadNext(currentIndex);
    } else {
      _controller?.dispose();
      _initializeVideo(currentIndex);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _nextController?.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onUserInteraction() {
    setState(() => showReloadButton = true);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Mengunduh playlist... ${(downloadProgress * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      );
    }

    if (hasError || playlist.isEmpty || _controller == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Gagal memuat playlist',
            style: const TextStyle(fontSize: 18, color: Colors.red),
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
      body: RawKeyboardListener(
        autofocus: true,
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            _onUserInteraction();
          }
        },
        child: GestureDetector(
          onTap: _onUserInteraction,
          child: Stack(
            children: [
              Center(
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
              if (showReloadButton)
                Positioned(
                  top: 20,
                  right: 20,
                  child: FocusableActionDetector(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.enter):
                          const ActivateIntent(),
                    },
                    actions: {
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (intent) {
                          _onUserInteraction();
                          _loadPlaylist();
                          return null;
                        },
                      ),
                    },
                    child: ElevatedButton(
                      onPressed: () {
                        _onUserInteraction();
                        _loadPlaylist();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text("Reload"),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
