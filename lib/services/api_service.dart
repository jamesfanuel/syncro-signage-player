import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';
import '../models/license_validate_model.dart';
import '../constants/api_constants.dart';

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
  Future<List<Playlist>> fetchPlaylist() async {
    try {
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

      return data
          .where((item) =>
              item['file_path'] != null &&
              item['file_path'].toString().contains('.mp4'))
          .map((item) {
        final updatedItem = Map<String, dynamic>.from(item);
        final filePath = updatedItem['file_path'];
        if (filePath != null && !filePath.startsWith('http')) {
          updatedItem['file_path'] = '${ApiConstants.baseUrl}$filePath';
        }
        return Playlist.fromJson(updatedItem);
      }).toList();
    } catch (e) {
      print('Error in fetchPlaylist: $e');
      rethrow;
    }
  }
}
