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
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final now = DateTime.now();

    for (var item in data) {
      try {
        final isTimed = (item['is_timed'] ?? 0) == 1;
        final startTimeStr = item['start_time']?.toString();
        final stopTimeStr = item['stop_time']?.toString();

        // Filter berdasarkan jam jika is_timed = 1
        if (isTimed && startTimeStr != null && stopTimeStr != null) {
          final startParts = startTimeStr.split(':').map(int.parse).toList();
          final stopParts = stopTimeStr.split(':').map(int.parse).toList();

          if (startParts.length < 2 || stopParts.length < 2) {
            completed++;
            if (onProgress != null) onProgress(completed / data.length);
            continue;
          }

          final startMinutes = startParts[0] * 60 + startParts[1];
          final stopMinutes = stopParts[0] * 60 + stopParts[1];
          final nowMinutes = now.hour * 60 + now.minute;

          if (nowMinutes < startMinutes || nowMinutes > stopMinutes) {
            completed++;
            if (onProgress != null) onProgress(completed / data.length);
            continue; // skip playlist ini
          }
        }

        final filePathStr = (item['file_path'] ?? '').toString().trim();
        if (filePathStr.isEmpty || !filePathStr.toLowerCase().endsWith('.mp4')) {
          completed++;
          if (onProgress != null) onProgress(completed / data.length);
          continue;
        }

        final updatedItem = Map<String, dynamic>.from(item);
        var filePath = filePathStr;

        if (!filePath.startsWith('http')) filePath = '${ApiConstants.baseUrl}$filePath';

        File? localFile;
        if (!kIsWeb) {
          final fileName = Uri.parse(filePath).pathSegments.last;
          localFile = await _downloadVideo(filePath, fileName);
          updatedItem['file_path'] = localFile.path;
        } else {
          updatedItem['file_path'] = filePath;
        }

        playlists.add(Playlist.fromJson(updatedItem));
        completed++;
        if (onProgress != null) onProgress(completed / data.length);
      } catch (e) {
        print('Failed to process one playlist: $e');
        completed++;
        if (onProgress != null) onProgress(completed / data.length);
      }
    }

    return playlists;
  }

  Future<File> _downloadVideo(String url, String fileName) async {
    // 1. Minta izin storage
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }
    }

    // 2. Tentukan folder eksternal publik
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
      // buat subfolder agar mudah dicari
      dir = Directory('${dir!.path}/Download/YourApp');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/$fileName');

    // 3. Kalau sudah ada, langsung return
    if (await file.exists()) return file;

    // 4. Download dengan Dio
    try {
      final dio = Dio();
      await dio.download(url, file.path);
      print('Downloaded file path: ${file.path}');
      return file;
    } catch (e) {
      print('Download failed: $e');
      rethrow;
    }
  }
}
