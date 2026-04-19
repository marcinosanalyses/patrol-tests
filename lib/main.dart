import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_correction_service.dart';

void main() {
  runApp(
    MyApp(correctionService: GeminiTextCorrectionService.fromEnvironment()),
  );
}

class AppKeys {
  static const inputField = Key('input-field');
  static const fixButton = Key('fix-button');
  static const retryButton = Key('retry-button');
  static const copyButton = Key('copy-button');
  static const copyErrorButton = Key('copy-error-button');
  static const outputText = Key('output-text');
  static const errorText = Key('error-text');
  static const loadingIndicator = Key('loading-indicator');
}

abstract class ClipboardService {
  Future<void> setText(String text);
}

class SystemClipboardService implements ClipboardService {
  const SystemClipboardService();

  @override
  Future<void> setText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.correctionService,
    this.clipboardService = const SystemClipboardService(),
  });

  final TextCorrectionService correctionService;
  final ClipboardService clipboardService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Fixer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: TextFixerScreen(
        correctionService: correctionService,
        clipboardService: clipboardService,
      ),
    );
  }
}

class TextFixerScreen extends StatefulWidget {
  const TextFixerScreen({
    super.key,
    required this.correctionService,
    required this.clipboardService,
  });

  final TextCorrectionService correctionService;
  final ClipboardService clipboardService;

  @override
  State<TextFixerScreen> createState() => _TextFixerScreenState();
}

class _TextFixerScreenState extends State<TextFixerScreen> {
  static const int _maxInputLength = 5000;

  final TextEditingController _controller = TextEditingController();

  bool _isLoading = false;
  String? _correctedText;
  String? _error;

  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_isLoading;

  Future<void> _submitText() async {
    final inputText = _controller.text.trim();
    if (inputText.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final corrected = await widget.correctionService.correctText(inputText);
      if (!mounted) {
        return;
      }
      setState(() {
        _correctedText = corrected;
        _error = null;
      });
    } on ConfigurationException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _correctedText = null;
      });
    } on TextCorrectionException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _correctedText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unexpected error. Please retry.';
        _correctedText = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String? text, String successMessage) async {
    if (text == null || text.isEmpty) {
      return;
    }

    await widget.clipboardService.setText(text);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _copyResult() async {
    await _copyToClipboard(_correctedText, 'Corrected text copied.');
  }

  Future<void> _copyError() async {
    await _copyToClipboard(_error, 'Error log copied.');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('EN/PL Text Fixer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste or write text in English or Polish. The app fixes typos, grammar, and style.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: AppKeys.inputField,
                controller: _controller,
                maxLength: _maxInputLength,
                maxLines: 8,
                minLines: 6,
                textInputAction: TextInputAction.newline,
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type or paste your text here...',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    key: AppKeys.fixButton,
                    onPressed: _canSubmit ? _submitText : null,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Fix text'),
                  ),
                  if (_correctedText != null || _error != null)
                    OutlinedButton.icon(
                      key: AppKeys.retryButton,
                      onPressed: _canSubmit ? _submitText : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                ],
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(
                    key: AppKeys.loadingIndicator,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _error!,
                          key: AppKeys.errorText,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: AppKeys.copyErrorButton,
                            onPressed: _copyError,
                            icon: const Icon(Icons.copy_all),
                            label: const Text('Copy error'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_correctedText != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Corrected text',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _correctedText!,
                          key: AppKeys.outputText,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: AppKeys.copyButton,
                            onPressed: _copyResult,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
