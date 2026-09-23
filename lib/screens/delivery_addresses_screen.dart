import 'package:flutter/material.dart';
import '../app.dart';
import '../services/account_store.dart';
import '../services/maps_service.dart';
import '../widgets/place_search_field.dart';

/// Manage saved delivery addresses (stored locally on the device).
class DeliveryAddressesScreen extends StatelessWidget {
  const DeliveryAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delivery addresses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: RiderApp.brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add address'),
      ),
      body: ListenableBuilder(
        listenable: AccountStore.instance,
        builder: (context, _) {
          final addresses = AccountStore.instance.addresses;
          if (addresses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No saved addresses yet.\nTap “Add address” to save one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5B616A)),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final a = addresses[index];
              final isDefault = a.isDefault ||
                  (AccountStore.instance.defaultAddress?.id == a.id);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RiderApp.surface,
                  borderRadius: BorderRadius.circular(18),
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
                      child: const Icon(Icons.location_on_rounded,
                          color: Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(a.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15)),
                              if (isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: RiderApp.brandGreenLight,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text('Default',
                                      style: TextStyle(
                                          color: Color(0xFF15803D),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(a.address,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (choice) {
                        switch (choice) {
                          case 'default':
                            AccountStore.instance.setDefaultAddress(a.id);
                          case 'delete':
                            AccountStore.instance.removeAddress(a.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'default', child: Text('Set as default')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context) {
    final labelCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    PlaceSuggestion? picked;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add delivery address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Label', hintText: 'Home, Work…'),
              ),
              const SizedBox(height: 12),
              PlaceSearchField(
                controller: addressCtrl,
                labelText: 'Address',
                hintText: 'Street, area, city',
                height: 150,
                onLocationChanged: (p) => picked = p,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty ||
                      addressCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Add a label and an address.')),
                    );
                    return;
                  }
                  AccountStore.instance.addAddress(
                    labelCtrl.text.trim(),
                    addressCtrl.text.trim(),
                    latitude: picked?.latitude,
                    longitude: picked?.longitude,
                  );
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}