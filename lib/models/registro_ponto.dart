// lib/models/registro_ponto.dart

import 'package:intl/intl.dart';

class RegistroPonto {
  final int id;
  final String tecnico;
  final DateTime data;
  final String horaEntrada;
  final String? horaSaida;
  final String? duracaoFormatada;
  final String? observacoes;
  final String? observacoesEntrada; // Campo para a observação de entrada

  final bool isPending;

  RegistroPonto({
    required this.id,
    required this.tecnico,
    required this.data,
    required this.horaEntrada,
    this.horaSaida,
    this.duracaoFormatada,
    this.observacoes,
    this.observacoesEntrada, // Adicionado ao construtor
    this.isPending = false,
  });

  factory RegistroPonto.fromJson(Map<String, dynamic> json) {
    String? formatTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
      return timeStr;
    }

    return RegistroPonto(
      id: json['id'],
      tecnico: json['tecnico'] ?? 'N/A',
      data: DateTime.parse(json['data']),
      horaEntrada: formatTime(json['hora_entrada']) ?? 'N/A',
      horaSaida: formatTime(json['hora_saida']),
      duracaoFormatada: json['duracao_formatada'],
      observacoes: json['observacoes'],
      observacoesEntrada: json['observacoes_entrada'], // Lendo do JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tecnico': tecnico,
      'data': data.toIso8601String(),
      'hora_entrada': horaEntrada,
      'hora_saida': horaSaida,
      'duracao_formatada': duracaoFormatada,
      'observacoes': observacoes,
      'observacoes_entrada': observacoesEntrada, // Adicionado ao JSON
    };
  }

  RegistroPonto copyWith({
    int? id,
    String? tecnico,
    DateTime? data,
    String? horaEntrada,
    String? horaSaida,
    String? observacoes,
    String? observacoesEntrada, // Adicionado ao copyWith
    bool? isPending,
    String? duracaoFormatada,
  }) {
    return RegistroPonto(
      id: id ?? this.id,
      tecnico: tecnico ?? this.tecnico,
      data: data ?? this.data,
      horaEntrada: horaEntrada ?? this.horaEntrada,
      horaSaida: horaSaida ?? this.horaSaida,
      observacoes: observacoes ?? this.observacoes,
      observacoesEntrada: observacoesEntrada ?? this.observacoesEntrada,
      isPending: isPending ?? this.isPending,
      duracaoFormatada: duracaoFormatada ?? this.duracaoFormatada,
    );
  }
}
