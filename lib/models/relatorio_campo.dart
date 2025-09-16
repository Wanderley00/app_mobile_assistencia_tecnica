// lib/models/relatorio_campo.dart

import 'problema_relatorio.dart';
import 'horas_relatorio_tecnico.dart';
import 'tipo_relatorio.dart';
import 'categoria_problema.dart';
import 'subcategoria_problema.dart';
import 'foto_relatorio.dart';

class RelatorioCampo {
  final int id;
  final TipoRelatorio tipoRelatorio;
  final DateTime dataRelatorio;
  final String tecnico;
  final String descricaoAtividades;
  final String? materialUtilizado;
  final String? observacoesAdicionais;
  final String? localServico;
  final List<ProblemaRelatorio> problemas;
  final List<HorasRelatorioTecnico> horas;
  final List<FotoRelatorio> fotos;
  final bool isPendingSync;

  RelatorioCampo copyWith({
    List<FotoRelatorio>? fotos,
  }) {
    return RelatorioCampo(
      id: id,
      tipoRelatorio: tipoRelatorio,
      dataRelatorio: dataRelatorio,
      tecnico: tecnico,
      descricaoAtividades: descricaoAtividades,
      materialUtilizado: materialUtilizado,
      observacoesAdicionais: observacoesAdicionais,
      localServico: localServico,
      problemas: problemas,
      horas: horas,
      fotos: fotos ?? this.fotos,
      isPendingSync: isPendingSync,
    );
  }

  RelatorioCampo({
    required this.id,
    required this.tipoRelatorio,
    required this.dataRelatorio,
    required this.tecnico,
    required this.descricaoAtividades,
    this.materialUtilizado,
    this.observacoesAdicionais,
    this.localServico,
    this.problemas = const [],
    this.horas = const [],
    this.fotos = const [],
    this.isPendingSync = false,
  });

  factory RelatorioCampo.fromJson(Map<String, dynamic> json) {
    return RelatorioCampo(
      id: json['id'],
      tipoRelatorio: TipoRelatorio.fromJson(json['tipo_relatorio'] ?? {}),
      dataRelatorio: DateTime.parse(json['data_relatorio']),
      tecnico: json['tecnico'] ?? 'N/A',
      descricaoAtividades: json['descricao_atividades'] ?? 'N/A',
      materialUtilizado: json['material_utilizado'],
      observacoesAdicionais: json['observacoes_adicionais'],
      localServico: json['local_servico'],
      // --- CORREÇÃO APLICADA AQUI ---
      // Removemos a gambiarra e agora processamos os dados reais da API
      problemas: (json['problemas'] as List? ?? [])
          .map((p) => ProblemaRelatorio.fromJson(p))
          .toList(),
      horas: (json['horas'] as List? ?? [])
          .map((h) => HorasRelatorioTecnico.fromJson(h))
          .toList(),
      fotos: (json['fotos'] as List? ?? [])
          .map((f) => FotoRelatorio.fromJson(f))
          .toList(),

      // --- 2. LÊ O VALOR DO CACHE ---
      // Se o valor não existir no cache (para dados antigos), assume 'false'.
      isPendingSync: json['is_pending_sync'] ?? false,
    );
  }

  /// Cria uma instância temporária de RelatorioCampo a partir do payload do formulário.
  /// Usado para exibição imediata no modo offline.
  factory RelatorioCampo.fromPayload(
    Map<String, dynamic> payload,
    List<TipoRelatorio> tiposDisponiveis,
    List<CategoriaProblema> categoriasDisponiveis, // Novo parâmetro
  ) {
    final tipoRelatorio = tiposDisponiveis.firstWhere(
      (t) => t.id == payload['tipo_relatorio'],
      orElse: () => TipoRelatorio(id: 0, nome: 'Desconhecido'),
    );

    return RelatorioCampo(
      id: 0,
      tipoRelatorio: tipoRelatorio,
      dataRelatorio: DateTime.parse(payload['data_relatorio']),
      tecnico: 'Você (Offline)',
      descricaoAtividades: payload['descricao_atividades'],
      materialUtilizado: payload['material_utilizado'],
      observacoesAdicionais: payload['observacoes_adicionais'],
      localServico: payload['local_servico'],

      // --- INÍCIO DA CORREÇÃO ---
      // Mapeia a lista de problemas do payload, traduzindo os IDs para nomes
      problemas: (payload['problemas'] as List? ?? []).map((p) {
        final int categoriaId = p['categoria'];
        final int? subcategoriaId = p['subcategoria'];

        // Encontra o objeto CategoriaProblema correspondente ao ID
        final categoria = categoriasDisponiveis.firstWhere(
          (c) => c.id == categoriaId,
          orElse: () =>
              CategoriaProblema(id: 0, nome: 'Desconhecida', subcategorias: []),
        );

        // Encontra o objeto SubcategoriaProblema correspondente ao ID
        SubcategoriaProblema? subcategoria;
        if (subcategoriaId != null) {
          subcategoria = categoria.subcategorias.firstWhere(
            (s) => s.id == subcategoriaId,
            orElse: () => SubcategoriaProblema(id: 0, nome: 'Desconhecida'),
          );
        }

        // Cria o objeto ProblemaRelatorio com os NOMES, como esperado
        return ProblemaRelatorio(
          categoria: categoria.nome,
          subcategoria: subcategoria?.nome,
          observacao: p['observacao'],
          solucaoAplicada: p['solucao_aplicada'],
        );
      }).toList(),
      // --- FIM DA CORREÇÃO ---

      horas: (payload['horas'] as List? ?? [])
          .map((h) => HorasRelatorioTecnico.fromJson(h))
          .toList(),

      // --- 3. MARCA COMO PENDENTE ---
      // Ao criar um relatório offline, definimos esta flag como 'true'
      isPendingSync: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo_relatorio': tipoRelatorio.toJson(),
      'data_relatorio': dataRelatorio.toIso8601String(),
      'tecnico': tecnico,
      'descricao_atividades': descricaoAtividades,
      'material_utilizado': materialUtilizado,
      'observacoes_adicionais': observacoesAdicionais,
      'local_servico': localServico,
      'problemas': problemas.map((p) => p.toJson()).toList(),
      // Agora esta linha funcionará
      'horas': horas.map((h) => h.toJson()).toList(),
      'fotos': fotos.map((f) => f.toJson()).toList(),
      'is_pending_sync': isPendingSync,
    };
  }
}
