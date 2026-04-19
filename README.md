# text_fixer_app

Flutter web app that fixes English/Polish text with Gemini.

## Run

```bash
flutter pub get
flutter run -d chrome --dart-define=GEMINI_API_KEY=your_api_key
```

Use local config (recommended):

```json
{
  "GEMINI_API_KEY": "your_api_key",
  "GEMINI_MODEL": "gemini-2.5-flash"
}
```

```bash
flutter run -d chrome --dart-define-from-file=env.local.json
```

## Tests

Widget tests:

```bash
flutter test
```

Run widget + Patrol web tests with report:

```bash
./scripts/run_tests_with_report.sh
```

Useful flags:

- `--headed` run Chrome in headed mode.
- `--open` open HTML report after run (macOS).
- `--patrol-only` skip `flutter test` and run only Patrol web.
- `--target patrol_test/web/<file>.dart` run a specific Patrol test file.

Examples:

```bash
./scripts/run_tests_with_report.sh --open
./scripts/run_tests_with_report.sh --headed --open
./scripts/run_tests_with_report.sh --patrol-only --target patrol_test/web/text_fixer_test.dart
```

Report output:

```bash
open build/patrol_web_report/index.html
```

## Notes

- Node.js is required for Patrol web (Playwright).
- Default Patrol target: `patrol_test/web/text_fixer_test.dart`.
