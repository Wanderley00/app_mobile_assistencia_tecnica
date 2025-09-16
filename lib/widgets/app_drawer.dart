// lib/widgets/app_drawer.dart (VERSÃO CORRIGIDA)

import 'package:flutter/material.dart';
import '../main.dart'; // Para AppColors, AppTextStyles
import 'package:package_info_plus/package_info_plus.dart';

class AppDrawer extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const AppDrawer({super.key, required this.username, required this.onLogout});

  // --- MUDANÇA 1: O método _confirmLogout foi REMOVIDO daqui ---
  // A lógica de confirmação agora está centralizada e é mais inteligente
  // na tela OsListScreen, então este método se tornou redundante.

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                UserAccountsDrawerHeader(
                  accountName: Text(
                    'Olá, $username!',
                    style: AppTextStyles.subtitle1.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  accountEmail: null,
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  decoration: const BoxDecoration(color: AppColors.primary),
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Ordens de Serviço'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                // --- ADICIONE ESTE NOVO LISTTILE ---
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Minhas Despesas'),
                  onTap: () {
                    Navigator.of(context)
                        .pop(); // Fecha o drawer antes de navegar
                    Navigator.of(context).pushNamed('/my_expenses');
                  },
                ),
                const Divider(),
                // --- MUDANÇA 2: ListTile "Sair" foi alterada ---
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  // Agora, o onTap chama diretamente a função onLogout,
                  // que acionará o pop-up inteligente na tela anterior.
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              String versionText;
              if (snapshot.hasData) {
                versionText = 'Versão: ${snapshot.data!.version}';
              } else {
                versionText = 'Carregando versão...';
              }

              return Container(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'P3 Smart Solutions',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      versionText,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
