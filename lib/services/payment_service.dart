import 'api_client.dart';

class PaymentService {
  PaymentService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;

  Map<String, String> _auth(String token) => {
        'Authorization': 'Bearer $token',
      };

  Future<List<Map<String, dynamic>>> listBanks() async {
    final data = await api.get('/api/v1/banks');
    return (data['banks'] as List<dynamic>? ?? [])
        .map((b) => {'name': b['name'].toString(), 'code': b['code'].toString()})
        .toList();
  }

  Future<Map<String, String>?> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final data = await api.get(
      '/api/v1/banks/resolve?bank_code=$bankCode&account_number=$accountNumber',
    );
    if (data['account_name'] != null) {
      return {
        'account_name': data['account_name'].toString(),
        'account_number': data['account_number'].toString(),
        'bank_code': data['bank_code'].toString(),
      };
    }
    return null;
  }

  Future<Map<String, dynamic>> addWallet(
    String token, {
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    return await api.post(
      '/api/v1/rider/wallets',
      headers: _auth(token),
      body: {
        'bank_name': bankName,
        'bank_code': bankCode,
        'account_number': accountNumber,
        'account_name': accountName,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listWallets(String token) async {
    final data = await api.get('/api/v1/rider/wallets', headers: _auth(token));
    return (data['wallets'] as List<dynamic>? ?? [])
        .map((w) => Map<String, dynamic>.from(w))
        .toList();
  }

  Future<void> deleteWallet(String token, int id) async {
    await api.delete('/api/v1/rider/wallets/$id', headers: _auth(token));
  }

  Future<Map<String, dynamic>> withdraw(
    String token, {
    required double amount,
    required int walletId,
  }) async {
    return await api.post(
      '/api/v1/rider/withdraw',
      headers: _auth(token),
      body: {'amount': amount, 'wallet_id': walletId},
    );
  }

  Future<List<Map<String, dynamic>>> listWithdrawals(String token) async {
    final data = await api.get('/api/v1/rider/withdrawals', headers: _auth(token));
    return (data['withdrawals'] as List<dynamic>? ?? [])
        .map((w) => Map<String, dynamic>.from(w))
        .toList();
  }
}
