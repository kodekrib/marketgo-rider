import 'api_client.dart';

/// Vehicle types the mover marketplace supports.
const moverVehicleTypes = ['pickup_truck', 'van', 'mini_truck', 'lorry'];

String moverVehicleLabel(String type) {
  switch (type) {
    case 'pickup_truck':
      return 'Pickup Truck';
    case 'van':
      return 'Van';
    case 'mini_truck':
      return 'Mini Truck';
    case 'lorry':
      return 'Lorry';
    default:
      return type;
  }
}

/// Rider-side projection of a moving job.
class MoverJob {
  const MoverJob({
    required this.id,
    required this.customerId,
    required this.riderId,
    required this.vehicleType,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.description,
    required this.itemCount,
    required this.extraPackers,
    required this.packerPrice,
    required this.totalPackerFee,
    required this.quotedPrice,
    required this.platformFee,
    required this.totalAmount,
    required this.status,
    required this.cancelReason,
    required this.customerName,
    required this.customerPhone,
    required this.riderName,
    required this.riderPhone,
    required this.vehicleName,
    required this.createdAt,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
  });

  final int id;
  final int customerId;
  final int? riderId;
  final String vehicleType;
  final String pickupAddress;
  final String deliveryAddress;
  final String description;
  final int itemCount;
  final int extraPackers;
  final double packerPrice;
  final double totalPackerFee;
  final double quotedPrice;
  final double platformFee;
  final double totalAmount;
  final String status;
  final String cancelReason;
  final String customerName;
  final String customerPhone;
  final String riderName;
  final String riderPhone;
  final String vehicleName;
  final DateTime createdAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;

  factory MoverJob.fromJson(Map<String, dynamic> json) {
    return MoverJob(
      id: (json['id'] as num?)?.toInt() ?? 0,
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      riderId: (json['rider_id'] as num?)?.toInt(),
      vehicleType: json['vehicle_type'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      description: json['description'] as String? ?? '',
      itemCount: (json['item_count'] as num?)?.toInt() ?? 1,
      extraPackers: (json['extra_pickers'] as num?)?.toInt() ?? 0,
      packerPrice: (json['packer_price'] as num?)?.toDouble() ?? 0,
      totalPackerFee: (json['total_packer_fee'] as num?)?.toDouble() ?? 0,
      quotedPrice: (json['quoted_price'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      cancelReason: json['cancel_reason'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String? ?? '',
      riderName: json['rider_name'] as String? ?? '',
      riderPhone: json['rider_phone'] as String? ?? '',
      vehicleName: json['vehicle_name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      pickupLat: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLng: (json['pickup_longitude'] as num?)?.toDouble(),
      deliveryLat: (json['delivery_latitude'] as num?)?.toDouble(),
      deliveryLng: (json['delivery_longitude'] as num?)?.toDouble(),
    );
  }

  bool get isActive =>
      status != 'delivered' && status != 'cancelled';

  /// Next status in the mover lifecycle.
  String? get nextStatus {
    switch (status) {
      case 'pending':
      case 'accepted':
        return 'en_route';
      case 'en_route':
        return 'arrived';
      case 'arrived':
        return 'loading';
      case 'loading':
        return 'in_transit';
      case 'in_transit':
        return 'delivered';
      default:
        return null;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Waiting for a mover';
      case 'accepted':
        return 'Accepted — heading to pickup';
      case 'en_route':
        return 'On the way to pickup';
      case 'arrived':
        return 'Arrived at pickup';
      case 'loading':
        return 'Loading items';
      case 'in_transit':
        return 'In transit to delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get nextButtonLabel {
    switch (nextStatus) {
      case 'en_route':
        return 'Start heading to pickup';
      case 'arrived':
        return 'Mark as Arrived';
      case 'loading':
        return 'Start Loading';
      case 'in_transit':
        return 'Start Trip';
      case 'delivered':
        return 'Mark as Delivered';
      default:
        return 'Continue';
    }
  }
}

/// Todays/unfinished mover earnings summary.
class MoverEarnings {
  const MoverEarnings({
    required this.completedJobs,
    required this.totalEarnings,
    required this.currency,
  });

  final int completedJobs;
  final double totalEarnings;
  final String currency;

  factory MoverEarnings.fromJson(Map<String, dynamic> json) {
    return MoverEarnings(
      completedJobs: (json['completed_jobs'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

/// Vehicle types available for registration, driven by the admin-managed
/// catalog via GET /api/v1/rider/vehicle-types.
class FleetVehicleType {
  const FleetVehicleType({
    required this.name,
    required this.label,
  });

  final String name;
  final String label;

  factory FleetVehicleType.fromJson(Map<String, dynamic> json) {
    return FleetVehicleType(
      name: json['name'] as String? ?? '',
      label: json['label'] as String? ?? (json['name'] as String? ?? ''),
    );
  }
}

/// A moving vehicle registered by the rider.
class MoverVehicle {
  const MoverVehicle({
    required this.id,
    required this.vehicleType,
    required this.brand,
    required this.model,
    required this.color,
    required this.registrationNumber,
    required this.capacity,
    required this.packerPrice,
    required this.maxPackers,
    required this.isActive,
  });

  final int id;
  final String vehicleType;
  final String brand;
  final String model;
  final String color;
  final String registrationNumber;
  final String capacity;
  final double packerPrice;
  final int maxPackers;
  final bool isActive;

  String get vehicleLabel {
    final parts = [if (brand.isNotEmpty) brand, if (model.isNotEmpty) model];
    return parts.isEmpty ? moverVehicleLabel(vehicleType) : parts.join(' ');
  }

  factory MoverVehicle.fromJson(Map<String, dynamic> json) {
    return MoverVehicle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      vehicleType: json['vehicle_type'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      registrationNumber: json['registration_number'] as String? ?? '',
      capacity: json['capacity'] as String? ?? '',
      packerPrice: (json['packer_price'] as num?)?.toDouble() ?? 0,
      maxPackers: (json['max_pickers'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Thin client over the rider mover endpoints (/api/v1/rider/moving-jobs/...).
class MoverService {
  MoverService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  Future<List<MoverJob>> available(String token, {String? vehicleType}) async {
    final query = vehicleType == null
        ? '/api/v1/rider/moving-jobs/available'
        : '/api/v1/rider/moving-jobs/available?vehicle_type=$vehicleType';
    final data = await api.get(query, headers: _auth(token));
    return _jobs(data['jobs']);
  }

  Future<MoverJob?> current(String token) async {
    try {
      final data = await api.get('/api/v1/rider/moving-jobs/current',
          headers: _auth(token));
      final j = data['job'];
      return j is Map<String, dynamic> ? MoverJob.fromJson(j) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<MoverJob>> history(String token) async {
    final data = await api.get('/api/v1/rider/moving-jobs/history',
        headers: _auth(token));
    return _jobs(data['jobs']);
  }

  Future<void> accept(String token, int jobId,
      {required double price, required double packerPrice}) async {
    await api.post('/api/v1/rider/moving-jobs/$jobId/accept',
        headers: _auth(token),
        body: {'price': price, 'packer_price': packerPrice});
  }

  Future<void> updateStatus(String token, int jobId, String status) async {
    await api.post('/api/v1/rider/moving-jobs/$jobId/status',
        headers: _auth(token), body: {'status': status});
  }

  /// Pushes the rider's current GPS fix for a live move so the customer and
  /// admin tracking screens can follow along.
  Future<void> updateLocation(
      String token, int jobId, double latitude, double longitude) async {
    await api.post('/api/v1/rider/moving-jobs/$jobId/location',
        headers: _auth(token),
        body: {'latitude': latitude, 'longitude': longitude});
  }

  Future<void> cancel(String token, int jobId, String reason) async {
    await api.post('/api/v1/rider/moving-jobs/$jobId/cancel',
        headers: _auth(token), body: {'reason': reason});
  }

  Future<MoverEarnings> earnings(String token) async {
    final data =
        await api.get('/api/v1/rider/mover-earnings', headers: _auth(token));
    return MoverEarnings.fromJson(data);
  }

  Future<List<MoverVehicle>> vehicles(String token) async {
    final data = await api.get('/api/v1/rider/vehicles', headers: _auth(token));
    return _vehicles(data['vehicles']);
  }

  Future<List<FleetVehicleType>> vehicleTypes(String token) async {
    final data =
        await api.get('/api/v1/rider/vehicle-types', headers: _auth(token));
    final list = data['vehicle_types'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(FleetVehicleType.fromJson)
        .toList();
  }

  Future<MoverVehicle> createVehicle(
    String token, {
    required String vehicleType,
    required String brand,
    required String model,
    required String color,
    required String registrationNumber,
    String capacity = '',
    double packerPrice = 0,
    int maxPackers = 0,
  }) async {
    final data = await api.post('/api/v1/rider/vehicles',
        headers: _auth(token),
        body: {
          'vehicle_type': vehicleType,
          'brand': brand,
          'model': model,
          'color': color,
          'registration_number': registrationNumber,
          'capacity': capacity,
          'packer_price': packerPrice,
          'max_pickers': maxPackers,
        });
    final v = data['vehicle'];
    if (v is Map<String, dynamic>) return MoverVehicle.fromJson(v);
    throw const ApiException('Unexpected vehicle payload');
  }

  Future<void> deleteVehicle(String token, int id) async {
    await api.delete('/api/v1/rider/vehicles/$id', headers: _auth(token));
  }

  List<MoverJob> _jobs(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MoverJob.fromJson)
        .toList();
  }

  List<MoverVehicle> _vehicles(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MoverVehicle.fromJson)
        .toList();
  }

  /// Demo jobs shown in an unauthenticated/demo session.
  static List<MoverJob> demoJobs() {
    return [
      MoverJob(
        id: 1001,
        customerId: 1,
        riderId: null,
        vehicleType: 'pickup_truck',
        pickupAddress: '12 Admiralty Way, Lekki Phase 1',
        deliveryAddress: '3 Bourdillon Road, Ikoyi',
        description: 'Sofa, fridge and 6 cartons',
        itemCount: 8,
        extraPackers: 2,
        packerPrice: 5000,
        totalPackerFee: 10000,
        quotedPrice: 0,
        platformFee: 0,
        totalAmount: 0,
        status: 'pending',
        cancelReason: '',
        customerName: 'Ada Obi',
        customerPhone: '+2348012345678',
        riderName: '',
        riderPhone: '',
        vehicleName: '',
        createdAt: DateTime(2026, 9, 12, 9, 15),
      ),
    ];
  }

  /// Demo vehicles shown in an unauthenticated/demo session.
  static List<MoverVehicle> demoVehicles() {
    return const [
      MoverVehicle(
        id: 1,
        vehicleType: 'pickup_truck',
        brand: 'Toyota',
        model: 'Hilux',
        color: '#16A34A',
        registrationNumber: 'LAG-560-JKK',
        capacity: '1.5 tons',
        packerPrice: 5000,
        maxPackers: 3,
        isActive: true,
      ),
      MoverVehicle(
        id: 2,
        vehicleType: 'van',
        brand: 'Toyota',
        model: 'Hiace',
        color: '#3B82F6',
        registrationNumber: 'LAG-112-MGA',
        capacity: '12 chairs',
        packerPrice: 4000,
        maxPackers: 2,
        isActive: true,
      ),
    ];
  }
}