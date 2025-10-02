// lib/screens/os_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/ordem_servico.dart';
import 'os_detail_screen.dart';
import '../widgets/os_card.dart';
import '../providers/os_list_provider.dart';
import '../widgets/app_drawer.dart';
import '../providers/notification_provider.dart';
import 'package:badges/badges.dart' as badges;

class OsListScreen extends StatefulWidget {
  const OsListScreen({super.key});

  @override
  State<OsListScreen> createState() => _OsListScreenState();
}

class _OsListScreenState extends State<OsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterOrdens);

    // --- INÍCIO DA CORREÇÃO ---
    // Usamos addPostFrameCallback para garantir que o contexto esteja pronto
    // para ser usado pelo Provider logo após a construção da tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Verifica se o widget ainda está "montado" (na tela) antes de usar o context
      if (mounted) {
        // Chama o método de inicialização que carrega o nome de usuário e os dados iniciais.
        // Isso força a atualização toda vez que a tela é carregada após um login.
        context.read<OsListProvider>().initialize();
        context.read<NotificationProvider>().fetchUnreadCount();
      }
    });
    // --- FIM DA CORREÇÃO ---
  }

  void _filterOrdens() {
    context.read<OsListProvider>().filterOrdens(_searchController.text);
  }

  Future<void> _refreshData() async {
    // Esta função será usada para o "puxar para atualizar"
    await Future.wait([
      context.read<OsListProvider>().syncAllChanges(),
      context.read<NotificationProvider>().fetchUnreadCount(),
    ]);
  }

  Future<void> _logout({bool sessionExpired = false}) async {
    // --- LÓGICA DE LOGOUT SIMPLIFICADA ---

    // 1. Trata o caso de sessão expirada (logout automático) sem pedir confirmação
    if (sessionExpired) {
      if (mounted) {
        // Mostra o aviso primeiro, antes de deslogar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sua sessão expirou por inatividade.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Executa o logout
        await context.read<OsListProvider>().logout();
      }
      return;
    }

    // 2. Para o logout manual, sempre mostra uma confirmação simples
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Você tem certeza que deseja sair?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child:
                  const Text('Sair', style: TextStyle(color: AppColors.error)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    // 3. Executa o logout se o usuário confirmou
    if (confirmLogout == true) {
      if (mounted) {
        await context.read<OsListProvider>().logout();
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOrdens);
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. ADICIONE ESTE NOVO MÉTODO ---
  Widget _buildSyncStatusBanner() {
    // --- INÍCIO DA CORREÇÃO ---
    // Agora, assistimos à propriedade 'isBusy', que é verdadeira tanto para Download quanto para Sincronização.
    final isBusy = context.select((OsListProvider p) => p.isBusy);
    final syncMessage = context.select((OsListProvider p) => p.syncMessage);

    // A condição agora verifica se o app está "ocupado" (isBusy)
    if (isBusy && syncMessage != null) {
      // --- FIM DA CORREÇÃO ---
      return Container(
        width: double.infinity,
        color: AppColors.primaryLight.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                syncMessage,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox
        .shrink(); // Não mostra nada se não estiver sincronizando
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(4.0),
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.textSecondary.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Você está offline',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma OS Encontrada',
              style: AppTextStyles.headline2
                  .copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Realize o download, tente sincronizar para buscar as ordens mais recentes ou ajuste os termos da sua busca.',
              style: AppTextStyles.body2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar Agora'),
              onPressed: context.watch<OsListProvider>().isBusy
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Sincronizando dados pendentes...'),
                        behavior: SnackBarBehavior.floating,
                      ));
                      context.read<OsListProvider>().syncAllChanges();
                    },
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final osProvider = context.watch<OsListProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordens de Serviço'),
        actions: [
          osProvider.isDownloading
              ? Container(
                  width: 48.0,
                  height: 48.0,
                  padding: const EdgeInsets.all(12.0),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons
                      .download_outlined), // Ícone atualizado para consistência
                  tooltip: 'Baixar todas as ordens',
                  onPressed: osProvider.isBusy
                      ? null
                      : () {
                          if (osProvider.isOnline) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  'Baixando todas as ordens e notificações...'), // Mensagem um pouco mais clara
                              behavior: SnackBarBehavior.floating,
                            ));

                            // --- INÍCIO DA CORREÇÃO ---
                            // 1. Pega a instância do NotificationProvider
                            final notificationProvider =
                                context.read<NotificationProvider>();

                            // 2. Chama a função de download passando o provider como argumento
                            context
                                .read<OsListProvider>()
                                .fetchAllAndCache(notificationProvider);
                            // --- FIM DA CORREÇÃO ---
                          } else {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  'Para realizar o download, você precisa estar conectado à internet.'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                ),
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return badges.Badge(
                position: badges.BadgePosition.topEnd(top: 0, end: 3),
                showBadge: notificationProvider.unreadCount > 0,
                badgeContent: Text(
                  notificationProvider.unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8), // Espaçamento
        ],
      ),
      drawer: AppDrawer(
        username: osProvider.username,
        onLogout: () => _logout(),
      ),
      // --- INÍCIO DA CORREÇÃO ---
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!osProvider.isOnline) _buildOfflineBanner(),

            // --- 2. ADICIONE A CHAMADA PARA O NOVO BANNER AQUI ---
            _buildSyncStatusBanner(),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 8), // Ajuste no padding
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar OS, cliente, equipamento...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ToggleButtons(
                onPressed: (int index) {
                  final newStatus = index == 0 ? 'Em andamento' : 'Concluída';
                  context
                      .read<OsListProvider>()
                      .setActiveStatusFilter(newStatus);
                },
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderColor: Colors.grey.shade300,
                selectedBorderColor: AppColors.primary,
                selectedColor: Colors.white,
                fillColor: AppColors.primary,
                color: AppColors.primary,
                constraints: BoxConstraints(
                  minHeight: 40.0,
                  minWidth: (MediaQuery.of(context).size.width - 36) / 2,
                ),
                isSelected: [
                  osProvider.activeStatusFilter == 'Em andamento',
                  osProvider.activeStatusFilter == 'Concluída',
                ],
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Em Andamento'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Concluídas'),
                  ),
                ],
              ),
            ),
            // 2. O WIDGET 'Expanded' FOI REMOVIDO DAQUI
            RefreshIndicator(
              onRefresh: _refreshData,
              child: osProvider.isBusy &&
                      osProvider.filteredOrdensServico.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : osProvider.filteredOrdensServico.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          // 3. AS DUAS PROPRIEDADES ABAIXO FORAM ADICIONADAS
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          //--------------------------------------------
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: osProvider.filteredOrdensServico.length,
                          itemBuilder: (context, index) {
                            final os = osProvider.filteredOrdensServico[index];
                            return OsCard(
                              ordemServico: os,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => OsDetailScreen(
                                      osId: os.id,
                                      osNumero: os.numeroOs,
                                    ),
                                  ),
                                );
                                _refreshData();
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      // --- FIM DA CORREÇÃO ---
      floatingActionButton: FloatingActionButton(
        onPressed: osProvider.isBusy
            ? null
            : () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Sincronizando dados pendentes...'),
                  behavior: SnackBarBehavior.floating,
                ));
                context.read<OsListProvider>().syncAllChanges();
              },
        tooltip: 'Sincronizar dados pendentes',
        child: osProvider.isSyncing
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3.0,
              )
            : const Icon(Icons.sync),
      ),
    );
  }
}
