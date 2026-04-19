import 'package:text_fixer_app/main.dart';
import 'package:text_fixer_app/text_correction_service.dart';

import '../common.dart';

void main() {
  patrol('Shows corrected text and allows copying it', ($) async {
    await createApp(
      $,
      SequenceTextCorrectionService(['This is the corrected version.']),
    );

    await $(AppKeys.inputField).enterText('A sample txt here');
    await $(AppKeys.fixButton).tap();

    await $(AppKeys.outputText).waitUntilVisible();
    expect($('This is the corrected version.'), findsOneWidget);
    await $(AppKeys.copyButton).tap();
    await $('Corrected text copied.').waitUntilVisible();
  });

  patrol('Retries correction and allows copying the retried result', ($) async {
    await createApp(
      $,
      SequenceTextCorrectionService([
        'This is the corrected version before retry.',
        'This is the retried corrected version.',
      ]),
    );

    await $(AppKeys.inputField).enterText('A sample txt here to be retried');
    await $(AppKeys.fixButton).tap();

    await $(AppKeys.outputText).waitUntilVisible();
    expect($('This is the corrected version before retry.'), findsOneWidget);

    await $(AppKeys.retryButton).tap();
    await $('This is the retried corrected version.').waitUntilVisible();
    expect($('This is the retried corrected version.'), findsOneWidget);

    await $(AppKeys.copyButton).tap();
    await $('Corrected text copied.').waitUntilVisible();
  });

  patrol('Shows an error and allows copying the error log', ($) async {
    const errorMessage = 'Gemini request failed (500): test failure';

    await createApp($, const FailingTextCorrectionService(errorMessage));

    await $(
      AppKeys.inputField,
    ).enterText('Sample text here, tutaj przykladowy tekst ');
    await $(AppKeys.fixButton).tap();

    await $(AppKeys.errorText).waitUntilVisible();
    expect($(errorMessage), findsOneWidget);

    await $(AppKeys.copyErrorButton).tap();
    await $('Error log copied.').waitUntilVisible();
  });
}

class SequenceTextCorrectionService implements TextCorrectionService {
  SequenceTextCorrectionService(this._responses);

  final List<String> _responses;
  int _callCount = 0;

  @override
  Future<String> correctText(String inputText) async {
    final index = _callCount < _responses.length
        ? _callCount
        : _responses.length - 1;
    _callCount += 1;
    return _responses[index];
  }
}

class FailingTextCorrectionService implements TextCorrectionService {
  const FailingTextCorrectionService(this._message);

  final String _message;

  @override
  Future<String> correctText(String inputText) {
    throw TextCorrectionException(_message);
  }
}
