// lib/services/notification_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';
import '../main.dart';
import '../models/notificacao.dart';

class NotificationService {
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  Future<List<Notificacao>> getNotifications() async {
    const String cacheKey = 'cached_notifications'; // Chave para o cache
    final prefs = await SharedPreferences.getInstance();

    try {
      // Tenta buscar da API se estiver online
      final response = await _apiClient.get('/notificacoes/');
      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        // Salva a resposta bem-sucedida no cache
        await prefs.setString(cacheKey, jsonString);
        final List<dynamic> data = jsonDecode(jsonString);
        return data.map((json) => Notificacao.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar notificações da API');
      }
    } catch (e) {
      print("Falha ao buscar notificações da API, tentando cache. Erro: $e");
      // Se a API falhar (ex: offline), tenta ler do cache
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final List<dynamic> data = jsonDecode(cachedData);
        return data.map((json) => Notificacao.fromJson(json)).toList();
      }
    }

    // Retorna uma lista vazia se estiver offline e sem cache
    return [];
  }

  Future<int> getUnreadCount() async {
    try {
      final response =
          await _apiClient.get('/notificacoes/nao-lidas/contagem/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['nao_lidas_count'] ?? 0;
      }
    } catch (e) {
      // Em caso de erro (ex: offline), retorna 0 para não quebrar a UI
      print("Erro ao buscar contagem de notificações: $e");
    }
    return 0;
  }

  Future<void> markAsRead(int notificationId) async {
    await _apiClient
        .post('/notificacoes/marcar-como-lida/', {'id': notificationId});
  }

  Future<void> markAllAsRead() async {
    await _apiClient
        .post('/notificacoes/marcar-como-lida/', {'marcar_todas': true});
  }
}
