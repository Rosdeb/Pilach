import 'package:app/core/widgets/global_keyboard_dismiss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty tap dismisses focus only while keyboard is visible', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    Future<void> pumpWithInset(double bottomInset) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: bottomInset),
            ),
            child: GlobalKeyboardDismiss(
              child: Scaffold(
                body: Column(
                  children: [
                    TextField(focusNode: focusNode),
                    const Expanded(
                      child: ColoredBox(
                        key: Key('empty-space'),
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpWithInset(300);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(200, 150));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    await pumpWithInset(0);
    focusNode.requestFocus();
    await tester.pump();
    await tester.tapAt(const Offset(200, 150));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });
}
