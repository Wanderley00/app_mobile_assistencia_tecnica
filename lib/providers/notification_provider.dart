// lib/providers/notification_provider.dart

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/notificacao.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _service = NotificationService();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  List<Notificacao> _notifications = [];
  List<Notificacao> get notifications => _notifications;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchUnreadCount() async {
    _unreadCount = await _service.getUnreadCount();
    notifyListeners();
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _service.getNotifications();
    } catch (e) {
      print("Erro ao buscar lista de notificações: $e");
    }
    _isLoading = false;
    notifyListeners();
    // Atualiza a contagem após buscar a lista completa
    await fetchUnreadCount();
  }

  Future<void> markOneAsRead(int notificationId) async {
    // Atualiza na UI primeiro para uma resposta instantânea
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].lida) {
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      // Recria o objeto para garantir que a UI atualize
      _notifications[index] = Notificacao(
        id: _notifications[index].id,
        mensagem: _notifications[index].mensagem,
        link: _notifications[index].link,
        lida: true, // A mudança principal
        dataCriacao: _notifications[index].dataCriacao,
      );
      notifyListeners();
    }
    // Envia a requisição para a API em segundo plano
    await _service.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    _unreadCount = 0;
    _notifications = _notifications
        .map((n) => Notificacao(
              id: n.id,
              mensagem: n.mensagem,
              link: n.link,
              lida: true,
              dataCriacao: n.dataCriacao,
            ))
        .toList();
    notifyListeners();
    await _service.markAllAsRead();
  }
}
