import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shift_provider.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseRepository _repo = ExpenseRepository();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _newCatController = TextEditingController();

  List<ExpenseCategoryModel> _categories = [];
  String? _selectedCategoryId;
  String _paymentMethod = 'TUNAI';
  DateTime _date = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _repo.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (cats.isNotEmpty) _selectedCategoryId = cats.first.id;
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewCategory() async {
    final name = _newCatController.text.trim();
    if (name.isNotEmpty) {
      await _repo.addCategory(name);
      _newCatController.clear();
      Navigator.of(context).pop();
      await _loadCategories();
      setState(() {
        _selectedCategoryId = _categories.firstWhere((c) => c.name == name, orElse: () => _categories.first).id;
      });
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kategori Pengeluaran'),
        content: TextField(
          controller: _newCatController,
          decoration: const InputDecoration(hintText: 'Contoh: Promosi Brosur, Gas Elpiji'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(onPressed: _addNewCategory, child: const Text('Tambah')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    setState(() => _isSaving = true);
    final user = ref.read(authProvider).currentUser;
    final shift = ref.read(shiftProvider).currentShift;

    final selectedCat = _categories.firstWhere((c) => c.id == _selectedCategoryId);
    final amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0.0;

    final exp = ExpenseModel(
      id: IdGenerator.generateId(prefix: 'exp'),
      shiftId: shift?.id,
      categoryId: selectedCat.id,
      categoryName: selectedCat.name,
      amount: amount,
      paymentMethod: _paymentMethod,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      date: _date.toIso8601String().substring(0, 10),
      createdBy: user?.name,
    );

    await _repo.saveExpense(
      expense: exp,
      currentShiftId: shift?.id,
      userId: user?.id,
      userName: user?.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran berhasil dicatat!'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Pengeluaran Toko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nominal
                    const Text('Nominal Pengeluaran (Rp)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(prefixText: 'Rp '),
                      validator: (val) => val == null || double.tryParse(val.replaceAll('.', '')) == null ? 'Masukkan nominal valid' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kategori Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Kategori Baru', style: TextStyle(fontSize: 12)),
                          onPressed: _showAddCategoryDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          items: _categories.map((c) {
                            return DropdownMenuItem(value: c.id, child: Text(c.name));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method & Date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sumber Dana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('Kas Tunai'),
                                    selected: _paymentMethod == 'TUNAI',
                                    selectedColor: AppColors.primaryContainer,
                                    onSelected: (_) => setState(() => _paymentMethod = 'TUNAI'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text('Non-Tunai'),
                                    selected: _paymentMethod == 'NON_TUNAI',
                                    selectedColor: AppColors.primaryContainer,
                                    onSelected: (_) => setState(() => _paymentMethod = 'NON_TUNAI'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (d != null) setState(() => _date = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Tanggal'),
                              child: Text(_date.toIso8601String().substring(0, 10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text('Keterangan Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Contoh: Beli token listrik kedai, galon air minum'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: const Text('Simpan Pengeluaran'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
