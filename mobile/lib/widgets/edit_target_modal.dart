import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sanchay_target.dart';
import '../services/auth_service.dart';
import '../services/target_service.dart';
import '../theme/app_theme.dart';

class EditTargetModal extends StatefulWidget {
  final String vaultId;
  final SanchayTarget? target;

  const EditTargetModal({
    super.key,
    required this.vaultId,
    this.target,
  });

  static Future<void> show(
    BuildContext context, {
    required String vaultId,
    SanchayTarget? target,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditTargetModal(vaultId: vaultId, target: target),
    );
  }

  @override
  State<EditTargetModal> createState() => _EditTargetModalState();
}

class _EditTargetModalState extends State<EditTargetModal> {
  late TextEditingController _titleController;
  late TextEditingController _capController;
  late DateTime _selectedDeadline;
  late String _selectedCategory;
  late int _selectedColorValue;
  late bool _isActive;
  late bool _isPrimary;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'General', 'icon': Icons.savings_outlined},
    {'name': 'Emergency', 'icon': Icons.security_outlined},
    {'name': 'Travel', 'icon': Icons.flight_takeoff_outlined},
    {'name': 'Vehicle', 'icon': Icons.directions_car_outlined},
    {'name': 'Gadget', 'icon': Icons.devices_outlined},
    {'name': 'Property', 'icon': Icons.home_outlined},
    {'name': 'Investment', 'icon': Icons.trending_up_outlined},
  ];

  final List<int> _colors = const [
    0xFFDC2626, // Crimson
    0xFF059669, // Emerald
    0xFF2563EB, // Sapphire
    0xFFD97706, // Amber
    0xFF7C3AED, // Purple
    0xFF0891B2, // Cyan
    0xFF1E293B, // Obsidian
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.target;

    _titleController = TextEditingController(text: t?.title ?? 'Savings Vault');

    final capVal = t?.targetCap ?? 100000.0;
    _capController = TextEditingController(
      text: capVal.truncateToDouble() == capVal
          ? capVal.toInt().toString()
          : capVal.toStringAsFixed(2),
    );

    _selectedDeadline = t?.targetDate ?? DateTime.now().add(const Duration(days: 90));
    _selectedCategory = t?.category ?? 'General';

    // Parse initial color value
    int initialColor = 0xFFDC2626;
    if (t != null) {
      try {
        final hex = t.accentColorHex.replaceAll('#', '');
        if (hex.length == 6) {
          initialColor = int.parse('0xFF$hex');
        } else if (hex.length == 8) {
          initialColor = int.parse('0x$hex');
        }
      } catch (_) {}
    }
    _selectedColorValue = initialColor;

    _isActive = !(t?.isPaused ?? false);
    _isPrimary = t?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _capController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline.isAfter(now)
          ? _selectedDeadline
          : now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.obsidian,
              onPrimary: Colors.white,
              onSurface: AppColors.obsidian,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final capText = _capController.text.replaceAll(',', '').trim();
    final cap = double.tryParse(capText) ?? 0.0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a goal title'),
          backgroundColor: AppColors.crimson,
        ),
      );
      return;
    }

    if (cap <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target cap must be greater than zero (₹)'),
          backgroundColor: AppColors.crimson,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await TargetVaultService.updateVault(
      vaultId: widget.vaultId,
      title: title,
      targetCap: cap,
      deadline: _selectedDeadline,
      category: _selectedCategory,
      colorValue: _selectedColorValue,
      isActive: _isActive,
      isPrimary: _isPrimary,
      bannerUrl: widget.target?.imageUrl,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Goal updated',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update goal. Please try again.'),
          backgroundColor: AppColors.crimson,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _deleteVault(String vaultId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (uid.isEmpty) return;

    // Pop sheet instantly
    Navigator.of(context).pop();

    AuthService.firestoreInstance
        .collection('users')
        .doc(uid)
        .collection('targets')
        .doc(vaultId)
        .delete()
        .then((_) {
          debugPrint("Vault deleted successfully");
        })
        .catchError((e) {
          debugPrint("Delete error: $e");
        });
  }

  void _handleDelete() {
    _deleteVault(widget.vaultId);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.14),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 28 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(_selectedColorValue).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: Color(_selectedColorValue), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONFIGURE VAULT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(_selectedColorValue),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Edit Goal Target',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 1. Goal Title Input
            Text(
              'GOAL TITLE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.obsidian,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Color(_selectedColorValue), width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Target Savings Cap (₹)
            Text(
              'TARGET SAVINGS CAP (₹)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _capController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.obsidian,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(_selectedColorValue),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Color(_selectedColorValue), width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 3. Target Deadline Date Picker
            Text(
              'TARGET DEADLINE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceContainerHigh),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 18, color: Color(_selectedColorValue)),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDeadline),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_selectedDeadline.difference(DateTime.now()).inDays.clamp(1, 99999)} days left',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 4. Accent Color Selector
            Text(
              'ACCENT COLOR',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _colors.map((cVal) {
                final isSelected = _selectedColorValue == cVal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorValue = cVal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(cVal),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Color(cVal).withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // 5. Category Chips
            Text(
              'CATEGORY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final name = cat['name'] as String;
                  final icon = cat['icon'] as IconData;
                  final isSelected = _selectedCategory == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(
                        icon,
                        size: 14,
                        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                      label: Text(name),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.obsidian,
                      ),
                      selectedColor: Color(_selectedColorValue),
                      backgroundColor: AppColors.surfaceContainerLow,
                      side: BorderSide(
                        color: isSelected
                            ? Color(_selectedColorValue)
                            : AppColors.surfaceContainerHigh,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = name);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // 6. Active Toggle & Primary Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Pacing Active',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.obsidian,
                      ),
                    ),
                    subtitle: Text(
                      _isActive ? 'Target runs daily run-rate pacing calculations' : 'Goal pacing is paused',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    value: _isActive,
                    activeColor: Color(_selectedColorValue),
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Primary Goal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.obsidian,
                      ),
                    ),
                    subtitle: Text(
                      _isPrimary ? 'Featured on dashboard main view' : 'Standard secondary vault',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    value: _isPrimary,
                    activeColor: AppColors.obsidian,
                    onChanged: (val) => setState(() => _isPrimary = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Save Changes Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(_selectedColorValue),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // 8. Delete Vault Button (Red Button at bottom)
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _handleDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.crimson, size: 18),
                label: Text(
                  'Delete Vault',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.crimson,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.crimson.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: AppColors.crimson.withOpacity(0.04),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
