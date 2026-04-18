import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_fixer_app/main.dart';
import 'package:text_fixer_app/text_correction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fix button is disabled for empty input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(correctionService: _FakeSuccessService('Corrected text')),
    );

    final fixButton = tester.widget<ElevatedButton>(
      find.byKey(AppKeys.fixButton),
    );
    expect(fixButton.onPressed, isNull);
  });

  testWidgets('successful correction shows output, retry and copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(correctionService: _FakeSuccessService('Corrected result')),
    );

    await tester.enterText(find.byKey(AppKeys.inputField), 'helo world');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.fixButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(AppKeys.outputText), findsOneWidget);
    expect(find.text('Corrected result'), findsOneWidget);
    expect(find.byKey(AppKeys.retryButton), findsOneWidget);
    expect(find.byKey(AppKeys.copyButton), findsOneWidget);
  });

  testWidgets('shows loading while waiting for correction', (
    WidgetTester tester,
  ) async {
    final completer = Completer<String>();
    await tester.pumpWidget(
      MyApp(correctionService: _FakeDelayedService(completer.future)),
    );

    await tester.enterText(find.byKey(AppKeys.inputField), 'Witam cie');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.fixButton));
    await tester.pump();

    expect(find.byKey(AppKeys.loadingIndicator), findsOneWidget);

    completer.complete('Witam cię');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loadingIndicator), findsNothing);
    expect(find.text('Witam cię'), findsOneWidget);
  });

  testWidgets('error path shows retry button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(correctionService: _FakeErrorService('Request failed')),
    );

    await tester.enterText(find.byKey(AppKeys.inputField), 'something');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.fixButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.errorText), findsOneWidget);
    expect(find.textContaining('Request failed'), findsOneWidget);
    expect(find.byKey(AppKeys.retryButton), findsOneWidget);
    expect(find.byKey(AppKeys.copyErrorButton), findsOneWidget);
  });

  testWidgets('copy error action sends visible error to clipboard', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });

    await tester.pumpWidget(
      MyApp(correctionService: _FakeErrorService('Visible error log')),
    );

    await tester.enterText(find.byKey(AppKeys.inputField), 'bad input');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.fixButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.copyErrorButton));
    await tester.pumpAndSettle();

    expect(copiedText, 'Visible error log');
    expect(find.text('Error log copied.'), findsOneWidget);

    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('copy action sends corrected text to clipboard', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });

    await tester.pumpWidget(
      MyApp(correctionService: _FakeSuccessService('Copied text value')),
    );

    await tester.enterText(find.byKey(AppKeys.inputField), 'copi me');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.fixButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.copyButton));
    await tester.pumpAndSettle();

    expect(copiedText, 'Copied text value');
    expect(find.text('Corrected text copied.'), findsOneWidget);

    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

class _FakeSuccessService implements TextCorrectionService {
  _FakeSuccessService(this.result);

  final String result;

  @override
  Future<String> correctText(String inputText) async => result;
}

class _FakeDelayedService implements TextCorrectionService {
  _FakeDelayedService(this.resultFuture);

  final Future<String> resultFuture;

  @override
  Future<String> correctText(String inputText) => resultFuture;
}

class _FakeErrorService implements TextCorrectionService {
  _FakeErrorService(this.message);

  final String message;

  @override
  Future<String> correctText(String inputText) async {
    throw TextCorrectionException(message);
  }
}
