// lib/utils/error_handler.dart
import 'dart:io';
import 'package:http/http.dart' as http;

class ErrorHandler {
  static String getUserFriendlyMessage(Object error) {
    print("Erro original: $error"); // Mantém o log técnico para o dev
    if (error is SocketException) {
      return "Falha na conexão. Verifique sua internet e tente novamente.";
    }
    if (error is http.ClientException) {
      return "Erro de comunicação com o servidor. Tente mais tarde.";
    }
    // Você pode adicionar mais casos específicos aqui, como para TimeoutException

    // Mensagem padrão para outros tipos de erro
    return "Ocorreu um erro inesperado. Por favor, contate o suporte.";
  }
}
