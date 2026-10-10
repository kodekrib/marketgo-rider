import 'api_client.dart';

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return (value as num?)?.toInt() ?? fallback;
}

double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return (value as num?)?.toDouble() ?? fallback;
}

String _str(Object? value) => value?.toString() ?? '';

/// A vehicle category the rider picks when completing KYC, from
/// GET /api/v1/rider/vehicle-types.
class RiderVehicleType {
  const RiderVehicleType({required this.id, required this.name, required this.label});

  final int id;
  final String name;
  final String label;

  factory RiderVehicleType.fromJson(Map<String, dynamic> json) {
    return RiderVehicleType(
      id: _int(json['id']),
      name: _str(json['name']),
      label: _str(json['label']).isEmpty ? _str(json['name']) : _str(json['label']),
    );
  }
}

/// The rider's verification profile returned by GET /api/v1/rider/kyc.
class RiderKYCRecord {
  const RiderKYCRecord({
    required this.userId,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleRegNo,
    required this.vehicleTypeName,
    required this.primaryAddress,
    required this.rating,
    required this.kycStatus,
  });

  final int userId;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleRegNo;
  final String vehicleTypeName;
  final String primaryAddress;
  final double rating;
  final String kycStatus;

  bool get isApproved => kycStatus == 'approved';
  bool get isPending => kycStatus == 'pending' || kycStatus == 'under_review';
  bool get isRejected => kycStatus == 'rejected';
  bool get isEmpty =>
      vehicleMake.isEmpty && vehicleModel.isEmpty && vehicleRegNo.isEmpty || kycStatus.isEmpty;

  factory RiderKYCRecord.fromJson(Map<String, dynamic> json) {
    return RiderKYCRecord(
      userId: _int(json['user_id']),
      vehicleMake: _str(json['vehicle_make']),
      vehicleModel: _str(json['vehicle_model']),
      vehicleRegNo: _str(json['vehicle_reg_no']),
      vehicleTypeName: _str(json['vehicle_type_name']),
      primaryAddress: _str(json['address']),
      rating: _double(json['rating']),
      kycStatus: _str(json['kyc_status']),
    );
  }
}

/// Rider-facing client for the verification (KYC) flow backed by the rider
/// onboarding profile: vehicle make/model, registration, category and docs.
class KYCService {
  KYCService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  Future<List<RiderVehicleType>> vehicleTypes(String token) async {
    final data = await api.get('/api/v1/rider/vehicle-types', headers: _auth(token));
    if (data['vehicle_types'] is! List) return const [];
    return (data['vehicle_types'] as List)
        .whereType<Map<String, dynamic>>()
        .map(RiderVehicleType.fromJson)
        .toList();
  }

  Future<RiderKYCRecord> profile(String token) async {
    final data = await api.get('/api/v1/rider/kyc', headers: _auth(token));
    final profile = data['profile'];
    return RiderKYCRecord.fromJson(
        profile is Map<String, dynamic> ? profile : data);
  }

  Future<RiderKYCRecord> submit(String token, Map<String, dynamic> payload) async {
    final data = await api.put('/api/v1/rider/kyc', body: payload, headers: _auth(token));
    final profile = data['profile'];
    return RiderKYCRecord.fromJson(
        profile is Map<String, dynamic> ? profile : data);
  }
}