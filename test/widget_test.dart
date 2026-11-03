import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_roast/core/widgets/empty_state_widget.dart';

void main() {
  testWidgets('EmptyStateWidget renders its message and icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            message: 'Nothing here yet',
            icon: Icons.leaderboard_rounded,
          ),
        ),
      ),
    );

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.byIcon(Icons.leaderboard_rounded), findsOneWidget);
    // No retry button unless a callback is supplied.
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('EmptyStateWidget shows retry button when a callback is given',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            message: 'Failed to load',
            onRetry: () {},
            retryButtonText: 'Try again',
          ),
        ),
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
