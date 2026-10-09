import 'package:flutter_test/flutter_test.dart';

import 'package:rider/app.dart';
import 'package:rider/widgets/route_animation.dart';

void main() {
  setUpAll(() => kRouteAnimationEnabled = false);

  testWidgets('Rider login screen renders its sign-in form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RiderApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Test mode'), findsNothing);
    expect(find.text('Demo account'), findsNothing);
  });
}