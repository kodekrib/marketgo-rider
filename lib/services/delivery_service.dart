import 'api_client.dart';

/// Rider-facing projection of a delivery (marketplace order or on-demand
/// courier) as returned by /api/v1/rider/*.
class RiderDelivery {
  const RiderDelivery({
    required this.id,
    required this.type,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.phone,
    required this.packageDetails,
    required this.fee,
    required this.customerName,
    required this.storeName,
    required this.riderName,
    this.weightKg,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.estimatedTime,
  });

  final int id;
  final String type;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final String phone;
  final String packageDetails;
  final double fee;
  final String customerName;
  final String storeName;
  final String riderName;
  final double? weightKg;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final DateTime? estimatedTime;

  factory RiderDelivery.fromJson(Map<String, dynamic> json) {
    return RiderDelivery(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'order',
      status: json['status'] as String? ?? 'pending',
      pickupAddress: json['pickup_address'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      packageDetails: json['package_details'] as String? ?? '',
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      customerName: json['customer_name'] as String? ?? 'Customer',
      storeName: json['store_name'] as String? ?? '',
      riderName: json['rider_name'] as String? ?? '',
      weightKg: json['weight_kg'] == null
          ? null
          : (json['weight_kg'] as num).toDouble(),
      pickupLat: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLng: (json['pickup_longitude'] as num?)?.toDouble(),
      deliveryLat: (json['delivery_latitude'] as num?)?.toDouble(),
      deliveryLng: (json['delivery_longitude'] as num?)?.toDouble(),
      estimatedTime: json['estimated_time'] == null
          ? null
          : DateTime.tryParse(json['estimated_time'] as String? ?? ''),
    );
  }

  bool get hasCoords =>
      pickupLat != null && pickupLng != null &&
      deliveryLat != null && deliveryLng != null;

  bool get isActive =>
      status != 'delivered' && status != 'cancelled';

  /// Human label for the delivery lifecycle.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Waiting for a rider';
      case 'accepted':
        return 'Heading to pickup';
      case 'picked_up':
        return 'Pickup complete';
      case 'in_transit':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get pickupLabel => storeName.isNotEmpty ? storeName : pickupAddress;

  /// Parcel info worth showing the rider: weight when known, else the package
  /// description, else nothing.
  String get parcelInfo {
    if (weightKg != null) {
      final label = weightKg == weightKg!.roundToDouble()
          ? weightKg!.toStringAsFixed(0)
          : weightKg!.toStringAsFixed(1);
      return 'Parcel: $label kg';
    }
    return packageDetails;
  }
}

class DeliveryEarnings {
  const DeliveryEarnings({
    required this.completedDeliveries,
    required this.totalEarnings,
    required this.currency,
  });

  final int completedDeliveries;
  final double totalEarnings;
  final String currency;

  factory DeliveryEarnings.fromJson(Map<String, dynamic> json) {
    return DeliveryEarnings(
      completedDeliveries: (json['completed_deliveries'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

/// Thin client over the rider delivery endpoints.
class DeliveryService {
  DeliveryService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  Future<List<RiderDelivery>> available(String token) async {
    final data = await api.get('/api/v1/rider/deliveries/available',
        headers: _auth(token));
    return _list(data['deliveries']);
  }

  Future<void> accept(String token, int deliveryId) async {
    await api.post('/api/v1/rider/deliveries/$deliveryId/accept',
        headers: _auth(token));
  }

  Future<RiderDelivery?> current(String token) async {
    try {
      final data = await api.get('/api/v1/rider/deliveries/current',
          headers: _auth(token));
      final d = data['delivery'];
      return d is Map<String, dynamic> ? RiderDelivery.fromJson(d) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<RiderDelivery>> myDeliveries(String token) async {
    final data =
        await api.get('/api/v1/rider/deliveries', headers: _auth(token));
    return _list(data['deliveries']);
  }

  Future<void> updateStatus(
      String token, int deliveryId, String status) async {
    await api.patch('/api/v1/rider/deliveries/$deliveryId/status',
        headers: _auth(token), body: {'status': status});
  }

  Future<void> updateLocation(
      String token, int deliveryId, double latitude, double longitude) async {
    await api.patch('/api/v1/rider/deliveries/$deliveryId/location',
        headers: _auth(token),
        body: {'latitude': latitude, 'longitude': longitude});
  }

  Future<DeliveryEarnings> earnings(String token) async {
    final data = await api.get('/api/v1/rider/earnings', headers: _auth(token));
    return DeliveryEarnings.fromJson(data);
  }

  List<RiderDelivery> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(RiderDelivery.fromJson)
        .toList();
  }
}