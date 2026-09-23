import '../models/faq.dart';
import 'api_client.dart';

/// Loads the public FAQ list for the rider app (`/api/v1/faqs/rider`).
class FaqService {
  FaqService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  /// Fetches FAQs from the backend; returns bundled demo content when the
  /// backend isn't reachable (e.g. an offline demo session).
  Future<List<FaqEntry>> byTarget(String target) async {
    try {
      final data = await api.get('/api/v1/faqs/$target');
      final items = data['faqs'];
      if (items is List) {
        final parsed = items
            .whereType<Map<String, dynamic>>()
            .map(FaqEntry.fromJson)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
      return riderDemoFaqs();
    } on ApiException catch (e) {
      if (e.statusCode == 0) return riderDemoFaqs();
      rethrow;
    }
  }
}