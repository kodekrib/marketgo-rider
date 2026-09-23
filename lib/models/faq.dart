/// A single FAQ entry served by `GET /api/v1/faqs/:target`.
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.question,
    required this.answer,
  });

  final int id;
  final String question;
  final String answer;

  factory FaqEntry.fromJson(Map<String, dynamic> json) {
    return FaqEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

/// Built-in help content shown for the rider app when the backend isn't
/// reachable (demo mode).
List<FaqEntry> riderDemoFaqs() {
  return const [
    FaqEntry(
      id: 1,
      question: 'How do I get delivery requests?',
      answer:
          'While you are online, delivery requests appear on your Home tab. '
          'Tap Accept to take one — the pickup and drop-off details are shown '
          'before you commit.',
    ),
    FaqEntry(
      id: 2,
      question: 'How do my earnings work?',
      answer:
          'You earn a delivery fee for every completed delivery. Fees are shown '
          'on each request before you accept, and earnings settle into your '
          'account after each completed delivery.',
    ),
    FaqEntry(
      id: 3,
      question: 'How do I withdraw my earnings?',
      answer:
          'Open Account → Withdraw Earnings, add your bank details once, then '
          'request a payout. Withdrawals are paid to the bank account you '
          'registered.',
    ),
    FaqEntry(
      id: 4,
      question: 'What if a customer doesn\'t show up?',
      answer:
          'Mark the delivery as complete from the navigation screen once you '
          'reach the drop-off. If you need help mid-delivery, contact support '
          'and a team member will assist.',
    ),
    FaqEntry(
      id: 5,
      question: 'How do I add my vehicle or insurance docs?',
      answer:
          'Open Account → My vehicle or Insurance & docs and follow the steps '
          'to submit your details for review. You are assigned deliveries only '
          'once your docs are approved.',
    ),
  ];
}