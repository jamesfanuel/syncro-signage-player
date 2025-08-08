class ApiConstants {
  // static const String baseUrl = 'https://syncrosignage.com';
  static const String baseUrl = 'http://192.168.210.86:8000';

  static String get validateCodeUrl => '$baseUrl/api/license/validate';

  static String playlistUrl(int customerId, int outletId, int screenId) =>
      '$baseUrl/api/playlist/get/$customerId/$outletId/$screenId';
}
