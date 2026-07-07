import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/code_graph.dart';

class AnalysisApiService {
  final String baseUrl;

  AnalysisApiService({required this.baseUrl});

  Future<CodeGraph> analyzeRepo(String repoUrl) async {
    final uri = Uri.parse('$baseUrl/analyze');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'repoUrl': repoUrl}),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200) {
      throw Exception(
        'Analiz başarısız (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CodeGraph.fromJson(json);
  }
}