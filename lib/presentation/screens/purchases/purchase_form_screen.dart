import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/repositories/ingredient_repository.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shift_provider.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PurchaseRepository _purchaseRepo = PurchaseRepository();
  final IngredientRepository _ingRepo = IngredientRepository();

  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'TUNAI';
  DateTime _purchaseDate = DateTime.now();

  List<IngredientModel> _availableIngredients = [];
  final List<PurchaseItemModel> _purchaseItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final ings = await _ingRepo.getIngredients();
    if (mounted) {
      setState(() {
        _availableIngredients = ings;
        _isLoading = false;
      });
    }
  }

  double get _totalPurchaseAmount {
    return _purchaseItems.fold(0.0, (sum, i) => sum + i.totalPrice);
  }

  void _addItemToPurchase(IngredientModel ing) {
    setState(() {
      _purchaseItems.add(PurchaseItemModel(
        id: IdGenerator.generateId(prefix: 'pi'),
        purchaseId: '',
        ingredientId: ing.id,
        ingredientName: ing.name,
        quantity: 1000.0,
        unit: ing.unit,
        unitPrice: ing.costPerUnit,
        totalPrice: 1000.0 * ing.costPerUnit,
        batchNumber: 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        expiryDate: DateTime.now().add(const Duration(days: 90)).toIso8601String().substring(0, 10),
      ));
    });
  }

  void _showAddIngredientModal() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Bahan yang Dibeli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _availableIngredients.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final ing = _availableIngredients[index];
                  return ListTile(
                    title: Text(ing.name),
                    subtitle: Text('Stok Saat Ini: ${ing.currentStock.toStringAsFixed(1)} ${ing.unit}'),
                    trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _addItemToPurchase(ing);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePurchase() async {
    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 bahan yang dibeli')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = ref.read(authProvider).currentUser;
    final shift = ref.read(shiftProvider).currentShift;

    final pId = IdGenerator.generateId(prefix: 'po');
    final pNumber = IdGenerator.generatePurchaseNumber();

    final purchase = PurchaseModel(
      id: pId,
      purchaseNumber: pNumber,
      supplierName: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
      totalAmount: _totalPurchaseAmount,
      paymentMethod: _paymentMethod,
      purchaseDate: _purchaseDate.toIso8601String().substring(0, 10),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdBy: user?.name,
    );

    final itemsToSave = _purchaseItems.map((i) {
      return PurchaseItemModel(
        id: i.id,
        purchaseId: pId,
        ingredientId: i.ingredientId,
        ingredientName: i.ingredientName,
        quantity: i.quantity,
        unit: i.unit,
        unitPrice: i.unitPrice,
        totalPrice: i.totalPrice,
        batchNumber: i.batchNumber,
        expiryDate: i.expiryDate,
      );
    }).toList();

    await _purchaseRepo.savePurchase(
      purchase: purchase,
      items: itemsToSave,
      currentShiftId: shift?.id,
      userId: user?.id,
      userName: user?.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembelian bahan berhasil disimpan & stok diperbarui!'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Pembelian Bahan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _isSaving ? null : _savePurchase,
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
                    // Supplier & Date
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _supplierController,
                            decoration: const InputDecoration(labelText: 'Nama Supplier / Toko', hintText: 'Contoh: Toko Bahan Kue Jaya'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (d != null) setState(() => _purchaseDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Tanggal Beli'),
                              child: Text(_purchaseDate.toIso8601String().substring(0, 10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Payment Method Toggle
                    Row(
                      children: [
                        const Text('Metode Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Tunai (Kas)'),
                          selected: _paymentMethod == 'TUNAI',
                          selectedColor: AppColors.primaryContainer,
                          onSelected: (_) => setState(() => _paymentMethod = 'TUNAI'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Non-Tunai / Transfer'),
                          selected: _paymentMethod == 'NON_TUNAI',
                          selectedColor: AppColors.primaryContainer,
                          onSelected: (_) => setState(() => _paymentMethod = 'NON_TUNAI'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Catatan / No. Nota Pembelian (Opsional)'),
                    ),
                    const SizedBox(height: 20),

                    // Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bahan yang Dibeli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Pilih Bahan'),
                          onPressed: _showAddIngredientModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_purchaseItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Text('Belum ada bahan yang dipilih', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _purchaseItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _purchaseItems[index];

                          return Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item.ingredientName ?? 'Bahan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                        onPressed: () {
                                          setState(() => _purchaseItems.removeAt(index));
                                        },
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.quantity.toStringAsFixed(0),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(labelText: 'Jumlah (${item.unit})'),
                                          onChanged: (val) {
                                            final qty = double.tryParse(val) ?? item.quantity;
                                            setState(() {
                                              _purchaseItems[index] = PurchaseItemModel(
                                                id: item.id,
                                                purchaseId: item.purchaseId,
                                                ingredientId: item.ingredientId,
                                                ingredientName: item.ingredientName,
                                                quantity: qty,
                                                unit: item.unit,
                                                unitPrice: item.unitPrice,
                                                totalPrice: qty * item.unitPrice,
                                                batchNumber: item.batchNumber,
                                                expiryDate: item.expiryDate,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.unitPrice.toStringAsFixed(0),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(labelText: 'Harga/${item.unit}'),
                                          onChanged: (val) {
                                            final cost = double.tryParse(val) ?? item.unitPrice;
                                            setState(() {
                                              _purchaseItems[index] = PurchaseItemModel(
                                                id: item.id,
                                                purchaseId: item.purchaseId,
                                                ingredientId: item.ingredientId,
                                                ingredientName: item.ingredientName,
                                                quantity: item.quantity,
                                                unit: item.unit,
                                                unitPrice: cost,
                                                totalPrice: item.quantity * cost,
                                                batchNumber: item.batchNumber,
                                                expiryDate: item.expiryDate,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Batch: ${item.batchNumber ?? "-"}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      Text(
                                        'Subtotal: ${CurrencyFormatter.format(item.totalPrice)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),

                    // Total & Submit
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembelian:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(
                            CurrencyFormatter.format(_totalPurchaseAmount),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePurchase,
                        child: const Text('Simpan Pembelian & Perbarui Stok'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
