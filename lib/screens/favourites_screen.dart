import 'package:flutter/material.dart';
import '../app.dart';
import '../services/account_store.dart';

/// Stores and products favourited from the MarketGO storefront (stored
/// locally). Reads the same favourites persisted per-device.
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _priceLabel(int price) {
    final s = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return '${RiderApp.currencySymbol}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Favourites'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: RiderApp.brandGreenDark,
          indicatorColor: RiderApp.brandGreen,
          unselectedLabelColor: const Color(0xFF5B616A),
          tabs: const [
            Tab(text: 'Stores'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ListenableBuilder(
            listenable: AccountStore.instance,
            builder: (context, _) {
              final stores = AccountStore.instance.favouriteStores;
              if (stores.isEmpty) {
                return const _EmptyFavourites(
                  icon: Icons.storefront_outlined,
                  message: 'Stores you favourite from the MarketGO storefront '
                      'will show up here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: stores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final s = stores[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: RiderApp.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: RiderApp.brandGreenLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Color(0xFF15803D)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              if (s.tagline.isNotEmpty)
                                Text(s.tagline,
                                    style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => AccountStore.instance
                              .toggleFavouriteStore(s),
                          icon: const Icon(Icons.favorite_rounded,
                              color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          ListenableBuilder(
            listenable: AccountStore.instance,
            builder: (context, _) {
              final products = AccountStore.instance.favouriteProducts;
              if (products.isEmpty) {
                return const _EmptyFavourites(
                  icon: Icons.favorite_border_rounded,
                  message: 'Products you favourite from the MarketGO storefront '
                      'will show up here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = products[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: RiderApp.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: RiderApp.brandGreenLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: Color(0xFF15803D)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text('${p.vendorName} · ${p.unit}',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        _PriceLabel(text: _priceLabel(p.price)),
                        IconButton(
                          onPressed: () => AccountStore.instance
                              .toggleFavouriteProduct(p),
                          icon: const Icon(Icons.favorite_rounded,
                              color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13));
  }
}

class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9AA1AA)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}