// lib/screens/auth_check_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Garante que a verificação aconteça assim que o widget for construído.
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();

    // --- ALTERAÇÃO AQUI ---
    // Verifica a existência do REFRESH token, que representa a sessão de longa duração.
    final String? token = prefs.getString('refreshToken');
    // --- FIM DA ALTERAÇÃO ---

    if (!mounted) return;

    if (token != null) {
      // Se a sessão existe, vai para a lista de OS
      Navigator.of(context).pushReplacementNamed('/os_list');
    } else {
      // Se não há sessão, vai para o login
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostra um indicador de carregamento enquanto a verificação é feita.
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
