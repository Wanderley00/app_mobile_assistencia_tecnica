// lib/models/historico_aprovacao.dart

class HistoricoAprovacao {
  final int id;
  final String usuario;
  final String acao;
  final String comentario;
  final DateTime dataAcao;
  final String? tecnicoFinalizou;
  final DateTime? dataFinalizacaoTecnico;

  HistoricoAprovacao({
    required this.id,
    required this.usuario,
    required this.acao,
    required this.comentario,
    required this.dataAcao,
    this.tecnicoFinalizou,
    this.dataFinalizacaoTecnico,
  });

  factory HistoricoAprovacao.fromJson(Map<String, dynamic> json) {
    return HistoricoAprovacao(
      id: json['id'],
      usuario: json['usuario'] ?? 'N/A',
      acao: json['acao'] ?? 'DESCONHECIDA',
      comentario: json['comentario'] ?? '',
      dataAcao: DateTime.parse(json['data_acao']),
      tecnicoFinalizou: json['tecnico_finalizou'],
      dataFinalizacaoTecnico: json['data_finalizacao_tecnico'] != null
          ? DateTime.parse(json['data_finalizacao_tecnico'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario': usuario,
      'acao': acao,
      'comentario': comentario,
      'data_acao': dataAcao.toIso8601String(),
      'tecnico_finalizou': tecnicoFinalizou,
      'data_finalizacao_tecnico': dataFinalizacaoTecnico?.toIso8601String(),
    };
  }
}
