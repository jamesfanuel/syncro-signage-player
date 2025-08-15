import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';
import '../models/license_validate_model.dart';
import '../constants/api_constants.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  /// Validasi license, simpan ke SharedPreferences
  Future<LicenseValidationResponse?> validateLicenseCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.validateCodeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_code': code}),
      );

      final jsonData = jsonDecode(response.body);

      final validationResponse = LicenseValidationResponse.fromJson(jsonData);

      if (response.statusCode != 200) {
          return validationResponse;
      }
      
      final data = validationResponse.data;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('customer_id', data.customerId);
      await prefs.setInt('outlet_id', data.outletId);
      await prefs.setInt('screen_id', data.screenId);

      return validationResponse;
    } catch (e) {
      print('Error in validateLicenseCode: $e');
      rethrow;
    }
  }

  /// Ambil playlist berdasarkan data dari SharedPreferences
  Future<List<Playlist>> fetchPlaylist(Function(double progress)? onProgress) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getInt('customer_id');
    final outletId = prefs.getInt('outlet_id');
    final screenId = prefs.getInt('screen_id');

    if (customerId == null || outletId == null || screenId == null) {
      throw Exception('Missing license data. Please validate first.');
    }

    final url = ApiConstants.playlistUrl(customerId, outletId, screenId);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to load playlist: ${response.body}');
    }

    final body = json.decode(response.body);
    final List<dynamic> data = body['data'];

    int completed = 0;
    final playlists = <Playlist>[];

    for (var item in data) {
      try {
        final filePathStr = (item['file_path'] ?? '').toString().trim();
        if (filePathStr.isEmpty || !filePathStr.toLowerCase().endsWith('.mp4')) continue;

        final updatedItem = Map<String, dynamic>.from(item);
        var filePath = filePathStr;

        if (!filePath.startsWith('http')) filePath = '${ApiConstants.baseUrl}$filePath';

        File? localFile;
        if (!kIsWeb) {
          final fileName = Uri.parse(filePath).pathSegments.last;
          localFile = await _downloadVideo(filePath, fileName);
          updatedItem['file_path'] = localFile.path;
        } else {
          // Web → pakai URL asli
          updatedItem['file_path'] = filePath;
        }

        playlists.add(Playlist.fromJson(updatedItem));

        completed++;
        if (onProgress != null) onProgress(completed / data.length);
      } catch (e) {
        print('Failed to download one video: $e');
      }
    }

    return playlists;
  }

  Future<File> _downloadVideo(String url, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);

    if (await file.exists()) return file;

    try {
      final dio = Dio();
      await dio.download(url, filePath);
      return file;
    } catch (e) {
      print('Download failed: $e');
      rethrow;
    }
  }
}
