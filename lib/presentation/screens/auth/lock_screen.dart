import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _enteredPin = '';
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).loadUsers();
    });
  }

  void _onNumberTap(String number) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length >= 4) {
        _attemptLogin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _enteredPin = '';
    });
  }

  Future<void> _attemptLogin() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih akun pengguna terlebih dahulu')),
      );
      setState(() => _enteredPin = '');
      return;
    }

    final success = await ref.read(authProvider.notifier).login(_selectedUserId!, _enteredPin);
    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      setState(() {
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final users = authState.availableUsers;

    // Default select first user if none selected
    if (_selectedUserId == null && users.isNotEmpty) {
      _selectedUserId = users.first.id;
    }

    final selectedUser = users.firstWhere(
      (u) => u.id == _selectedUserId,
      orElse: () => users.isNotEmpty
          ? users.first
          : UserModel(id: 'dummy', name: 'User', role: 'CASHIER', pinHash: ''),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top App Logo & Name
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_cafe, size: 40, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          AppConstants.appName,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Text(
                          'Aplikasi Kasir Minuman UMKM (Offline)',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),

                    // User Selection & PIN Dots
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        // Dropdown user selection
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUserId,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items: users.map((u) {
                                return DropdownMenuItem<String>(
                                  value: u.id,
                                  child: Row(
                                    children: [
                                      Icon(
                                        u.isLocked ? Icons.lock : Icons.person_outline,
                                        size: 18,
                                        color: u.isLocked ? AppColors.danger : AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${u.name} (${u.role})'),
                                      if (u.isLocked) ...[
                                        const SizedBox(width: 6),
                                        const Text('[TERKUNCI]', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedUserId = val;
                                  _enteredPin = '';
                                });
                              },
                            ),
                          ),
                        ),

                        if (selectedUser.isLocked) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning, color: AppColors.danger, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Akun terkunci karena 5x salah PIN. Masuk dengan akun Pemilik (Owner) untuk membuka kunci.',
                                    style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            authState.errorMessage!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 16),
                        const Text(
                          'Masukkan PIN Keamanan',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        // PIN indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _enteredPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? AppColors.primary : Colors.transparent,
                                border: Border.all(color: AppColors.primary, width: 2),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                    // Numeric Keypad
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        children: [
                          _buildKeypadRow(['1', '2', '3']),
                          const SizedBox(height: 12),
                          _buildKeypadRow(['4', '5', '6']),
                          const SizedBox(height: 12),
                          _buildKeypadRow(['7', '8', '9']),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton('C', _onClear),
                              _buildNumberButton('0'),
                              _buildActionButton('⌫', _onBackspace, isIcon: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Developer footer
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: const [
                          Text(
                            AppConstants.developedByText,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            AppConstants.contactText,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: () => _onNumberTap(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap, {bool isIcon = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
        ),
        child: isIcon
            ? const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textPrimary)
            : Text(
                label,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.danger),
              ),
      ),
    );
  }
}
