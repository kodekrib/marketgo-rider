import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart' show AuthSession;
import '../services/payment_service.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _paymentService = PaymentService();
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  bool _submitting = false;

  final _amountController = TextEditingController();
  Map<String, dynamic>? _selectedWallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken ?? '';
    try {
      final results = await Future.wait([
        _paymentService.listWallets(token),
        _paymentService.listWithdrawals(token),
      ]);
      if (mounted) {
        setState(() {
          _wallets = results[0];
          _withdrawals = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 100 || _selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum withdrawal is ${RiderApp.currencySymbol}100')),
      );
      return;
    }
    setState(() => _submitting = true);
    final token = AuthSession.instance.accessToken ?? '';
    try {
      await _paymentService.withdraw(
        token,
        amount: amount,
        walletId: _selectedWallet!['id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted')),
        );
        _amountController.clear();
        setState(() => _selectedWallet = null);
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Withdraw Earnings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWithdrawForm(),
                  const SizedBox(height: 24),
                  Text(
                    'Withdrawal History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_withdrawals.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No withdrawals yet.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ..._withdrawals.map(_withdrawalCard),
                ],
              ),
            ),
    );
  }

  Widget _buildWithdrawForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_wallets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Add a bank account first in Account > Bank Accounts.'),
                    ),
                  ],
                ),
              )
            else ...[
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedWallet,
                decoration: const InputDecoration(
                  labelText: 'Withdraw to',
                  border: OutlineInputBorder(),
                ),
                items: _wallets
                    .map((w) => DropdownMenuItem(
                          value: w,
                          child: Text('${w['bank_name']} - ${w['account_number']}'),
                        ))
                    .toList(),
                onChanged: (w) => setState(() => _selectedWallet = w),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (${RiderApp.currencySymbol})',
                  border: const OutlineInputBorder(),
                  prefixText: '${RiderApp.currencySymbol} ',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitWithdrawal,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Request Withdrawal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _withdrawalCard(Map<String, dynamic> w) {
    final status = w['status'] ?? 'pending';
    final color = switch (status) {
      'completed' => Colors.green,
      'processing' => Colors.orange,
      'failed' => Colors.red,
      _ => Colors.grey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${RiderApp.currencySymbol}${(w['amount'] ?? 0).toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${w['bank_name']} • ${w['account_number']}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
