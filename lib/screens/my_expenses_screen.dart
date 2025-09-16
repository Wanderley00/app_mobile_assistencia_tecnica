// lib/screens/my_expenses_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../main.dart';
import '../models/despesa.dart';
import 'expense_form_screen.dart';
import 'expense_detail_screen.dart';
import '../widgets/status_badge.dart';
import '../os_repository.dart';
import 'package:provider/provider.dart';
import '../providers/os_list_provider.dart';

class MyExpensesScreen extends StatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  final OsRepository _osRepository = OsRepository();

  // Listas para gerenciar os dados originais e os filtrados
  List<Despesa> _allDespesas = [];
  List<Despesa> _filteredDespesas = [];

  // Controlador para o campo de busca
  final TextEditingController _searchController = TextEditingController();

  // --- INÍCIO DA ALTERAÇÃO ---
  // Variáveis de estado para o filtro de data
  DateTime? _startDate;
  DateTime? _endDate;
  // --- FIM DA ALTERAÇÃO ---

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterExpenses);
    _fetchMyExpenses();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterExpenses);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyExpenses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // AQUI ESTÁ A MUDANÇA PRINCIPAL
      // Agora chamamos o nosso novo método centralizado no repositório.
      // Ele já cuida de tudo (online/offline/cache).
      final List<Despesa> fetchedDespesas = await _osRepository.getMyExpenses();

      if (mounted) {
        setState(() {
          _allDespesas = fetchedDespesas;
          // Aplica os filtros atuais aos novos dados (do cache ou da API)
          _filterExpenses();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // A mensagem de erro agora pode vir do repositório
          _errorMessage = 'Erro ao carregar despesas: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // --- MÉTODO DE FILTRAGEM ATUALIZADO ---
  void _filterExpenses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDespesas = _allDespesas.where((despesa) {
        // Lógica de busca por texto
        final descriptionMatch =
            despesa.descricao.toLowerCase().contains(query);
        final osNumberMatch =
            despesa.osNumero?.toLowerCase().contains(query) ?? false;
        final osTitleMatch =
            despesa.osTitulo?.toLowerCase().contains(query) ?? false;
        final textMatch = descriptionMatch || osNumberMatch || osTitleMatch;

        // Lógica de filtro por data
        final dateMatch = () {
          if (_startDate == null || _endDate == null) {
            return true; // Se não há filtro de data, todas as datas são válidas
          }
          // Normaliza as datas para ignorar a parte do tempo e fazer uma comparação inclusiva
          final despesaDate = DateUtils.dateOnly(despesa.dataDespesa);
          final startDate = DateUtils.dateOnly(_startDate!);
          final endDate = DateUtils.dateOnly(_endDate!);

          return (despesaDate.isAtSameMomentAs(startDate) ||
                  despesaDate.isAfter(startDate)) &&
              (despesaDate.isAtSameMomentAs(endDate) ||
                  despesaDate.isBefore(endDate));
        }();

        // Retorna verdadeiro apenas se ambas as condições (texto e data) forem atendidas
        return textMatch && dateMatch;
      }).toList();
    });
  }

  // --- NOVO MÉTODO PARA SELECIONAR O INTERVALO DE DATAS ---
  Future<void> _pickDateRange() async {
    final initialDateRange = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null;

    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });
      _filterExpenses(); // Re-aplica os filtros com a nova data
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. OBTENHA A INSTÂNCIA DO PROVIDER AQUI
    // Usamos context.watch para que a tela seja reconstruída
    // sempre que o status da conexão mudar.
    final osProvider = context.watch<OsListProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Despesas'),
        // 2. ADICIONE O WIDGET DE AÇÕES AQUI
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Tooltip(
              message: osProvider.isOnline ? 'Online' : 'Offline',
              child: Icon(
                osProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                color: osProvider.isOnline
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por OS, título ou descrição...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // --- NOVO WIDGET PARA O FILTRO DE DATA ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Filtrar por Data'),
                ),
                if (_startDate != null && _endDate != null)
                  Expanded(
                    child: Text(
                      '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                if (_startDate != null || _endDate != null)
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.error, size: 20),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _filterExpenses();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // --- FIM DO NOVO WIDGET ---

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMyExpenses,
              child: _buildBodyContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_filteredDespesas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchController.text.isEmpty && _startDate == null
                    ? Icons.receipt_long_outlined
                    : Icons.search_off_outlined,
                size: 80,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                _searchController.text.isEmpty && _startDate == null
                    ? 'Nenhuma Despesa Encontrada'
                    : 'Nenhum Resultado',
                style: AppTextStyles.headline2
                    .copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty && _startDate == null
                    ? 'Você ainda não registrou nenhuma despesa.'
                    : 'Nenhuma despesa corresponde aos filtros aplicados.',
                style: AppTextStyles.body2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDespesas.length,
      itemBuilder: (context, index) {
        final despesa = _filteredDespesas[index];
        return _buildDespesaCard(despesa);
      },
    );
  }

  Widget _buildDespesaCard(Despesa despesa) {
    // ... (Este método não precisa de alterações)
    final Color statusColor =
        despesa.isPending ? AppColors.warning : AppColors.primaryLight;
    IconData categoryIcon = Icons.receipt_long_outlined;
    if (despesa.categoria != null) {
      String categoriaNome = despesa.categoria!.nome.toLowerCase();
      if (categoriaNome.contains('aliment')) {
        categoryIcon = Icons.restaurant_outlined;
      } else if (categoriaNome.contains('transporte') ||
          categoriaNome.contains('combustível')) {
        categoryIcon = Icons.directions_car_outlined;
      } else if (categoriaNome.contains('hospedagem')) {
        categoryIcon = Icons.hotel_outlined;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Slidable(
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: (context) async {
                  final result =
                      await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ExpenseFormScreen(
                      ordemServicoId: despesa.ordemServicoId,
                      despesaParaEditar: despesa,
                    ),
                  ));
                  if (result == true && mounted) {
                    _fetchMyExpenses();
                  }
                },
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Editar',
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.1),
                child: Icon(categoryIcon, color: statusColor),
              ),
              title: Text(
                despesa.osTitulo ?? 'Ordem de Serviço',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    despesa.descricao,
                    style: AppTextStyles.subtitle1.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OS ${despesa.osNumero ?? "N/A"} - ${DateFormat('dd/MM/yyyy').format(despesa.dataDespesa)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${despesa.valor.toStringAsFixed(2)}',
                    style: AppTextStyles.subtitle1
                        .copyWith(color: AppColors.primary, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (despesa.statusAprovacao != null)
                        StatusBadge(status: despesa.statusAprovacao!),
                      // Adiciona um espaçamento se ambos os status estiverem presentes
                      if (despesa.statusAprovacao != null &&
                          despesa.statusPagamento != null)
                        const SizedBox(width: 4),
                      // Mostra o status de pagamento se ele existir
                      if (despesa.statusPagamento != null)
                        StatusBadge(status: despesa.statusPagamento!),
                    ],
                  )
                  // --- FIM DA ALTERAÇÃO ---
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ExpenseDetailScreen(despesa: despesa),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
