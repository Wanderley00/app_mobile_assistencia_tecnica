// sync_service.dart

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'database_helper.dart';
import 'main.dart'; // Para a constante API_BASE_URL
import 'api_client.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  // --- MÉTODO NOVO QUE PRECISA SER ADICIONADO ---
  // Este método chama a função que você criou no DatabaseHelper.
  Future<List<int>> getDistinctOsIdsFromPendingActions() async {
    return await _dbHelper.getDistinctOsIdsFromPendingActions();
  }
  // --- FIM DO MÉTODO NOVO ---

  Future<void> processSyncQueue() async {
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

    print(
      "Itens pendentes na fila: ${pendingActions.length}. Iniciando sincronização...",
    );

    final Map<int, List<Map<String, dynamic>>> actionsByOs = {};
    for (var action in pendingActions) {
      final osId = action['os_id'] as int;
      actionsByOs.putIfAbsent(osId, () => []).add(action);
    }

    for (final osId in actionsByOs.keys) {
      final osActions = actionsByOs[osId]!;
      // bool allActionsSuccessful = true; // Não é mais necessário

      for (var action in osActions) {
        try {
          final success = await _syncAction(action);
          if (success) {
            await _dbHelper.deletePendingAction(action['id']);
            print(
              "Ação ${action['id']} (${action['action']}) da OS $osId sincronizada e removida.",
            );
          } else {
            // allActionsSuccessful = false; // Não é mais necessário
            print(
              "Falha ao sincronizar a ação ${action['id']}. Permanecerá na fila.",
            );
          }
        } catch (e) {
          // allActionsSuccessful = false; // Não é mais necessário
          print("Erro ao processar a ação ${action['id']}: $e");
        }
      }

      // O BLOCO if (allActionsSuccessful) FOI REMOVIDO DAQUI.
    }
    print("Processamento da fila de sincronização concluído.");
  }

  Future<bool> _syncAction(Map<String, dynamic> action) async {
    final payload = jsonDecode(action['payload']);
    final osId = action['os_id'];
    final actionType = action['action'];

    try {
      http.Response response;

      switch (actionType) {
        case 'create_report':
          response = await _apiClient.post(
            '/ordens-servico/$osId/relatorios/',
            payload,
          );
          break;

        case 'edit_report':
          // 1. Pega o ID do relatório que foi salvo no payload
          final relatorioId = payload.remove('relatorio_id');

          // 2. Faz uma requisição PUT para o endpoint de detalhe do relatório
          //    O corpo da requisição é o resto do payload, que contém os dados atualizados.
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
              '/ordens-servico/$osId/despesas/',
              payload,
            );
          }
          break;

        case 'add_document':
          final filePath = payload.remove('arquivo_caminho');
          response = await _apiClient.postMultipart(
            '/ordens-servico/$osId/documentos/',
            payload,
            filePath: filePath,
            fileField: 'arquivo',
          );
          break;

        case 'register_ponto_entrada':
          response = await _apiClient.post(
            '/ordens-servico/$osId/pontos/',
            payload,
          );
          break;

        case 'register_ponto_saida':
          final pontoId = payload['ponto_id'];
          payload.remove('ponto_id');
          response = await _apiClient.put('/pontos/$pontoId/', payload);
          break;

        case 'edit_expense':
          // 1. Pega o ID da despesa que foi salva no payload
          final despesaId = payload.remove('despesa_id');

          if (payload.containsKey('comprovante_caminho') &&
              payload['comprovante_caminho'] != null) {
            // Se houver, remove o caminho do payload e usa o patchMultipart
            final filePath = payload.remove('comprovante_caminho');
            response = await _apiClient.patchMultipart(
              '/despesas/$despesaId/',
              payload,
              filePath: filePath,
              fileField: 'comprovante_anexo',
            );
          } else {
            // Se não houver, usa o PUT normal
            response = await _apiClient.put('/despesas/$despesaId/', payload);
          }
          // --- FIM DA CORREÇÃO ---
          break;

        case 'delete_expense':
          final despesaId = payload['despesa_id'];
          response = await _apiClient.delete('/despesas/$despesaId/');
          // O status 204 (No Content) é o sucesso para delete
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

  /// Verifica se existem ações pendentes na fila de sincronização.
  /// Retorna `true` se a fila não estiver vazia.
  Future<bool> hasPendingActions() async {
    final pendingActions = await _dbHelper.getPendingActions();
    return pendingActions.isNotEmpty;
  }
}
