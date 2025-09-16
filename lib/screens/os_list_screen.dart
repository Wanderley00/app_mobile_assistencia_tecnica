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

class OsListScreen extends StatefulWidget {
  const OsListScreen({super.key});

  @override
  State<OsListScreen> createState() => _OsListScreenState();
}

class _OsListScreenState extends State<OsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _inactivityTimer;
  static const _sessionTimeout = Duration(minutes: 20);

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
      }
    });
    // --- FIM DA CORREÇÃO ---

    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lastInteraction =
          context.read<OsListProvider>().lastInteractionTime;
      if (DateTime.now().difference(lastInteraction) > _sessionTimeout) {
        _logout(sessionExpired: true);
        _inactivityTimer?.cancel();
      }
    });
  }

  void _onUserInteraction() {
    context.read<OsListProvider>().updateInteractionTime();
  }

  void _filterOrdens() {
    context.read<OsListProvider>().filterOrdens(_searchController.text);
  }

  Future<void> _logout({bool sessionExpired = false}) async {
    // --- LÓGICA UNIFICADA DE LOGOUT ---

    // 1. PRIMEIRO, TRATA O CASO DE SESSÃO EXPIRADA (LOGOUT AUTOMÁTICO)
    if (sessionExpired) {
      await context.read<OsListProvider>().logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sua sessão expirou por inatividade.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 2. SE NÃO FOR SESSÃO EXPIRADA, É UM LOGOUT MANUAL DO USUÁRIO
    final hasPending = await context.read<OsListProvider>().hasPendingActions();

    if (!mounted) return;

    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        if (hasPending) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                SizedBox(width: 10),
                Text('Atenção!'),
              ],
            ),
            content: const Text(
                'Você possui dados não sincronizados. Se sair agora, todas as alterações feitas offline serão PERDIDAS PERMANENTEMENTE.\n\nDeseja continuar?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: const Text('Sair Mesmo Assim',
                    style: TextStyle(color: AppColors.error)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: const Text('Confirmar Saída'),
            content: const Text('Você tem certeza que deseja sair?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: const Text('Sair',
                    style: TextStyle(color: AppColors.error)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        }
      },
    );

    // 3. SÓ EXECUTA O LOGOUT SE O USUÁRIO CONFIRMOU A SAÍDA MANUAL
    if (confirmLogout == true) {
      await context.read<OsListProvider>().logout();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOrdens);
    _searchController.dispose();
    _inactivityTimer?.cancel();
    super.dispose();
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

    return GestureDetector(
      onTap: _onUserInteraction,
      onPanDown: (_) => _onUserInteraction(),
      child: Scaffold(
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
                    icon: const Icon(Icons.download),
                    tooltip: 'Baixar todas as ordens',
                    onPressed: osProvider.isBusy
                        ? null
                        : () {
                            if (osProvider.isOnline) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Baixando todas as ordens para acesso offline...'),
                                behavior: SnackBarBehavior.floating,
                              ));
                              context.read<OsListProvider>().fetchAllAndCache();
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
          ],
        ),
        drawer: AppDrawer(
          username: osProvider.username,
          onLogout: () => _logout(),
        ),
        body: Column(
          children: [
            if (!osProvider.isOnline) _buildOfflineBanner(),
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
                  // Chama o método que criamos no provider
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
                  // Define qual botão está selecionado com base no estado do provider
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
            Expanded(
              child: osProvider.filteredOrdensServico.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<OsListProvider>().syncAllChanges(),
                      child: ListView.builder(
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
                              context.read<OsListProvider>().syncAllChanges();
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
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
      ),
    );
  }
}
