import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/settings/presentation/widgets/edit_name_dialog.dart';

/// Item 9 (quick check, not exhaustive re-testing of `NameValidator` itself
/// — that's already covered by `name_validator_test.dart`): confirms
/// `EditNameDialog` genuinely delegates to the shared `NameValidator`
/// instead of reimplementing its own ad-hoc rules, by exercising two rules
/// `NameValidator` is known to enforce (the 12-char cap and the profanity
/// filter) through the dialog's own Save button.
void main() {
  Future<void> pumpDialog(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [preferencesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEditNameDialog(context, initialName: ''),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a disallowed (profanity-filtered) name is rejected by the '
      'dialog\'s Save action -- proving it defers to the shared filter '
      'rather than only checking length/characters itself', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'fuck');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("isn't allowed"),
      findsOneWidget,
      reason: 'the shared NameValidator/ProfanityFilter rejected it, and '
          'the dialog is still open showing the inline rejection note',
    );
  });

  testWidgets('a name that fits the 12-grapheme cap and passes the filter '
      'is accepted (Save closes the dialog)', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'Aman');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(EditNameDialog), findsNothing, reason: 'a valid name saves and closes');
  });
}
