import 'package:text_fixer_app/main.dart';
import 'package:text_fixer_app/text_correction_service.dart';

import '../common.dart';

void main() {

    patrol('Check if adding text is possible and corrected version is received and can be copied', ($) async {
    await createApp(
      $,
      SequenceTextCorrectionService([
        'This is the corrected version.'
      ]),
    );

    await $(AppKeys.inputField).enterText('A sample txt here');
    await $(AppKeys.fixButton).tap();

    await $(AppKeys.outputText).waitUntilVisible();
    expect($('This is the corrected version.'), findsOneWidget);
    await $.platform.web.grantPermissions(
      permissions: ['clipboard-read', 'clipboard-write'],
    );
    await $(AppKeys.copyButton).tap();
    final clipboard = await $.platform.web.getClipboard();
    // Expects the corrected text to be written to the clipboard.
    expect(clipboard, 'This is the corrected version.');


  });
  
  patrol('Check if retry is possible and the retried response can be copied', ($) async {
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

    await $.platform.web.grantPermissions(
      permissions: ['clipboard-read', 'clipboard-write'],
    );
    await $(AppKeys.copyButton).tap();

    final clipboard = await $.platform.web.getClipboard();
    expect(clipboard, 'This is the retried corrected version.');
  });

  patrol('Check if error log can be copied', ($) async {
    const errorMessage = 'Gemini request failed (500): test failure';

    await createApp($, FailingTextCorrectionService(errorMessage));

    await $(AppKeys.inputField).enterText('Sample text here, tutaj przykladowy tekst ');
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
