import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart' show AuthSession;
import '../services/payment_service.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _paymentService = PaymentService();
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _banks = [];
  bool _loading = true;
  bool _resolving = false;
  String? _resolvedName;

  final _accountController = TextEditingController();
  Map<String, dynamic>? _selectedBank;

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
        _paymentService.listBanks(),
      ]);
      if (mounted) {
        setState(() {
          _wallets = results[0];
          _banks = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveAccount() async {
    if (_selectedBank == null || _accountController.text.length < 10) return;
    setState(() {
      _resolving = true;
      _resolvedName = null;
    });
    try {
      final result = await _paymentService.resolveAccount(
        bankCode: _selectedBank!['code']!,
        accountNumber: _accountController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _resolvedName = result?['account_name'];
          _resolving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resolve account: $e')),
        );
      }
    }
  }

  Future<void> _addWallet() async {
    if (_selectedBank == null || _resolvedName == null) return;
    final token = AuthSession.instance.accessToken ?? '';
    try {
      await _paymentService.addWallet(
        token,
        bankName: _selectedBank!['name']!,
        bankCode: _selectedBank!['code']!,
        accountNumber: _accountController.text.trim(),
        accountName: _resolvedName!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account added')),
        );
        _accountController.clear();
        setState(() {
          _selectedBank = null;
          _resolvedName = null;
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteWallet(int id) async {
    final token = AuthSession.instance.accessToken ?? '';
    try {
      await _paymentService.deleteWallet(token, id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Bank Accounts'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAddForm(),
                  const SizedBox(height: 24),
                  Text(
                    'Saved Accounts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_wallets.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No bank accounts added yet.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ..._wallets.map((w) => _walletCard(w)),
                ],
              ),
            ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Bank Account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedBank,
              decoration: const InputDecoration(
                labelText: 'Bank',
                border: OutlineInputBorder(),
              ),
              items: _banks
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b['name']!, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (b) => setState(() {
                _selectedBank = b;
                _resolvedName = null;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _accountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Account Number (NUBAN)',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() => _resolvedName = null),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resolving ? null : _resolveAccount,
                  child: _resolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            ),
            if (_resolvedName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resolvedName!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _accountController.text,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addWallet,
                  child: const Text('Save Bank Account'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _walletCard(Map<String, dynamic> w) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: RiderApp.brandGreenLight,
          child: Icon(Icons.account_balance, color: RiderApp.brandGreenDark),
        ),
        title: Text(w['bank_name'] ?? ''),
        subtitle: Text('${w['account_name']}\n${w['account_number']}'),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteWallet(w['id']),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }
}
