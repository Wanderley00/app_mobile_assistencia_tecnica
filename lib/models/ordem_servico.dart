// lib/models/ordem_servico.dart

import 'cliente.dart';
import 'equipamento.dart';
import 'relatorio_campo.dart';
import 'despesa.dart';
import 'membro_equipe.dart';
import 'documento_os.dart';
import 'registro_ponto.dart';
import 'historico_aprovacao.dart';

class OrdemServico {
  final int id;
  final String numeroOs;
  final String tituloServico;
  final String descricaoProblema;
  final Cliente cliente;
  final Equipamento equipamento;
  final String status;
  final DateTime dataAbertura;
  final String tecnicoResponsavel;
  final String gestorResponsavel;
  final String? tipoManutencao;
  final String? observacoesGerais;
  final DateTime? dataInicioPlanejado;
  final DateTime? dataInicioReal;
  final DateTime? dataConclusaoPrevista;
  final DateTime? dataFechamento;
  final List<RelatorioCampo> relatorios;
  final List<Despesa> despesas;
  final List<MembroEquipe> equipe;
  final List<DocumentoOS> documentos;
  final List<RegistroPonto> pontos;
  final List<HistoricoAprovacao> historicoAprovacoes;
  final bool hasPendingActions;

  OrdemServico({
    required this.id,
    required this.numeroOs,
    required this.tituloServico,
    required this.descricaoProblema,
    required this.cliente,
    required this.equipamento,
    required this.status,
    required this.dataAbertura,
    required this.tecnicoResponsavel,
    required this.gestorResponsavel,
    this.tipoManutencao,
    this.observacoesGerais,
    this.dataInicioPlanejado,
    this.dataInicioReal,
    this.dataConclusaoPrevista,
    this.dataFechamento,
    this.relatorios = const [],
    this.despesas = const [],
    this.equipe = const [],
    this.documentos = const [],
    this.pontos = const [],
    this.historicoAprovacoes = const [],
    this.hasPendingActions = false,
  });

  OrdemServico copyWith({
    List<RegistroPonto>? pontos,
    List<RelatorioCampo>? relatorios,
    List<Despesa>? despesas,
    List<MembroEquipe>? equipe,
    List<DocumentoOS>? documentos,
    bool? hasPendingActions,
    List<HistoricoAprovacao>? historicoAprovacoes,
    // Adicione outros campos se quiser permitir cópia customizada
  }) {
    return OrdemServico(
      id: id,
      numeroOs: numeroOs,
      tituloServico: tituloServico,
      descricaoProblema: descricaoProblema,
      cliente: cliente,
      equipamento: equipamento,
      status: status,
      dataAbertura: dataAbertura,
      tecnicoResponsavel: tecnicoResponsavel,
      gestorResponsavel: gestorResponsavel,
      tipoManutencao: tipoManutencao,
      observacoesGerais: observacoesGerais,
      dataInicioPlanejado: dataInicioPlanejado,
      dataInicioReal: dataInicioReal,
      dataConclusaoPrevista: dataConclusaoPrevista,
      dataFechamento: dataFechamento,
      relatorios: relatorios ?? this.relatorios,
      despesas: despesas ?? this.despesas,
      equipe: equipe ?? this.equipe,
      documentos: documentos ?? this.documentos,
      pontos: pontos ?? this.pontos,
      historicoAprovacoes: historicoAprovacoes ?? this.historicoAprovacoes,
      hasPendingActions: hasPendingActions ?? this.hasPendingActions,
    );
  }

  factory OrdemServico.fromJson(Map<String, dynamic> json) {
    return OrdemServico(
      id: json['id'],
      numeroOs: json['numero_os'] ?? 'N/A',
      tituloServico: json['titulo_servico'] ?? 'N/A',
      descricaoProblema: json['descricao_problema'] ?? 'N/A',
      cliente: Cliente.fromJson(json['cliente'] ?? {}),
      equipamento: Equipamento.fromJson(json['equipamento'] ?? {}),
      status: json['status'] ?? 'DESCONHECIDO',
      dataAbertura: DateTime.parse(json['data_abertura']),
      tecnicoResponsavel: json['tecnico_responsavel'] ?? 'N/A',
      gestorResponsavel: json['gestor_responsavel'] ?? 'N/A',
      tipoManutencao: json['tipo_manutencao'] as String?,
      observacoesGerais: json['observacoes_gerais'],
      dataInicioPlanejado: json['data_inicio_planejado'] != null
          ? DateTime.parse(json['data_inicio_planejado'])
          : null,
      dataInicioReal: json['data_inicio_real'] != null
          ? DateTime.parse(json['data_inicio_real'])
          : null,
      dataConclusaoPrevista: json['data_previsao_conclusao'] != null
          ? DateTime.parse(json['data_previsao_conclusao'])
          : null,
      dataFechamento: json['data_fechamento'] != null
          ? DateTime.parse(json['data_fechamento'])
          : null,
      relatorios: (json['relatorios_campo'] as List? ?? [])
          .map((r) => RelatorioCampo.fromJson(r))
          .toList(),
      despesas: (json['despesas'] as List? ?? [])
          .map((d) => Despesa.fromJson(d))
          .toList(),
      equipe: (json['equipe'] as List? ?? [])
          .map((e) => MembroEquipe.fromJson(e))
          .toList(),
      documentos: (json['documentos'] as List? ?? [])
          .map((doc) => DocumentoOS.fromJson(doc))
          .toList(),
      pontos: (json['pontos'] as List? ?? [])
          .map((p) => RegistroPonto.fromJson(p))
          .toList(),
      historicoAprovacoes: (json['historico_aprovacoes'] as List? ?? [])
          .map((h) => HistoricoAprovacao.fromJson(h))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero_os': numeroOs,
      'titulo_servico': tituloServico,
      'descricao_problema': descricaoProblema,
      'cliente': cliente.toJson(),
      'equipamento': equipamento.toJson(),
      'status': status,
      'data_abertura': dataAbertura.toIso8601String(),
      'tecnico_responsavel': tecnicoResponsavel,
      'gestor_responsavel': gestorResponsavel,
      'tipo_manutencao': tipoManutencao,
      'observacoes_gerais': observacoesGerais,
      'data_inicio_planejado': dataInicioPlanejado?.toIso8601String(),
      'data_inicio_real': dataInicioReal?.toIso8601String(),
      'data_previsao_conclusao': dataConclusaoPrevista?.toIso8601String(),
      'data_fechamento': dataFechamento?.toIso8601String(),
      // Agora esta linha funcionará
      'relatorios_campo': relatorios.map((r) => r.toJson()).toList(),
      'despesas': despesas.map((d) => d.toJson()).toList(),
      'equipe': equipe.map((e) => e.toJson()).toList(),
      'documentos': documentos.map((doc) => doc.toJson()).toList(),
      'pontos': pontos.map((p) => p.toJson()).toList(),
      'historico_aprovacoes':
          historicoAprovacoes.map((h) => h.toJson()).toList(),
    };
  }
}
