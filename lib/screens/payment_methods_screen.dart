import 'package:flutter/material.dart';
import '../app.dart';
import '../services/account_store.dart';

/// Saved payment methods (stored locally on the device).
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Payment methods'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: RiderApp.brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add card'),
      ),
      body: ListenableBuilder(
        listenable: AccountStore.instance,
        builder: (context, _) {
          final cards = AccountStore.instance.cards;
          if (cards.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No saved payment methods yet.\nAdd one to save it on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5B616A)),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = cards[index];
              final isDefault = c.isDefault ||
                  (AccountStore.instance.defaultCard?.id == c.id);
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
                      child: const Icon(Icons.credit_card_rounded,
                          color: Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${c.brand} •••• ${c.last4}',
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
                          Text('Expires ${c.expiry}',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (choice) {
                        switch (choice) {
                          case 'default':
                            AccountStore.instance.setDefaultCard(c.id);
                          case 'delete':
                            AccountStore.instance.removeCard(c.id);
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
    final brandCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add payment method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: brandCtrl,
              decoration: const InputDecoration(
                  labelText: 'Card type', hintText: 'Visa, Mastercard…'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.number,
              maxLength: 16,
              decoration: const InputDecoration(
                  labelText: 'Card number',
                  hintText: '•••• •••• •••• ••••'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: expiryCtrl,
              decoration:
                  const InputDecoration(labelText: 'Expiry', hintText: 'MM/YY'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final number = numberCtrl.text.trim();
                if (brandCtrl.text.trim().isEmpty || number.length < 4) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter card type and number.')),
                  );
                  return;
                }
                AccountStore.instance.addCard(
                  brandCtrl.text.trim().toUpperCase(),
                  number,
                  expiryCtrl.text.trim().isEmpty
                      ? '—'
                      : expiryCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Save card'),
            ),
          ],
        ),
      ),
    );
  }
}