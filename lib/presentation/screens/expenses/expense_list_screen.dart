import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final ExpenseRepository _repo = ExpenseRepository();
  List<ExpenseModel> _expenses = [];
  List<ExpenseCategoryModel> _categories = [];
  String _selectedCatId = 'ALL';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await _repo.getCategories();
    final list = await _repo.getExpenses(
      categoryId: _selectedCatId == 'ALL' ? null : _selectedCatId,
    );
    if (mounted) {
      setState(() {
        _categories = cats;
        _expenses = list;
        _isLoading = false;
      });
    }
  }

  double get _totalExpenses => _expenses.fold(0.0, (s, e) => s + e.amount);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pengeluaran Toko',
      currentRoute: '/expenses',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Catat Pengeluaran', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
          );
          if (res == true) _loadData();
        },
      ),
      body: Column(
        children: [
          // Total Expense Banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pengeluaran Tercatat:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(
                      CurrencyFormatter.format(_totalExpenses),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Semua'),
                          selected: _selectedCatId == 'ALL',
                          selectedColor: AppColors.primaryContainer,
                          onSelected: (_) {
                            setState(() => _selectedCatId = 'ALL');
                            _loadData();
                          },
                        ),
                      ),
                      ..._categories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: _selectedCatId == c.id,
                              selectedColor: AppColors.primaryContainer,
                              onSelected: (_) {
                                setState(() => _selectedCatId = c.id);
                                _loadData();
                              },
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.money_off_outlined,
                        title: 'Belum Ada Pengeluaran',
                        message: 'Catat pengeluaran listrik, sewa, gaji, atau bahan untuk pembukuan yang rapi.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final exp = _expenses[index];

                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_wallet, color: AppColors.danger, size: 20),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(exp.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    CurrencyFormatter.format(exp.amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (exp.description != null && exp.description!.isNotEmpty)
                                    Text(exp.description!, style: const TextStyle(fontSize: 12)),
                                  Text(
                                    '${exp.date} • ${exp.paymentMethod} • Dicatat oleh: ${exp.createdBy ?? "-"}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
