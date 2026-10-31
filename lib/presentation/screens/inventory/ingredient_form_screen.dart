import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/repositories/ingredient_repository.dart';

class IngredientFormScreen extends StatefulWidget {
  final IngredientModel? ingredient;

  const IngredientFormScreen({super.key, this.ingredient});

  @override
  State<IngredientFormScreen> createState() => _IngredientFormScreenState();
}

class _IngredientFormScreenState extends State<IngredientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final IngredientRepository _repo = IngredientRepository();

  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _costController;
  bool _isPackaging = false;
  bool _isSaving = false;

  final List<String> _commonUnits = ['gram', 'ml', 'pcs', 'sachet', 'buah', 'botol', 'lembar'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _unitController = TextEditingController(text: widget.ingredient?.unit ?? 'gram');
    _stockController = TextEditingController(
      text: widget.ingredient?.currentStock.toStringAsFixed(1) ?? '1000',
    );
    _minStockController = TextEditingController(
      text: widget.ingredient?.minimumStock.toStringAsFixed(1) ?? '100',
    );
    _costController = TextEditingController(
      text: widget.ingredient?.costPerUnit.toStringAsFixed(1) ?? '50',
    );
    _isPackaging = widget.ingredient?.isPackaging ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final id = widget.ingredient?.id ?? IdGenerator.generateId(prefix: 'ing');
    final stock = double.tryParse(_stockController.text) ?? 0.0;
    final minStock = double.tryParse(_minStockController.text) ?? 10.0;
    final cost = double.tryParse(_costController.text) ?? 0.0;

    final ing = IngredientModel(
      id: id,
      name: _nameController.text.trim(),
      unit: _unitController.text.trim().toLowerCase(),
      currentStock: stock,
      minimumStock: minStock,
      costPerUnit: cost,
      lastBuyPrice: cost,
      isPackaging: _isPackaging,
    );

    await _repo.saveIngredient(ing);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ingredient != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Bahan Baku' : 'Tambah Bahan Baku Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              const Text('Nama Bahan Baku / Kemasan', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Contoh: Daun Teh Melati, Susu UHT, Cup 16oz'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama bahan wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // Unit
              const Text('Satuan Pemakaian / Resep', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(hintText: 'gram, ml, pcs, sachet'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Satuan wajib diisi' : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _commonUnits.map((u) {
                  return ActionChip(
                    label: Text(u),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => setState(() => _unitController.text = u),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Stock & Min Stock
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stok Saat Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _stockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val == null || double.tryParse(val) == null ? 'Wajib angka' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Batas Stok Minimum', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _minStockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val == null || double.tryParse(val) == null ? 'Wajib angka' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cost Per Unit
              const Text('Biaya per Satuan (HPP Bahan dalam Rupiah)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Contoh: Jika 1 kg (1000g) teh dibeli seharga Rp50.000, maka biaya per gram adalah Rp50.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: 'Rp '),
                validator: (val) => val == null || double.tryParse(val) == null ? 'Wajib angka' : null,
              ),
              const SizedBox(height: 16),

              // Is Packaging Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bahan Kemasan / Packaging', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Centang jika bahan ini adalah gelas plastik, sedotan, atau kantong kresek', style: TextStyle(fontSize: 12)),
                value: _isPackaging,
                onChanged: (val) => setState(() => _isPackaging = val ?? false),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(isEditing ? 'Perbarui Bahan' : 'Simpan Bahan Baku'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
