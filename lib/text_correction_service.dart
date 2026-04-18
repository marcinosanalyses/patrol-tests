import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class TextCorrectionService {
  Future<String> correctText(String inputText);
}

class GeminiTextCorrectionService implements TextCorrectionService {
  GeminiTextCorrectionService({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory GeminiTextCorrectionService.fromEnvironment({http.Client? client}) {
    return GeminiTextCorrectionService(
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      model: const String.fromEnvironment(
        'GEMINI_MODEL',
        defaultValue: 'gemini-2.5-flash',
      ),
      baseUrl: const String.fromEnvironment(
        'GEMINI_BASE_URL',
        defaultValue: 'https://generativelanguage.googleapis.com',
      ),
      client: client,
    );
  }

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _client;

  @override
  Future<String> correctText(String inputText) async {
    if (apiKey.trim().isEmpty) {
      throw const ConfigurationException(
        'Missing GEMINI_API_KEY. Start app with --dart-define=GEMINI_API_KEY=...'
      );
    }

    final uri = Uri.parse(
      '$baseUrl/v1beta/models/$model:generateContent?key=$apiKey',
    );

    const systemInstruction =
        'You are a careful proofreader. Fix typos, grammar, and style while '
        'preserving meaning. Keep the same language as input (English or Polish). '
        'Return only corrected text without explanations.';

    final payload = {
      'contents': [
        {
          'parts': [
            {
              'text': '$systemInstruction\n\nText to correct:\n$inputText',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
      },
    };

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TextCorrectionException(
        'Gemini request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const TextCorrectionException('Invalid Gemini response format.');
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const TextCorrectionException('No correction returned by Gemini.');
    }

    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw const TextCorrectionException('Invalid candidate format.');
    }

    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw const TextCorrectionException('Missing content in Gemini response.');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const TextCorrectionException('Missing text parts in Gemini response.');
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.write(text);
        }
      }
    }

    final corrected = buffer.toString().trim();
    if (corrected.isEmpty) {
      throw const TextCorrectionException('Gemini returned empty corrected text.');
    }

    return corrected;
  }
}

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TextCorrectionException implements Exception {
  const TextCorrectionException(this.message);

  final String message;

  @override
  String toString() => message;
}
