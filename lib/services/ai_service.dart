import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  // Tidak perlu nullable, karena kalau null akan langsung lempar Exception
  final String _apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
  final String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// 🔹 Chat teks biasa
  Future<String> generateResponseFromText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('❌ API Key tidak ditemukan atau kosong.');
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/waphafid-code/fidh-ai',
          'X-Title': 'FIDH AI',
        },
        body: jsonEncode({
          'model': 'deepseek/deepseek-chat',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final content = data['choices']?[0]?['message']?['content'];
        if (content is String && content.isNotEmpty) {
          return content;
        }
        return "⚠️ Tidak ada balasan dari AI.";
      } else {
        return "❌ Error API (${response.statusCode}): ${response.body}";
      }
    } catch (e, stack) {
      debugPrint("❌ Error saat generate konten teks: $e\n$stack");
      return "Terjadi error: $e";
    }
  }

  /// 🔹 Chat streaming teks
  Stream<String> generateResponseStream(String prompt) async* {
    if (_apiKey.isEmpty) {
      throw Exception('❌ API Key tidak ditemukan atau kosong.');
    }

    try {
      final request = http.Request('POST', Uri.parse(_apiUrl))
        ..headers.addAll({
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/waphafid-code/fidh-ai',
          'X-Title': 'FIDH AI',
        })
        ..body = jsonEncode({
          'model': 'deepseek/deepseek-chat',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'stream': true,
        });

      final response = await request.send();

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            if (line.trim().isEmpty || !line.startsWith("data:")) continue;

            final payload = line.replaceFirst("data:", "").trim();
            if (payload == "[DONE]") return;

            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              final content = data['choices']?[0]?['delta']?['content'];
              if (content is String) yield content;
            } catch (e) {
              debugPrint("⚠️ Gagal parsing JSON streaming: $e");
            }
          }
        }
      } else {
        throw Exception(
            "Streaming gagal (${response.statusCode}): ${response.reasonPhrase}");
      }
    } catch (e, stack) {
      throw Exception("Terjadi error streaming: $e\n$stack");
    }
  }
}
