import 'api_client.dart';

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return (value as num?)?.toInt() ?? fallback;
}

double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return (value as num?)?.toDouble() ?? fallback;
}

/// A customer's open request for delivery riders to bid on, as returned by
/// /api/v1/rider/requests/available and the `request.available` socket event.
class RiderDeliveryRequest {
  const RiderDeliveryRequest({
    required this.id,
    required this.type,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.phone,
    required this.packageDetails,
    required this.estFee,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.weightKg,
    this.offerCount = 0,
    this.storeName = '',
  });

  final int id;
  final String type;
  final String pickupAddress;
  final String deliveryAddress;
  final String phone;
  final String packageDetails;
  final double estFee;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? weightKg;
  final int offerCount;
  final String storeName;

  factory RiderDeliveryRequest.fromJson(Map<String, dynamic> json) {
    return RiderDeliveryRequest(
      id: _int(json['id']),
      type: json['type'] as String? ?? 'order',
      pickupAddress: json['pickup_address'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      packageDetails: json['package_details'] as String? ?? '',
      estFee: _double(json['est_fee']),
      status: json['status'] as String? ?? 'awaiting_offers',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      pickupLat: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLng: (json['pickup_longitude'] as num?)?.toDouble(),
      deliveryLat: (json['delivery_latitude'] as num?)?.toDouble(),
      deliveryLng: (json['delivery_longitude'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      offerCount: _int(json['offer_count']),
      storeName: json['store_name'] as String? ?? '',
    );
  }

  bool get isOpen =>
      status == 'awaiting_offers' && expiresAt.isAfter(DateTime.now());

  bool get hasCoords =>
      pickupLat != null && pickupLng != null &&
      deliveryLat != null && deliveryLng != null;

  /// Human label for the pickup point: order requests name their store,
  /// courier requests carry the pickup address.
  String get pickupLabel => storeName.isNotEmpty ? storeName : pickupAddress;

  /// Parcel info worth showing a rider (same convention as RiderDelivery).
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

/// A rider's submitted bid on a delivery request.
class RiderBidOffer {
  const RiderBidOffer({
    required this.id,
    required this.requestId,
    required this.riderId,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int requestId;
  final int riderId;
  final double price;
  final String status;
  final DateTime createdAt;

  factory RiderBidOffer.fromJson(Map<String, dynamic> json) {
    return RiderBidOffer(
      id: _int(json['id']),
      requestId: _int(json['request_id']),
      riderId: _int(json['rider_id']),
      price: _double(json['price']),
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Rider-facing client for the delivery-request/bidding flow.
class RequestService {
  RequestService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  /// Heartbeat the online/offline presence. Sent on toggle and on a timer
  /// while online so customers only see riders whose fix is fresh.
  Future<void> setPresence(
    String token, {
    required bool online,
    required double latitude,
    required double longitude,
  }) async {
    await api.post('/api/v1/rider/presence',
        body: {'online': online, 'latitude': latitude, 'longitude': longitude},
        headers: _auth(token));
  }

  /// Delivery requests open for bidding near the rider, newest first.
  Future<List<RiderDeliveryRequest>> availableRequests(String token) async {
    final data = await api.get('/api/v1/rider/requests/available',
        headers: _auth(token));
    if (data['requests'] is! List) return const [];
    return (data['requests'] as List)
        .whereType<Map<String, dynamic>>()
        .map(RiderDeliveryRequest.fromJson)
        .toList();
  }

  /// Bid on an open delivery request. The price becomes the delivery fee the
  /// customer sees on the choose-your-rider card.
  Future<RiderBidOffer> bid(
    String token,
    int requestId, {
    required double price,
  }) async {
    final data = await api.post('/api/v1/rider/requests/$requestId/bid',
        body: {'price': price}, headers: _auth(token));
    final offer = data['offer'];
    return RiderBidOffer.fromJson(
        offer is Map<String, dynamic> ? offer : const <String, dynamic>{});
  }
}