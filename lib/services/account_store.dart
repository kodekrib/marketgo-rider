import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved delivery address (local-first, stored on the device).
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String address;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  SavedAddress copyWith({bool? isDefault}) => SavedAddress(
        id: id,
        label: label,
        address: address,
        isDefault: isDefault ?? this.isDefault,
        latitude: latitude,
        longitude: longitude,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'isDefault': isDefault,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        address: json['address'] as String? ?? '',
        isDefault: json['isDefault'] == true,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

/// A saved payment card (local-first).
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiry,
    this.isDefault = false,
  });

  final String id;
  final String brand;
  final String last4;
  final String expiry;
  final bool isDefault;

  PaymentMethod copyWith({bool? isDefault}) => PaymentMethod(
        id: id,
        brand: brand,
        last4: last4,
        expiry: expiry,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'brand': brand, 'last4': last4, 'expiry': expiry, 'isDefault': isDefault};

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: json['id'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        last4: json['last4'] as String? ?? '',
        expiry: json['expiry'] as String? ?? '',
        isDefault: json['isDefault'] == true,
      );
}

/// A store favourited from the storefront (id + display fields only).
class FavouriteStore {
  const FavouriteStore({
    required this.id,
    required this.name,
    required this.tagline,
  });

  final String id;
  final String name;
  final String tagline;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'tagline': tagline};

  factory FavouriteStore.fromJson(Map<String, dynamic> json) => FavouriteStore(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        tagline: json['tagline'] as String? ?? '',
      );
}

/// A product favourited from the storefront.
class FavouriteProduct {
  const FavouriteProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.vendorName,
  });

  final String id;
  final String name;
  final String unit;
  final int price;
  final String vendorName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'vendorName': vendorName,
      };

  factory FavouriteProduct.fromJson(Map<String, dynamic> json) =>
      FavouriteProduct(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
        vendorName: json['vendorName'] as String? ?? '',
      );
}

/// Local-first store for the rider's account data — default delivery
/// addresses, saved payment methods and favourites. Everything persists via
/// shared_preferences on this device (no backend round-trips).
///
/// Singleton, mirrored after [AuthSession]; widgets read it with
/// `ListenableBuilder(listenable: AccountStore.instance)`.
class AccountStore extends ChangeNotifier {
  AccountStore._();

  static final AccountStore instance = AccountStore._();

  static const _kAddresses = 'rider.account.addresses';
  static const _kCards = 'rider.account.cards';
  static const _kFavStores = 'rider.account.fav_stores';
  static const _kFavProducts = 'rider.account.fav_products';

  List<SavedAddress> _addresses = [];
  List<PaymentMethod> _cards = [];
  List<FavouriteStore> _favStores = [];
  List<FavouriteProduct> _favProducts = [];
  bool _loaded = false;
  bool _seeded = false;

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);
  List<PaymentMethod> get cards => List.unmodifiable(_cards);
  List<FavouriteStore> get favouriteStores => List.unmodifiable(_favStores);
  List<FavouriteProduct> get favouriteProducts => List.unmodifiable(_favProducts);

  SavedAddress? get defaultAddress {
    for (final a in _addresses) {
      if (a.isDefault) return a;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  PaymentMethod? get defaultCard {
    for (final c in _cards) {
      if (c.isDefault) return c;
    }
    return _cards.isEmpty ? null : _cards.first;
  }

  bool isFavouriteStore(String id) => _favStores.any((s) => s.id == id);

  bool isFavouriteProduct(String id) => _favProducts.any((p) => p.id == id);

  /// Loads persisted state once. Safe to call every build; no-ops afterwards.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _addresses = _readList(prefs, _kAddresses, SavedAddress.fromJson);
    _cards = _readList(prefs, _kCards, PaymentMethod.fromJson);
    _favStores = _readList(prefs, _kFavStores, FavouriteStore.fromJson);
    _favProducts = _readList(prefs, _kFavProducts, FavouriteProduct.fromJson);
    if (_addresses.isEmpty && !_seeded) {
      _seeded = true;
      _addresses = const [
        SavedAddress(
          id: 'addr-home',
          label: 'Home',
          address: '2 Bode Thomas Street, Lekki',
          isDefault: true,
        ),
        SavedAddress(
          id: 'addr-work',
          label: 'Work',
          address: '14 Admiralty Way, Victoria Island',
        ),
      ];
      await _persist(prefs, _kAddresses, _addresses);
    }
    _loaded = true;
    notifyListeners();
  }

  // -- Addresses -------------------------------------------------------------

  Future<void> addAddress(
    String label,
    String address, {
    double? latitude,
    double? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _addresses = [
      ..._addresses,
      SavedAddress(
        id: 'addr-${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        address: address,
        isDefault: _addresses.isEmpty,
        latitude: latitude,
        longitude: longitude,
      ),
    ];
    notifyListeners();
    await _persist(prefs, _kAddresses, _addresses);
  }

  Future<void> removeAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final wasDefault = defaultAddress?.id == id;
    _addresses = _addresses.where((a) => a.id != id).toList();
    if (wasDefault && _addresses.isNotEmpty) {
      _addresses = [
        _addresses.first.copyWith(isDefault: true),
        ..._addresses.skip(1),
      ];
    }
    notifyListeners();
    await _persist(prefs, _kAddresses, _addresses);
  }

  Future<void> setDefaultAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _addresses = [
      for (final a in _addresses) a.copyWith(isDefault: a.id == id),
    ];
    notifyListeners();
    await _persist(prefs, _kAddresses, _addresses);
  }

  // -- Payment methods -------------------------------------------------------

  Future<void> addCard(String brand, String number, String expiry) async {
    final prefs = await SharedPreferences.getInstance();
    final last4 =
        number.length >= 4 ? number.substring(number.length - 4) : number;
    _cards = [
      ..._cards,
      PaymentMethod(
        id: 'card-${DateTime.now().microsecondsSinceEpoch}',
        brand: brand,
        last4: last4,
        expiry: expiry,
        isDefault: _cards.isEmpty,
      ),
    ];
    notifyListeners();
    await _persist(prefs, _kCards, _cards);
  }

  Future<void> removeCard(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final wasDefault = defaultCard?.id == id;
    _cards = _cards.where((c) => c.id != id).toList();
    if (wasDefault && _cards.isNotEmpty) {
      _cards = [defaultCard!];
    }
    notifyListeners();
    await _persist(prefs, _kCards, _cards);
  }

  Future<void> setDefaultCard(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _cards = [for (final c in _cards) c.copyWith(isDefault: c.id == id)];
    notifyListeners();
    await _persist(prefs, _kCards, _cards);
  }

  // -- Favourites ------------------------------------------------------------

  Future<void> toggleFavouriteStore(FavouriteStore store) async {
    final prefs = await SharedPreferences.getInstance();
    if (isFavouriteStore(store.id)) {
      _favStores = _favStores.where((s) => s.id != store.id).toList();
    } else {
      _favStores = [..._favStores, store];
    }
    notifyListeners();
    await _persist(prefs, _kFavStores, _favStores);
  }

  Future<void> toggleFavouriteProduct(FavouriteProduct product) async {
    final prefs = await SharedPreferences.getInstance();
    if (isFavouriteProduct(product.id)) {
      _favProducts = _favProducts.where((p) => p.id != product.id).toList();
    } else {
      _favProducts = [..._favProducts, product];
    }
    notifyListeners();
    await _persist(prefs, _kFavProducts, _favProducts);
  }

  // -- Persistence -----------------------------------------------------------

  List<T> _readList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <T>[];
      return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _persist<T>(SharedPreferences prefs, String key, List<T> items) {
    return prefs.setString(
      key,
      jsonEncode([
        for (final item in items)
          if (item is SavedAddress)
            item.toJson()
          else if (item is PaymentMethod)
            item.toJson()
          else if (item is FavouriteStore)
            item.toJson()
          else if (item is FavouriteProduct)
            item.toJson(),
      ]),
    );
  }
}