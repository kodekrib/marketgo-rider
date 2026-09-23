import 'package:flutter_test/flutter_test.dart';

import 'package:rider/app.dart';
import 'package:rider/widgets/route_animation.dart';

void main() {
  setUpAll(() => kRouteAnimationEnabled = false);

  testWidgets('Rider login screen renders with demo accounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RiderApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Courier'), findsOneWidget);
  });
}