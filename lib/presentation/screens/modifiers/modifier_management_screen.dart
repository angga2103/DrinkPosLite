import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/models/modifier_group_model.dart';
import '../../../data/models/modifier_model.dart';
import '../../../data/repositories/ingredient_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';

class ModifierManagementScreen extends StatefulWidget {
  const ModifierManagementScreen({super.key});

  @override
  State<ModifierManagementScreen> createState() => _ModifierManagementScreenState();
}

class _ModifierManagementScreenState extends State<ModifierManagementScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final IngredientRepository _ingRepo = IngredientRepository();

  List<ModifierGroupModel> _groups = [];
  List<IngredientModel> _ingredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final grps = await _productRepo.getModifierGroups(activeOnly: false);
    final ings = await _ingRepo.getIngredients();
    if (mounted) {
      setState(() {
        _groups = grps;
        _ingredients = ings;
        _isLoading = false;
      });
    }
  }

  void _showAddEditGroupDialog([ModifierGroupModel? existingGroup]) {
    final nameController = TextEditingController(text: existingGroup?.name ?? '');
    String selectionType = existingGroup?.selectionType ?? 'SINGLE';
    bool isRequired = existingGroup?.isRequired ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existingGroup == null ? 'Tambah Jenis Level / Topping' : 'Edit Jenis Level / Topping'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Grup:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Level Pedas, Level Gula, Topping, dll.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Tipe Pemilihan Kasir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectionType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SINGLE',
                      child: Text('Pilih Salah Satu (Level Rasa / Pilihan Tunggal)'),
                    ),
                    DropdownMenuItem(
                      value: 'MULTIPLE',
                      child: Text('Bisa Pilih Banyak (Aneka Topping / Tambahan)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectionType = val);
                  },
                ),
                const SizedBox(height: 14),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wajib Dipilih oleh Pelanggan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Kasir harus memilih minimal 1 opsi', style: TextStyle(fontSize: 11)),
                  value: isRequired,
                  onChanged: (val) => setModalState(() => isRequired = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama grup tidak boleh kosong')),
                  );
                  return;
                }

                final groupToSave = ModifierGroupModel(
                  id: existingGroup?.id ?? IdGenerator.generateId(prefix: 'grp'),
                  name: name,
                  selectionType: selectionType,
                  isRequired: isRequired,
                  displayOrder: existingGroup?.displayOrder ?? (_groups.length + 1),
                );

                await _productRepo.saveModifierGroup(groupToSave);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _loadData();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditOptionDialog(ModifierGroupModel group, [ModifierModel? existingOption]) {
    final nameController = TextEditingController(text: existingOption?.name ?? '');
    final priceController = TextEditingController(
      text: existingOption != null ? existingOption.extraPrice.toStringAsFixed(0) : '0',
    );
    String? selectedIngId = existingOption?.ingredientId;
    final amountController = TextEditingController(
      text: existingOption != null && existingOption.ingredientAmount > 0
          ? existingOption.ingredientAmount.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existingOption == null ? 'Tambah Opsi di ${group.name}' : 'Edit Opsi di ${group.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Opsi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: group.isSingleChoice ? 'Contoh: Sedang, Ekstra Pedas, 50%' : 'Contoh: Boba, Cincau, Keju',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Harga Tambahan (Rp):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0 jika gratis',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 14),

                const Divider(),
                const Text(
                  'Potong Stok Bahan Baku (Opsional):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jika opsi ini dipilih, stok bahan baku akan otomatis berkurang saat penjualan.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: selectedIngId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tidak Ada (Tanpa Potong Bahan)')),
                    ..._ingredients.map((ing) {
                      return DropdownMenuItem(
                        value: ing.id,
                        child: Text('${ing.name} (${ing.unit})'),
                      );
                    }),
                  ],
                  onChanged: (val) => setModalState(() => selectedIngId = val),
                ),

                if (selectedIngId != null) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final selectedIng = _ingredients.firstWhere(
                        (i) => i.id == selectedIngId,
                        orElse: () => _ingredients.first,
                      );
                      return TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Jumlah Bahan Digunakan (${selectedIng.unit}):',
                          hintText: 'Contoh: 30',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama opsi tidak boleh kosong')),
                  );
                  return;
                }

                final extraPrice = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
                final ingAmount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;

                final optionToSave = ModifierModel(
                  id: existingOption?.id ?? IdGenerator.generateId(prefix: 'mod'),
                  groupName: group.name,
                  name: name,
                  extraPrice: extraPrice,
                  ingredientId: selectedIngId,
                  ingredientAmount: ingAmount,
                  isActive: true,
                );

                await _productRepo.saveModifier(optionToSave);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _loadData();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGroup(ModifierGroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Hapus ${group.name}?'),
        content: Text(
          'Seluruh opsi (${group.options.length} opsi) di dalam grup ini akan dihapus dan tidak lagi ditampilkan pada produk mana pun.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              await _productRepo.deleteModifierGroup(group.name);
              if (mounted) {
                Navigator.of(ctx).pop();
                _loadData();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kelola Level & Topping',
      currentRoute: '/products',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Segarkan',
          onPressed: _loadData,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? EmptyStateView(
                  icon: Icons.tune,
                  title: 'Belum Ada Level / Topping',
                  message: 'Buat grup level baru seperti Level Gula, Level Pedas, atau Topping Tambahan.',
                  buttonText: 'Tambah Grup Baru',
                  onButtonPressed: () => _showAddEditGroupDialog(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Grup
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: group.isSingleChoice
                                            ? AppColors.primaryContainer
                                            : AppColors.secondaryContainer,
                                        child: Icon(
                                          group.isSingleChoice ? Icons.radio_button_checked : Icons.checklist,
                                          size: 18,
                                          color: group.isSingleChoice ? AppColors.primary : AppColors.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              group.isSingleChoice
                                                  ? 'Pilihan Tunggal (Radio/Level)'
                                                  : 'Pilihan Ganda (Bisa pilih banyak)',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit Grup',
                                      onPressed: () => _showAddEditGroupDialog(group),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                      tooltip: 'Hapus Grup',
                                      onPressed: () => _confirmDeleteGroup(group),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 18),

                            // List Opsi dalam Grup
                            if (group.options.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Belum ada opsi di grup ${group.name}.',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: group.options.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (ctx, optIdx) {
                                  final opt = group.options[optIdx];
                                  IngredientModel? linkedIng;
                                  if (opt.ingredientId != null) {
                                    try {
                                      linkedIng = _ingredients.firstWhere((i) => i.id == opt.ingredientId);
                                    } catch (_) {}
                                  }

                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(opt.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: linkedIng != null
                                        ? Text(
                                            'Potong ${opt.ingredientAmount} ${linkedIng.unit} (${linkedIng.name})',
                                            style: const TextStyle(fontSize: 11, color: AppColors.primary),
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          opt.extraPrice > 0 ? '+${CurrencyFormatter.format(opt.extraPrice)}' : 'Gratis',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: opt.extraPrice > 0 ? AppColors.primary : AppColors.success,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16),
                                          onPressed: () => _showAddEditOptionDialog(group, opt),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                                          onPressed: () async {
                                            await _productRepo.deleteModifier(opt.id);
                                            _loadData();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 10),

                            // Tombol Tambah Opsi
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: Text('Tambah Opsi di ${group.name}'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showAddEditOptionDialog(group),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Grup Level / Topping'),
        onPressed: () => _showAddEditGroupDialog(),
      ),
    );
  }
}
