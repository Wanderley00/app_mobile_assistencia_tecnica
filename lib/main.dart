// main.dart (sem mudanças estruturais, apenas comentários sobre integração)

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:collection/collection.dart';

import 'database_helper.dart';
import 'os_repository.dart';
import 'sync_service.dart';
import 'auth_helper.dart'; // NOVO: importe o helper de autenticação
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/report_detail_screen.dart';
import 'screens/photo_form_screen.dart';
import 'screens/my_expenses_screen.dart';

// Importa as novas telas e widgets
import 'screens/login_screen.dart';
import 'screens/os_list_screen.dart';
import 'screens/os_detail_screen.dart';
import 'screens/report_form_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/document_form_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_confirm_screen.dart';
import 'widgets/status_badge.dart';
import 'widgets/os_card.dart';
import 'widgets/app_drawer.dart';
import 'widgets/wave_clipper.dart';
import 'widgets/info_row.dart';
import 'models/ordem_servico.dart';
import 'models/relatorio_campo.dart';
import 'models/despesa.dart';
import 'models/membro_equipe.dart';
import 'models/documento_os.dart';
import 'models/cliente.dart';
import 'models/equipamento.dart';
import 'models/tipo_documento.dart';
import 'models/categoria_despesa.dart';
import 'models/forma_pagamento.dart';
import 'models/registro_ponto.dart';
import 'screens/auth_check_screen.dart';
import 'screens/conclusion_signature_screen.dart';
import 'package:flutter_application/providers/os_list_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/providers/notification_provider.dart';
import 'package:flutter_application/screens/notification_screen.dart';

//import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const String API_BASE_URL = 'http://192.168.8.212:8000/api';

void main() async {
  // É uma boa prática inicializar o DB aqui
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';

  // IMPORTANTE: Não inicialize o DB aqui - deixe o lazy loading funcionar
  // O DatabaseHelper já gerencia a inicialização automaticamente

  runApp(const MyApp());
}

//--- CLASSES DE ESTILO (inalteradas) ---

class AppColors {
  static const primary = Color(0xFF1E3A8A);
  static const primaryLight = Color(0xFF3B82F6);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF59E0B);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x0F000000);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}

class AppTextStyles {
  static const headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  static const headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
  );
  static const subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const body1 = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  static const body2 = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => OsListProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        title: 'Serviço de Campo',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 1,
            titleTextStyle: AppTextStyles.headline2,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            color: AppColors.surface,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) =>
              const AuthCheckScreen(), // Rota raiz agora é a verificação
          '/login': (context) =>
              const LoginScreen(), // Rota específica para o login
          '/forgot_password': (context) => const ForgotPasswordScreen(),
          '/reset_password_confirm': (context) =>
              const ResetPasswordConfirmScreen(),
          '/os_list': (context) => const OsListScreen(),
          '/os_detail': (context) {
            final os =
                ModalRoute.of(context)!.settings.arguments as OrdemServico;
            return OsDetailScreen(osId: os.id, osNumero: os.numeroOs);
          },
          '/report_form': (context) => ReportFormScreen(
                ordemServicoId:
                    ModalRoute.of(context)!.settings.arguments as int,
              ),
          '/expense_form': (context) => ExpenseFormScreen(
                ordemServicoId:
                    ModalRoute.of(context)!.settings.arguments as int,
              ),
          '/document_form': (context) => DocumentFormScreen(
                ordemServicoId:
                    ModalRoute.of(context)!.settings.arguments as int,
              ),
          '/report_detail': (context) => ReportDetailScreen(
                relatorioId: ModalRoute.of(context)!.settings.arguments as int,
              ),
          '/photo_form': (context) => PhotoFormScreen(
                relatorioId: ModalRoute.of(context)!.settings.arguments as int,
              ),
          '/conclusion_signature': (context) {
            final osId = ModalRoute.of(context)!.settings.arguments as int;
            return ConclusionSignatureScreen(osId: osId);
          },
          '/my_expenses': (context) => const MyExpensesScreen(),
          '/notifications': (context) => const NotificationScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/*
INSTRUÇÕES DE INTEGRAÇÃO:

1. No LoginScreen, após login bem-sucedido, use AuthHelper.saveAuthData():
   
   // Exemplo no seu LoginScreen após resposta 200 da API:
   final userData = jsonDecode(response.body);
   await AuthHelper.saveAuthData(
     accessToken: userData['access'],
     refreshToken: userData['refresh'],
     currentUserId: userData['user']['id'].toString(), // ou email/username único
   );

2. No AppDrawer ou onde tiver o botão de logout, use AuthHelper.logout():
   
   // Substitua qualquer chamada a DatabaseHelper().clearAllUserData() por:
   await AuthHelper.logout();
   Navigator.pushReplacementNamed(context, '/login');

3. No AuthCheckScreen, use AuthHelper.isLoggedIn() para verificar se há sessão.

4. O DatabaseHelper automaticamente filtra dados pelo currentUserId salvo no SharedPreferences.

IMPORTANTE: O cache SQLite nunca mais será apagado no logout. Isso permite:
- Múltiplos usuários usarem o mesmo dispositivo
- Dados ficarem disponíveis offline mesmo após logout/login
- Sync automático de pendências específicas de cada usuário
*/
