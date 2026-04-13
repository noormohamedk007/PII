import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // IMPORTANT: Update this URL based on your setup:
  // - Android emulator: 'http://10.0.2.2:5000'
  // - Real Android/iOS device: 'http://10.201.200.5:5000' (your computer's IP)
  // Get your PC IP: Run "ipconfig" in PowerShell, look for IPv4 Address
  static const String baseUrl = 'http://10.201.200.5:5000';
  static const String fingerprintToken = 'device_fingerprint_token';
  static String? _sessionCookieValue;

  static Map<String, String> get _defaultHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_sessionCookieValue != null && _sessionCookieValue!.isNotEmpty) {
      headers['Cookie'] = _sessionCookieValue!;
    }
    return headers;
  }

  static Uri _buildUri(String path) => Uri.parse('$baseUrl$path');

  static String? get sessionCookie => _sessionCookieValue;

  static void restoreSessionCookie(String cookie) {
    _sessionCookieValue = cookie;
  }

  static void clearSessionCookie() {
    _sessionCookieValue = null;
  }

  static void _storeCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _sessionCookieValue = setCookie.split(';').first;
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _buildUri('/register'),
      headers: _defaultHeaders,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _buildUri('/login'),
      headers: _defaultHeaders,
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    _storeCookie(response);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> logout() async {
    final response = await http.get(
      _buildUri('/logout'),
      headers: _defaultHeaders,
    );
    clearSessionCookie();
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> processDocument({
    required File file,
    required String docType,
    required String action,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _buildUri('/api/process'),
    );
    if (_sessionCookieValue != null && _sessionCookieValue!.isNotEmpty) {
      request.headers['Cookie'] = _sessionCookieValue!;
    }
    request.fields['doc_type'] = docType;
    request.fields['action'] = action;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Processing failed: ${response.statusCode} ${response.body}');
    }
  }

  static Future<bool> setPIN(String pin) async {
    final response = await http.post(
      _buildUri('/api/security/pin'),
      headers: _defaultHeaders,
      body: jsonEncode({'pin': pin}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> setFingerprint(String fingerprintData) async {
    final response = await http.post(
      _buildUri('/api/security/fingerprint'),
      headers: _defaultHeaders,
      body: jsonEncode({'fingerprint_data': fingerprintData}),
    );
    return response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getSecurityStatus() async {
    final response = await http.get(
      _buildUri('/api/security/status'),
      headers: _defaultHeaders,
    );
    return _handleResponse(response);
  }

  static Future<bool> verifyPIN(String pin) async {
    final response = await http.post(
      _buildUri('/api/security/verify-pin'),
      headers: _defaultHeaders,
      body: jsonEncode({'pin': pin}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> verifyFingerprint() async {
    final response = await http.post(
      _buildUri('/api/security/verify-fingerprint'),
      headers: _defaultHeaders,
      body: jsonEncode({'fingerprint_data': fingerprintToken}),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      _buildUri('/api/change-password'),
      headers: _defaultHeaders,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return _handleResponse(response);
  }

  static Future<bool> downloadDocument(String filename) async {
    try {
      final response = await http.get(
        _buildUri('/api/download/$filename'),
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        List<String> possiblePaths = [
          '/storage/emulated/0/Download',
          '/sdcard/Download',
          '/data/media/0/Download',
        ];

        for (String pathStr in possiblePaths) {
          try {
            final dir = Directory(pathStr);
            if (await dir.exists()) {
              final File file = File('$pathStr/$filename');
              await file.writeAsBytes(response.bodyBytes);
              return true;
            }
          } catch (e) {
            continue;
          }
        }

        final appDir = Directory('/data/data');
        try {
          final File file = File('${appDir.path}/$filename');
          await file.writeAsBytes(response.bodyBytes);
          return true;
        } catch (e) {
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Download error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAuditLogs() async {
    final response = await http.get(
      _buildUri('/audit-logs'),
      headers: _defaultHeaders,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load audit logs: ${response.statusCode}');
  }

  static String getDownloadUrl(String filename) =>
      '$baseUrl/download/$filename';

  static Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = null;
    }

    String message = 'Unknown error';
    if (jsonBody is Map<String, dynamic> && jsonBody['message'] != null) {
      message = jsonBody['message'].toString();
    } else if (response.reasonPhrase != null &&
        response.reasonPhrase!.isNotEmpty) {
      message = response.reasonPhrase!;
    }

    return {
      'status': response.statusCode,
      'success': response.statusCode >= 200 && response.statusCode < 400,
      'message': message,
      'data': jsonBody is Map<String, dynamic> ? jsonBody['data'] : jsonBody,
      'rawBody': response.body,
    };
  }
}
