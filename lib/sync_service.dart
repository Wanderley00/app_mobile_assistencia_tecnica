// sync_service.dart

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'main.dart';
import 'api_client.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  // --- O MÉTODO FALTANTE FOI ADICIONADO DE VOLTA AQUI ---
  Future<List<int>> getDistinctOsIdsFromPendingActions() async {
    return await _dbHelper.getDistinctOsIdsFromPendingActions();
  }

  // --- 1. MÉTODO AUXILIAR ADICIONADO ---
  String _getActionDescription(String actionType) {
    switch (actionType) {
      case 'create_report':
        return 'Criando relatório';
      case 'edit_report':
        return 'Editando relatório';
      case 'create_expense':
        return 'Registrando despesa';
      case 'edit_expense':
        return 'Editando despesa';
      case 'delete_expense':
        return 'Deletando despesa';
      case 'add_document':
        return 'Enviando documento';
      case 'edit_document':
        return 'Editando documento';
      case 'delete_document':
        return 'Deletando documento';
      case 'register_ponto_entrada':
        return 'Marcando ponto de entrada';
      case 'register_ponto_saida':
        return 'Encerrando ponto de saída';
      case 'add_photo':
        return 'Enviando foto';
      default:
        return 'Processando ação';
    }
  }

  // --- 2. MÉTODO PRINCIPAL MODIFICADO ---
  Future<void> processSyncQueue(Function(String?) onProgress) async {
    print("Verificando a fila de sincronização...");
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      print("Offline. A sincronização será adiada.");
      return;
    }

    final pendingActions = await _dbHelper.getPendingActions();
    if (pendingActions.isEmpty) {
      print("Fila de sincronização vazia.");
      return;
    }

    final totalActions = pendingActions.length;
    int currentActionIndex = 0;

    print("Itens pendentes na fila: $totalActions. Iniciando sincronização...");

    for (var action in pendingActions) {
      currentActionIndex++;
      final actionDescription =
          _getActionDescription(action['action'] as String);
      final progressMessage =
          'Sincronizando ${currentActionIndex} de ${totalActions}: $actionDescription...';

      // Chama o callback para notificar a UI do progresso
      onProgress(progressMessage);

      try {
        final success = await _syncAction(action);
        if (success) {
          await _dbHelper.deletePendingAction(action['id'] as int);
          print(
              "Ação ${action['id']} ($actionDescription) sincronizada e removida.");
        } else {
          print(
              "Falha ao sincronizar a ação ${action['id']}. Permanecerá na fila.");
        }
      } catch (e) {
        print("Erro ao processar a ação ${action['id']}: $e");
      }
    }

    // Limpa a mensagem de progresso no final
    onProgress(null);
    print("Processamento da fila de sincronização concluído.");
  }

  Future<bool> _syncAction(Map action) async {
    final payload = jsonDecode(action['payload']);
    final osId = action['os_id'];
    final actionType = action['action'];
    try {
      http.Response response;
      switch (actionType) {
        case 'create_report':
          response = await _apiClient.post(
              '/ordens-servico/$osId/relatorios/', payload);
          break;
        case 'edit_report':
          final relatorioId = payload.remove('relatorio_id');
          response =
              await _apiClient.put('/relatorios-campo/$relatorioId/', payload);
          break;
        case 'create_expense':
          if (payload.containsKey('comprovante_caminho') &&
              payload['comprovante_caminho'] != null) {
            final filePath = payload.remove('comprovante_caminho');
            response = await _apiClient.postMultipart(
              '/ordens-servico/$osId/despesas/',
              payload,
              filePath: filePath,
              fileField: 'comprovante_anexo',
            );
          } else {
            response = await _apiClient.post(
                '/ordens-servico/$osId/despesas/', payload);
          }
          break;
        case 'add_document':
          final filePathDoc = payload.remove('arquivo_caminho');
          response = await _apiClient.postMultipart(
            '/ordens-servico/$osId/documentos/',
            payload,
            filePath: filePathDoc,
            fileField: 'arquivo',
          );
          break;
        case 'register_ponto_entrada':
          response =
              await _apiClient.post('/ordens-servico/$osId/pontos/', payload);
          break;
        case 'register_ponto_saida':
          final pontoId = payload['ponto_id'];
          payload.remove('ponto_id');
          response = await _apiClient.put('/pontos/$pontoId/', payload);
          break;
        case 'edit_expense':
          final despesaId = payload.remove('despesa_id');
          if (payload.containsKey('comprovante_caminho') &&
              payload['comprovante_caminho'] != null) {
            final filePath = payload.remove('comprovante_caminho');
            response = await _apiClient.patchMultipart(
              '/despesas/$despesaId/',
              payload,
              filePath: filePath,
              fileField: 'comprovante_anexo',
            );
          } else {
            response = await _apiClient.put('/despesas/$despesaId/', payload);
          }
          break;
        case 'delete_expense':
          final despesaIdDel = payload['despesa_id'];
          response = await _apiClient.delete('/despesas/$despesaIdDel/');
          return response.statusCode == 204;
        case 'edit_document':
          final docId = payload.remove('documento_id');
          response = await _apiClient.put('/documentos/$docId/', payload);
          break;
        case 'delete_document':
          final documentoId = payload['documento_id'];
          response = await _apiClient.delete('/documentos/$documentoId/');
          return response.statusCode == 204;
        case 'add_photo':
          final relatorioId = payload['relatorio_id'];
          final imagePath = payload['local_image_path'];
          final description = payload['descricao'];
          response = await _apiClient.postMultipart(
            '/relatorios-campo/$relatorioId/fotos/',
            {'descricao': description},
            filePath: imagePath,
            fileField: 'imagem',
          );
          break;
        default:
          print("Ação desconhecida: $actionType");
          return false;
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("Erro na chamada de API para a ação '$actionType': $e");
      return false;
    }
  }

  Future<bool> hasPendingActions() async {
    final pendingActions = await _dbHelper.getPendingActions();
    return pendingActions.isNotEmpty;
  }
}
