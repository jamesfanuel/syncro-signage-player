class LicenseValidationResponse {
  final String status;
  final LicenseData data;

  LicenseValidationResponse({
    required this.status,
    required this.data,
  });

  factory LicenseValidationResponse.fromJson(Map<String, dynamic> json) {
    return LicenseValidationResponse(
      status: json['status'],
      data: json['data'] != null ? LicenseData.fromJson(json['data']) : LicenseData.empty(),
    );
  }
}

class LicenseData {
  final int customerId;
  final int outletId;
  final int screenId;

  LicenseData({
    required this.customerId,
    required this.outletId,
    required this.screenId,
  });

  factory LicenseData.fromJson(Map<String, dynamic> json) {
    return LicenseData(
      customerId: json['customer_id'],
      outletId: json['outlet_id'],
      screenId: json['screen_id'],
    );
  }

  factory LicenseData.empty() {
    return LicenseData(
      customerId: 0,
      outletId: 0,
      screenId: 0,
    );
  }
}
