// lib/api_client.dart (VERSÃO COMPLETA E FINAL)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'main.dart'; // Para a constante API_BASE_URL

// Exceção customizada para forçar o logout
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final String _baseUrl;
  http.Client _client;
  bool _isRefreshing = false;

  ApiClient(this._baseUrl) : _client = http.Client();

  // MÉTODOS PRIVADOS PARA GERENCIAR TOKENS

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  Future _saveTokens(String newAccessToken, String? newRefreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', newAccessToken);
    if (newRefreshToken != null) {
      await prefs.setString('refreshToken', newRefreshToken);
    }
  }

  // Lógica principal de renovação do token
  Future<bool> _handleTokenRefresh() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _client.post(
        Uri.parse('$_baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access'], data['refresh']);
        debugPrint("Token renovado com sucesso!");
        return true;
      } else {
        // Se a renovação falhar, o refresh token é inválido. Limpa apenas tokens.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        // Não limpa mais currentUserId - cache multiusuário
        return false;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> patch(
      String endpoint, Map<String, dynamic> body) async {
    return _request(() async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders();
      return _client.patch(url, headers: headers, body: jsonEncode(body));
    });
  }

  // WRAPPER DE REQUISIÇÃO INTELIGENTE

  Future<http.Response> _request(Future<http.Response> Function() makeRequest,
      {bool retry = true}) async {
    var response = await makeRequest();
    if (response.statusCode == 401 && retry) {
      debugPrint("Token expirado. Tentando renovar...");
      final bool success = await _handleTokenRefresh();
      if (success) {
        return await _request(makeRequest, retry: false);
      } else {
        throw UnauthorizedException(
            "Sessão inválida. Por favor, faça login novamente.");
      }
    }
    return response;
  }

  // MÉTODOS PÚBLICOS (GET, POST, etc.)

  Future<http.Response> get(String endpoint) async {
    return _request(() async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders();
      return _client.get(url, headers: headers);
    });
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    return _request(() async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders();
      return _client.post(url, headers: headers, body: jsonEncode(body));
    });
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    return _request(() async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders();
      return _client.put(url, headers: headers, body: jsonEncode(body));
    });
  }

  Future<http.Response> postMultipart(
      String endpoint, Map<String, dynamic> fields,
      {required String filePath, required String fileField}) async {
    var makeRequest = () async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final token = await _getAccessToken();
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      fields.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      if (filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(fileField, filePath,
            filename: p.basename(filePath)));
      }

      return http.Response.fromStream(await request.send());
    };

    var response = await makeRequest();
    if (response.statusCode == 401) {
      debugPrint("Token expirado em Multipart. Tentando renovar...");
      final success = await _handleTokenRefresh();
      if (success) {
        return await makeRequest();
      } else {
        throw UnauthorizedException(
            "Sessão inválida. Por favor, faça login novamente.");
      }
    }
    return response;
  }

  Future<http.Response> patchMultipart(
      String endpoint, Map<String, dynamic> fields,
      {required String filePath, required String fileField}) async {
    var makeRequest = () async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final token = await _getAccessToken();
      var request = http.MultipartRequest('PATCH', url); // <-- MUDANÇA AQUI
      request.headers['Authorization'] = 'Bearer $token';

      fields.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      if (filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(fileField, filePath,
            filename: p.basename(filePath)));
      }

      return http.Response.fromStream(await request.send());
    };

    // A lógica de retentativa de token é a mesma do postMultipart
    var response = await makeRequest();
    if (response.statusCode == 401) {
      debugPrint("Token expirado em Multipart PATCH. Tentando renovar...");
      final success = await _handleTokenRefresh();
      if (success) {
        return await makeRequest();
      } else {
        throw UnauthorizedException(
            "Sessão inválida. Por favor, faça login novamente.");
      }
    }
    return response;
  }

  Future<List<T>> getGenericList<T>(
      {required String endpoint,
      required T Function(Map<String, dynamic>) fromJson,
      required String cacheKey}) async {
    try {
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(data));
        return data
            .map((item) => fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Falha ao carregar dados da API. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (e is UnauthorizedException) rethrow; // Repassa a exceção para a UI
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final List data = jsonDecode(cachedData);
        return data
            .map((item) => fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    }
  }

  Future<http.Response> delete(String endpoint) async {
    return _request(() async {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders();
      return _client.delete(url, headers: headers);
    });
  }
}
