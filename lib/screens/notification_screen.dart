// lib/screens/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Para formatar datas
import '../providers/notification_provider.dart';
import '../main.dart'; // Para os estilos

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Busca as notificações ao entrar na tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications();
    });
  }

  // Função para formatar a data de forma relativa (ex: "Hoje", "Ontem")
  String _formatRelativeDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inHours < 24 && now.day == localDate.day) {
      return 'Hoje, às ${DateFormat.Hm().format(localDate)}';
    } else if (difference.inHours < 48 && now.day - localDate.day == 1) {
      return 'Ontem, às ${DateFormat.Hm().format(localDate)}';
    } else {
      return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(localDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          // Botão para marcar todas como lidas
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como lidas',
            onPressed: () {
              context.read<NotificationProvider>().markAllAsRead();
            },
          )
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.notifications.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma notificação encontrada.',
                style: AppTextStyles.body2,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.fetchNotifications,
            child: ListView.builder(
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return Material(
                  color: notification.lida
                      ? Colors.transparent
                      : AppColors.primary.withOpacity(0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notification.lida
                          ? Colors.grey.shade300
                          : AppColors.primary,
                      child: Icon(
                        Icons.notifications,
                        color: notification.lida
                            ? Colors.grey.shade700
                            : Colors.white,
                      ),
                    ),
                    title: Text(
                      notification.mensagem,
                      style: TextStyle(
                        fontWeight: notification.lida
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      _formatRelativeDate(notification.dataCriacao),
                      style: AppTextStyles.caption,
                    ),
                    onTap: () {
                      if (!notification.lida) {
                        provider.markOneAsRead(notification.id);
                      }
                      // Aqui você pode adicionar a lógica de navegação se o 'notification.link' for usado
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
