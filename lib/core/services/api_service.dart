import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // For Android Emulator use 10.0.2.2, for iOS/Web use localhost
  // If running on a physical device, change this to your computer's local IP address (e.g., 192.168.1.x)
  static String get _baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2';
    }
    return 'http://127.0.0.1';
  }

  // Port mapping from docker-compose
  static const int _matchingServicePort = 8003;
  static const int _exportServicePort = 8005;
  static const int _aiServicePort = 8004;

  static String get _matchingServiceUrl => '$_baseUrl:$_matchingServicePort';
  static String get _exportServiceUrl => '$_baseUrl:$_exportServicePort';
  static String get _aiServiceUrl => '$_baseUrl:$_aiServicePort';

  Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> findMatches(String timelineId,
      {bool forceRefresh = false}) async {
    final url = Uri.parse('$_matchingServiceUrl/match');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'timeline_id': timelineId,
      'limit': 10,
      'force_refresh': forceRefresh,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load matches: ${response.body}');
      }
    } catch (e) {
      // Fallback for when running on device/emulator where localhost might fail
      // or if services aren't running
      debugPrint('API Error: $e');
      // Return mock data for demo purposes if API fails
      return [
        {
          'match_id': 'mock-1',
          'similarity': 0.89,
          'diagnosis': 'Lupus',
          'symptoms': ['Joint pain', 'Fatigue', 'Rash']
        },
        {
          'match_id': 'mock-2',
          'similarity': 0.76,
          'diagnosis': 'Ehlers-Danlos Syndrome',
          'symptoms': ['Joint pain', 'Hyper-mobility']
        },
        {
          'match_id': 'mock-3',
          'similarity': 0.68,
          'diagnosis': 'Sjögren\'s Syndrome',
          'symptoms': ['Dry eyes', 'Dry mouth']
        },
      ];
    }
  }

  Future<String> generatePdf(String timelineId) async {
    final url = Uri.parse('$_exportServiceUrl/export/pdf');
    final headers = await _getHeaders();
    final body = jsonEncode({'timeline_id': timelineId});

    final response = await http.post(url, headers: headers, body: body);
    debugPrint('PDF Export Response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['url'] == null) {
        throw Exception(
            'Backend returned null URL. Response: ${response.body}');
      }
      return data['url'];
    } else {
      throw Exception('Failed to generate PDF: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getAiDiagnosis(String timelineId) async {
    final url = Uri.parse('$_aiServiceUrl/diagnose');
    final headers = await _getHeaders();
    final body = jsonEncode({'timeline_id': timelineId});

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get AI diagnosis: ${response.body}');
    }
  }

  Future<String> sendMessage(
      String message, List<Map<String, String>> history) async {
    final url = Uri.parse('$_aiServiceUrl/chat');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'message': message,
      'history': history,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Future<void> submitFeedback(
      String timelineId, String matchId, bool isHelpful) async {
    final url = Uri.parse('$_matchingServiceUrl/feedback');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'timeline_id': timelineId,
      'match_id': matchId,
      'is_helpful': isHelpful,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Exception('Failed to submit feedback: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error submitting feedback: $e');
    }
  }
}

final apiService = ApiService();
