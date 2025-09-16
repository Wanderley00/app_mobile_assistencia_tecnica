// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get osListTitle => 'Ordens de Serviço';

  @override
  String get confirmLogoutTitle => 'Confirmar Saída';

  @override
  String get confirmLogoutMessage => 'Você tem certeza que deseja sair?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get exit => 'Sair';
}
