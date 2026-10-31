import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/repositories/ingredient_repository.dart';

class StockOpnameDialog extends StatefulWidget {
  final IngredientModel ingredient;
  final String userId;
  final String userName;

  const StockOpnameDialog({
    super.key,
    required this.ingredient,
    required this.userId,
    required this.userName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required IngredientModel ingredient,
    required String userId,
    required String userName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StockOpnameDialog(
        ingredient: ingredient,
        userId: userId,
        userName: userName,
      ),
    );
  }

  @override
  State<StockOpnameDialog> createState() => _StockOpnameDialogState();
}

class _StockOpnameDialogState extends State<StockOpnameDialog> {
  final _formKey = GlobalKey<FormState>();
  final IngredientRepository _repo = IngredientRepository();
  late TextEditingController _actualStockController;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _actualStockController = TextEditingController(
      text: widget.ingredient.currentStock.toStringAsFixed(1),
    );
  }

  double get _actualStock => double.tryParse(_actualStockController.text) ?? widget.ingredient.currentStock;
  double get _diff => _actualStock - widget.ingredient.currentStock;

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _repo.adjustStock(
        ingredientId: widget.ingredient.id,
        actualStock: _actualStock,
        reason: _reasonController.text.trim(),
        userId: widget.userId,
        userName: widget.userName,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyesuaikan stok: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Penyesuaian Stok (Opname)\n${widget.ingredient.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Stock Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Stok Sistem Saat Ini:'),
                    Text(
                      '${widget.ingredient.currentStock.toStringAsFixed(1)} ${widget.ingredient.unit}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Actual Counted Stock
              Text('Stok Fisik Sebenarnya (${widget.ingredient.unit})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _actualStockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: widget.ingredient.unit,
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                  if (double.tryParse(val) == null) return 'Masukkan angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Difference indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selisih:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    '${_diff >= 0 ? "+" : ""}${_diff.toStringAsFixed(1)} ${widget.ingredient.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _diff == 0
                          ? AppColors.textSecondary
                          : _diff > 0
                              ? AppColors.success
                              : AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mandatory Reason
              const Text('Alasan Penyesuaian (Wajib)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Tumpah saat pembuatan, kemasan bocor, hasil hitung fisik',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Alasan wajib diisi' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitAdjustment,
          child: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan Penyesuaian'),
        ),
      ],
    );
  }
}
