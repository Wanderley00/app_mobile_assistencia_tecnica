// lib/models/horas_relatorio_tecnico.dart

class HorasRelatorioTecnico {
  final String tecnico;

  // --- MUDANÇA 1: CAMPOS SEPARADOS ---
  // Estes campos guardarão os valores decimais originais (ex: "8.50")
  final String horasNormaisDecimal;
  final String horasExtras60Decimal;
  final String horasExtras100Decimal;

  // Estes campos guardarão as strings formatadas (ex: "08:30") para exibição
  final String horasNormaisHHMM;
  final String horasExtras60HHMM;
  final String horasExtras100HHMM;

  final double kmRodado;

  HorasRelatorioTecnico({
    required this.tecnico,
    // Construtor atualizado
    required this.horasNormaisDecimal,
    required this.horasExtras60Decimal,
    required this.horasExtras100Decimal,
    required this.horasNormaisHHMM,
    required this.horasExtras60HHMM,
    required this.horasExtras100HHMM,
    required this.kmRodado,
  });

  // --- MUDANÇA 2: fromJson ATUALIZADO ---
  // Agora ele lê TODOS os campos de horas que a API envia
  factory HorasRelatorioTecnico.fromJson(Map<String, dynamic> json) {
    return HorasRelatorioTecnico(
      tecnico: json['tecnico'] ?? 'N/A',

      // Lê os valores decimais da API
      horasNormaisDecimal: json['horas_normais'].toString(),
      horasExtras60Decimal: json['horas_extras_60'].toString(),
      horasExtras100Decimal: json['horas_extras_100'].toString(),

      // Lê os valores formatados "HH:mm" da API
      horasNormaisHHMM: json['horas_normais_hhmm'] ?? '00:00',
      horasExtras60HHMM: json['horas_extras_60_hhmm'] ?? '00:00',
      horasExtras100HHMM: json['horas_extras_100_hhmm'] ?? '00:00',

      kmRodado: double.tryParse(json['km_rodado'].toString()) ?? 0.0,
    );
  }

  // --- MUDANÇA 3: MÉTODO toJson REMOVIDO ---
  // Removemos o método toJson pois a montagem do payload agora é feita
  // manualmente na tela do formulário, garantindo o envio dos dados corretos.
  Map<String, dynamic> toJson() {
    return {
      'tecnico': tecnico,
      // Salva ambos os tipos de valores no cache
      'horas_normais': horasNormaisDecimal,
      'horas_extras_60': horasExtras60Decimal,
      'horas_extras_100': horasExtras100Decimal,
      'horas_normais_hhmm': horasNormaisHHMM,
      'horas_extras_60_hhmm': horasExtras60HHMM,
      'horas_extras_100_hhmm': horasExtras100HHMM,
      'km_rodado': kmRodado,
    };
  }
}
