// lib/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;
  bool _emailSentSuccessfully = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
      _emailSentSuccessfully = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/password_reset/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _message =
              'Se um e-mail correspondente for encontrado em nosso sistema, um token de redefinição de senha será enviado.';
          _isError = false;
          _emailSentSuccessfully = true;
        });
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage =
            responseData['detail'] ?? 'Falha ao enviar o e-mail.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        _message = 'Ocorreu um erro. Verifique sua conexão e tente novamente.';
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redefinir Senha'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Esqueceu sua senha?',
                  style: AppTextStyles.headline2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Não se preocupe! Insira seu e-mail abaixo para receber as instruções de recuperação.',
                  style: AppTextStyles.body2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira seu e-mail.';
                    }
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Por favor, insira um e-mail válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isError ? AppColors.error : AppColors.success)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError ? AppColors.error : AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_emailSentSuccessfully)
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _sendResetLink,
                          child: const Text('Enviar Link de Recuperação'),
                        ),
                if (_emailSentSuccessfully) ...[
                  const SizedBox(height: 24),
                  const Divider(thickness: 1),
                  const SizedBox(height: 24),
                  const Text(
                    'Já recebeu seu token?',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle1,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/reset_password_confirm');
                    },
                    child: const Text('Inserir Token e Redefinir Senha'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
