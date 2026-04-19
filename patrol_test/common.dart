import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:text_fixer_app/main.dart';
import 'package:text_fixer_app/text_correction_service.dart';

export 'package:flutter_test/flutter_test.dart';
export 'package:patrol/patrol.dart';

final _patrolTesterConfig = PatrolTesterConfig(printLogs: true);

class _NoopClipboardService implements ClipboardService {
  const _NoopClipboardService();

  @override
  Future<void> setText(String text) async {}
}

Future<void> createApp(
  PatrolIntegrationTester $,
  TextCorrectionService correctionService,
) async {
  await $.pumpWidgetAndSettle(
    MyApp(
      correctionService: correctionService,
      clipboardService: const _NoopClipboardService(),
    ),
  );
}

void patrol(
  String description,
  Future<void> Function(PatrolIntegrationTester) callback,
) {
  patrolTest(description, config: _patrolTesterConfig, callback);
}
