// lib/os_repository.dart (VERSÃO CORRIGIDA E FINAL)

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_helper.dart';
import 'main.dart';
import 'api_client.dart';
import 'models/ordem_servico.dart';
import 'models/registro_ponto.dart';
import 'models/tipo_documento.dart';
import 'models/categoria_despesa.dart';
import 'models/forma_pagamento.dart';
import 'models/documento_os.dart';
import 'models/despesa.dart';
import 'models/relatorio_campo.dart';
import 'package:collection/collection.dart';

import 'package:intl/intl.dart';
import 'models/tipo_relatorio.dart';
import 'models/categoria_problema.dart';
import 'models/horas_relatorio_tecnico.dart';
import 'models/foto_relatorio.dart';

class DadosCalculadosRelatorio {
  final List<HorasRelatorioTecnico> horasCalculadas;

  DadosCalculadosRelatorio({
    required this.horasCalculadas,
  });
}

class OsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  // --- MUDANÇA 1: Novo método privado para buscar pontos da API sem salvar no cache ---
  /// Apenas busca os pontos da API e os retorna, sem qualquer outra lógica.
  Future<List<RegistroPonto>> _fetchPontosFromApi(int osId) async {
    try {
      final response = await _apiClient.get('/ordens-servico/$osId/pontos/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((p) => RegistroPonto.fromJson(p)).toList();
      }
    } catch (e) {
      print("Falha ao buscar pontos da API para a OS $osId: $e");
    }
    return []; // Retorna uma lista vazia em caso de erro.
  }
  // --- FIM DA MUDANÇA 1 ---

  Future<void> cacheOsDetalhes(OrdemServico os) async {
    await _dbHelper.cacheOrdemServicoDetalhes(os);
  }

  // --- MUDANÇA 2: Lógica de `fetchAllAndCache` completamente reestruturada e corrigida ---
  Future<void> fetchAllAndCache() async {
    print("Iniciando sincronização completa e cache de todas as ordens...");

    final ordensResumidas = await _fetchFromApi();
    final List<OrdemServico> ordensCompletasParaCache = [];

    for (var osResumo in ordensResumidas) {
      try {
        OrdemServico osDetalhada = await _fetchOsDetailsFromApi(osResumo.id);

        final pontos = await _fetchPontosFromApi(osDetalhada.id);
        osDetalhada = osDetalhada.copyWith(pontos: pontos);

        // --- LÓGICA DE FOTOS DO RELATÓRIO (CORRIGIDA) ---
        List<RelatorioCampo> relatoriosAtualizados = [];
        for (var relatorio in osDetalhada.relatorios) {
          List<FotoRelatorio> fotosAtualizadas = [];
          for (var foto in relatorio.fotos) {
            FotoRelatorio fotoAtualizada = foto;
            if (foto.imagemUrl != null && foto.imagemUrl!.isNotEmpty) {
              try {
                final dir = await getApplicationDocumentsDirectory();
                final fileName =
                    "foto_${foto.id}_${p.basename(foto.imagemUrl!)}";
                final filePath = p.join(dir.path, fileName);
                final file = File(filePath);

                // 1. Verifica se o ficheiro não existe para o descarregar.
                if (!await file.exists()) {
                  final response = await http.get(Uri.parse(foto.imagemUrl!));
                  if (response.statusCode == 200) {
                    await file.writeAsBytes(response.bodyBytes);
                    print(
                        'Foto do relatório ${relatorio.id} descarregada para cache: $filePath');
                  }
                }
                // 2. A CORREÇÃO CRÍTICA: Independentemente de ter descarregado ou não,
                //    atualiza o objeto com o caminho local.
                fotoAtualizada = foto.copyWith(localFilePath: filePath);
              } catch (e) {
                print('Erro ao descarregar a foto ${foto.id}: $e');
              }
            }
            fotosAtualizadas.add(fotoAtualizada);
          }
          relatoriosAtualizados
              .add(relatorio.copyWith(fotos: fotosAtualizadas));
        }
        osDetalhada = osDetalhada.copyWith(relatorios: relatoriosAtualizados);

        // --- LÓGICA DE DOCUMENTOS DA OS (TAMBÉM CORRIGIDA) ---
        List<DocumentoOS> documentosAtualizados = [];
        for (var doc in osDetalhada.documentos) {
          DocumentoOS docAtualizado = doc;
          if (doc.arquivoUrl != null && doc.arquivoUrl!.isNotEmpty) {
            try {
              final dir = await getApplicationDocumentsDirectory();
              final fileName = "doc_${doc.id}_${p.basename(doc.arquivoUrl!)}";
              final filePath = p.join(dir.path, fileName);
              final file = File(filePath);

              if (!await file.exists()) {
                final response = await http.get(Uri.parse(doc.arquivoUrl!));
                if (response.statusCode == 200) {
                  await file.writeAsBytes(response.bodyBytes);
                  print(
                      'Documento ${doc.id} descarregado para cache: $filePath');
                }
              }
              docAtualizado = doc.copyWith(localFilePath: filePath);
            } catch (e) {
              print('Erro ao descarregar o documento ${doc.id}: $e');
            }
          }
          documentosAtualizados.add(docAtualizado);
        }
        osDetalhada = osDetalhada.copyWith(documentos: documentosAtualizados);

        ordensCompletasParaCache.add(osDetalhada);
      } catch (e) {
        print("Falha ao buscar detalhes da OS ${osResumo.id} para cache: $e");
      }
    }

    await _dbHelper.cacheOrdensServico(ordensCompletasParaCache);

    // --- INÍCIO DA CORREÇÃO DEFINITIVA ---
    // Passo 7: Pré-carrega o cache dos dados do formulário de relatório (horas e tipos).
    print(
        "Iniciando pré-carregamento do cache para formulários de relatório...");
    final hoje = DateTime.now();
    for (final os in ordensCompletasParaCache) {
      // Pré-carrega os dados de hoje e dos últimos 7 dias para cada OS.
      // O ciclo vai de 0 a 7, totalizando 8 dias (hoje + 7 dias passados).
      for (int i = 0; i < 8; i++) {
        // A MUDANÇA ESTÁ AQUI: Usamos .subtract() para olhar para o passado em vez de .add()
        final dataParaCache = hoje.subtract(Duration(days: i));
        try {
          // Chama a função que busca da API e salva no SharedPreferences.
          // Como estamos online, isto irá preencher o cache.
          await getDadosCalculadosRelatorio(os.id, dataParaCache);
          print(
              "Cache do formulário para OS ${os.id} na data ${DateFormat('yyyy-MM-dd').format(dataParaCache)} preenchido.");
        } catch (e) {
          print(
              "Falha ao pré-carregar cache para OS ${os.id} na data ${DateFormat('yyyy-MM-dd').format(dataParaCache)}: $e");
        }
      }
    }
    print("Pré-carregamento do cache de formulários concluído.");
    // --- FIM DA CORREÇÃO DEFINITIVA ---

    // Passo 8: Cachear os outros dados de apoio (inalterado).
    try {
      await getTiposRelatorio();
      await getCategoriasProblema();
      print("Categorias de problema cacheadas.");
      await getCategoriasDespesa();
      print("Categorias de despesa cacheadas.");
      await getFormasPagamento();
      print("Formas de pagamento cacheadas.");
      await getTiposDocumento();
      print("Tipos de documento cacheados.");
      await getMyExpenses();
      print("Despesas do usuário cacheadas.");
    } catch (e) {
      print("Falha ao cachear dados de dropdown: $e");
    }

    print("Sincronização completa do cache concluída.");
  }
  // --- FIM DA MUDANÇA 2 ---

  Future<OrdemServico> _fetchOsDetailsFromApi(int osId) async {
    final response = await _apiClient.get('/ordens-servico/$osId/');
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    print("--- Dados da API para a OS $osId ---");
    print(data);
    print("---------------------------------------");

    return OrdemServico.fromJson(data);
  }

  Future<List<OrdemServico>> getOrdensServicoFromCache() async {
    return _dbHelper.getOrdensServicoFromCache();
  }

  Future<List<OrdemServico>> _fetchFromApi() async {
    final response = await _apiClient.get('/ordens-servico/');
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => OrdemServico.fromJson(json)).toList();
  }

  Future<OrdemServico> getOsDetalhes(int osId) async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      try {
        var os = await _fetchOsDetailsFromApi(osId);

        final pontosAtualizados = await getPontos(osId);
        os = os.copyWith(pontos: pontosAtualizados);

        List<DocumentoOS> documentosAtualizados = [];
        for (var doc in os.documentos) {
          DocumentoOS docAtualizado = doc;
          if (doc.arquivoUrl != null && doc.arquivoUrl!.isNotEmpty) {
            final dir = await getApplicationDocumentsDirectory();
            final fileName = "${doc.id}_${p.basename(doc.arquivoUrl!)}";
            final filePath = '${dir.path}/$fileName';
            final file = File(filePath);

            if (!await file.exists()) {
              try {
                final response = await http.get(Uri.parse(doc.arquivoUrl!));
                if (response.statusCode == 200) {
                  await file.writeAsBytes(response.bodyBytes);
                  print('Documento ${doc.id} baixado para cache: $filePath');
                }
              } catch (e) {
                print('Erro ao baixar o documento ${doc.id} para o cache: $e');
              }
            }
            docAtualizado = doc.copyWith(localFilePath: filePath);
          }
          documentosAtualizados.add(docAtualizado);
        }
        os = os.copyWith(documentos: documentosAtualizados);

        await _dbHelper.cacheOrdemServicoDetalhes(os);
        return os;
      } catch (e) {
        print(
            "Erro ao buscar detalhes completos da API, tentando cache. Erro: $e");
        return await _dbHelper.getOrdemServicoById(osId) ??
            (throw Exception(
                'Falha ao carregar OS da API e sem cache disponível.'));
      }
    } else {
      return await _dbHelper.getOrdemServicoById(osId) ??
          (throw Exception('App offline e sem detalhes da OS em cache.'));
    }
  }

  Future<List<RegistroPonto>> getPontos(int osId) async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      try {
        // Usa o novo método privado para buscar da API
        final pontosDaApi = await _fetchPontosFromApi(osId);
        // Salva no cache
        await _dbHelper.cachePontos(pontosDaApi, osId);
        return pontosDaApi;
      } catch (e) {
        print("Falha ao buscar pontos da API, tentando cache do DB. Erro: $e");
      }
    }
    // Se estiver offline ou a API falhar, busca do cache
    return _dbHelper.getPontosFromCache(osId);
  }

  Future<List<TipoDocumento>> getTiposDocumento() async {
    return _apiClient.getGenericList(
      endpoint: '/tipos-documento/',
      fromJson: (json) => TipoDocumento.fromJson(json),
      cacheKey: 'tipos_documento',
    );
  }

  Future<List<CategoriaDespesa>> getCategoriasDespesa() async {
    return _apiClient.getGenericList(
      endpoint: '/categorias-despesa/',
      fromJson: (json) => CategoriaDespesa.fromJson(json),
      cacheKey: 'categorias_despesa',
    );
  }

  Future<List<FormaPagamento>> getFormasPagamento() async {
    return _apiClient.getGenericList(
      endpoint: '/formas-pagamento/',
      fromJson: (json) => FormaPagamento.fromJson(json),
      cacheKey: 'formas_pagamento',
    );
  }

  Future<List<OrdemServico>> getOrdensServico() async {
    // Este método parece não ser mais usado pelo provider, mas o mantemos por consistência.
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      try {
        final ordens = await _fetchFromApi();
        await _dbHelper.cacheOrdensServico(ordens);
        return ordens;
      } catch (e) {
        print("Falha ao buscar ordens da API. Tentando cache... Erro: $e");
        return await _dbHelper.getOrdensServicoFromCache();
      }
    } else {
      return await _dbHelper.getOrdensServicoFromCache();
    }
  }

  Future<List<TipoRelatorio>> getTiposRelatorio() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cached_tipos_relatorio';

    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        final response =
            await _apiClient.get('/tipos-relatorio/'); // Chama o novo endpoint
        if (response.statusCode == 200) {
          final jsonString = utf8.decode(response.bodyBytes);
          await prefs.setString(cacheKey, jsonString);
          final List<dynamic> data = jsonDecode(jsonString);
          return data.map((item) => TipoRelatorio.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print("Falha ao buscar Tipos de Relatório da API, a usar o cache: $e");
    }

    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final List<dynamic> data = jsonDecode(cachedData);
      return data.map((item) => TipoRelatorio.fromJson(item)).toList();
    }

    return [];
  }

  /// Busca e armazena no cache a lista de Categorias e Subcategorias de Problema.
  Future<List<CategoriaProblema>> getCategoriasProblema() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cached_categorias_problema';

    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        // Online: Busca da API e atualiza o cache
        final response = await _apiClient.get('/problemas/categorias/');
        if (response.statusCode == 200) {
          final jsonString = utf8.decode(response.bodyBytes);
          await prefs.setString(cacheKey, jsonString);
          final List<dynamic> data = jsonDecode(jsonString);
          return data.map((item) => CategoriaProblema.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print(
          "Falha ao buscar Categorias de Problema da API, a usar o cache: $e");
    }

    // Offline ou falha na API: Tenta ler do cache
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final List<dynamic> data = jsonDecode(cachedData);
      return data.map((item) => CategoriaProblema.fromJson(item)).toList();
    }

    return []; // Retorna vazio se estiver offline e sem cache
  }

  /// Busca e armazena no cache os dados de horas calculadas para uma data específica.
  Future<DadosCalculadosRelatorio> getDadosCalculadosRelatorio(
      int osId, DateTime data) async {
    final prefs = await SharedPreferences.getInstance();
    final formattedDate = DateFormat('yyyy-MM-dd').format(data);
    final cacheKey =
        'cached_form_data_${osId}_$formattedDate'; // A chave de cache continua a mesma

    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        // ONLINE: Busca da API e atualiza o cache
        final endpoint =
            '/ordens-servico/$osId/calcular-horas-relatorio/?data=$formattedDate';
        final response = await _apiClient.get(endpoint);

        if (response.statusCode == 200) {
          final jsonString = utf8.decode(response.bodyBytes);
          await prefs.setString(
              cacheKey, jsonString); // Salva o JSON completo no cache

          final data = jsonDecode(jsonString);

          // A API ainda envia 'tipos_relatorio', mas aqui só nos interessam as horas.
          final horas = (data['horas_calculadas'] as List)
              .map((item) => HorasRelatorioTecnico.fromJson(item))
              .toList();

          // Retorna o objeto correto, que só precisa das horas
          return DadosCalculadosRelatorio(horasCalculadas: horas);
        }
      }
    } catch (e) {
      print("Falha ao buscar dados do formulário da API, a usar o cache: $e");
    }

    // OFFLINE ou FALHA NA API: Tenta ler do cache
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final data = jsonDecode(cachedData);

      // Mesmo no cache, só precisamos de extrair as horas para esta função
      final horas = (data['horas_calculadas'] as List)
          .map((item) => HorasRelatorioTecnico.fromJson(item))
          .toList();

      return DadosCalculadosRelatorio(horasCalculadas: horas);
    }

    // Se estiver offline e sem cache, retorna uma estrutura vazia
    return DadosCalculadosRelatorio(horasCalculadas: []);
  }

  Future<void> addPhotoToReportOnline({
    required int relatorioId,
    required String description,
    required File imageFile,
  }) async {
    final response = await _apiClient.postMultipart(
      '/relatorios-campo/$relatorioId/fotos/', // Endpoint da sua API para adicionar fotos
      {'descricao': description},
      filePath: imageFile.path,
      fileField: 'imagem', // Nome do campo do ficheiro na sua API
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao salvar foto: ${response.body}');
    }
  }

  Future<RelatorioCampo> getRelatorioDetalhes(int relatorioId) async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    final isOnline = connectivityResult != ConnectivityResult.none;

    // --- TENTATIVA ONLINE ---
    // Se estiver online, tenta sempre buscar os dados mais recentes da API.
    if (isOnline) {
      try {
        final response =
            await _apiClient.get('/relatorios-campo/$relatorioId/');
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          print("Detalhes do relatório $relatorioId obtidos da API.");
          return RelatorioCampo.fromJson(data);
        }
      } catch (e) {
        print(
            "Falha ao buscar detalhes do relatório da API, a tentar o cache. Erro: $e");
        // Se a API falhar (ex: servidor em baixo), continua para a lógica offline.
      }
    }

    // --- LÓGICA OFFLINE (OU DE FALLBACK) ---
    // Se estiver offline ou se a tentativa online falhou, procura no cache.
    print("A procurar detalhes do relatório $relatorioId no cache local...");

    // 1. Pega todas as Ordens de Serviço que estão guardadas no cache do SQLite.
    final cachedOsList = await _dbHelper.getOrdensServicoFromCache();

    // 2. Procura em todas as OSs pelo relatório com o ID correspondente.
    for (final os in cachedOsList) {
      // O 'firstWhereOrNull' é uma forma segura de procurar na lista de relatórios.
      final relatorioEncontrado = os.relatorios
          .firstWhereOrNull((relatorio) => relatorio.id == relatorioId);

      if (relatorioEncontrado != null) {
        print(
            "Relatório com ID $relatorioId encontrado no cache da OS ${os.id}.");
        return relatorioEncontrado;
      }
    }

    // 3. Se não encontrou em nenhum lugar, lança um erro informativo.
    throw Exception(
        'Este relatório não foi encontrado no cache. É necessária uma ligação à internet para o carregar pela primeira vez.');
  }

  /// Busca as despesas do usuário logado, utilizando cache para acesso offline.
  Future<List<Despesa>> getMyExpenses() async {
    // 1. Chave única para guardar a lista de despesas no cache.
    const String cacheKey = 'my_expenses_cache';

    // 2. Endpoint da API que retorna as despesas do usuário.
    const String endpoint = '/despesas/minhas-despesas/';

    // 3. O método getGenericList já contém toda a lógica necessária:
    //    - Tenta buscar da API se estiver online.
    //    - Se conseguir, salva a resposta no cache (SharedPreferences) com a chave fornecida.
    //    - Se estiver offline ou a API falhar, lê e retorna os dados do cache.
    return _apiClient.getGenericList<Despesa>(
      endpoint: endpoint,
      fromJson: (json) => Despesa.fromJson(json),
      cacheKey: cacheKey,
    );
  }
}
