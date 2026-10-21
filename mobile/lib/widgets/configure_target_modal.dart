import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sanchay_target.dart';
import '../providers/sanchay_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

import 'create_target_modal.dart';
import 'edit_target_modal.dart';
export 'create_target_modal.dart';
export 'edit_target_modal.dart';

class ConfigureTargetModal extends StatefulWidget {
  final SanchayTarget? target;
  final bool isNewVault;

  const ConfigureTargetModal({super.key, this.target, this.isNewVault = false});

  static Future<void> show(
    BuildContext context, {
    SanchayTarget? target,
    bool isNewVault = false,
  }) {
    if (isNewVault || target == null) {
      return CreateTargetModal.show(context);
    } else {
      return EditTargetModal.show(context, vaultId: target.id, target: target);
    }
  }

  @override
  State<ConfigureTargetModal> createState() => _ConfigureTargetModalState();
}

class _ConfigureTargetModalState extends State<ConfigureTargetModal> {
  late TextEditingController nameController;
  late TextEditingController capController;
  late TextEditingController imageController;
  late DateTime selectedDate;
  late bool isTargetActiveToggle;
  late bool isPrimaryToggle;
  late String selectedCategory;
  late String selectedIcon;
  late String selectedColorHex;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Emergency', 'icon': 'security', 'color': '#DC2626'},
    {'name': 'Travel', 'icon': 'flight', 'color': '#2563EB'},
    {'name': 'Vehicle', 'icon': 'directions_car', 'color': '#D97706'},
    {'name': 'Gadget', 'icon': 'laptop', 'color': '#7C3AED'},
    {'name': 'Property', 'icon': 'home', 'color': '#059669'},
    {'name': 'Investment', 'icon': 'trending_up', 'color': '#0891B2'},
    {'name': 'General', 'icon': 'savings', 'color': '#1E293B'},
  ];

  final List<String> _colors = [
    '#DC2626', // Crimson
    '#059669', // Emerald
    '#2563EB', // Sapphire
    '#D97706', // Amber
    '#7C3AED', // Purple
    '#0891B2', // Cyan
    '#1E293B', // Obsidian
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<SanchayProvider>();
    final t = widget.target;

    final defaultTitle = widget.isNewVault
        ? 'Japan Vacation Fund'
        : (t?.title ?? provider.targetName);

    final defaultCap = widget.isNewVault
        ? 50000.0
        : (t?.targetCap ?? provider.goalCap);

    final defaultDate = widget.isNewVault
        ? DateTime.now().add(const Duration(days: 90))
        : (t?.targetDate ?? provider.targetDate);

    final defaultPaused = widget.isNewVault ? false : (t?.isPaused ?? provider.isTargetPaused);

    nameController = TextEditingController(text: defaultTitle);
    capController = TextEditingController(
      text: defaultCap.truncateToDouble() == defaultCap
          ? defaultCap.toInt().toString()
          : defaultCap.toString(),
    );
    imageController = TextEditingController(text: t?.imageUrl ?? '');
    selectedDate = defaultDate;
    isTargetActiveToggle = !defaultPaused;
    isPrimaryToggle = t?.isPrimary ?? widget.isNewVault ? false : true;
    selectedCategory = t?.category ?? (widget.isNewVault ? 'Travel' : 'General');
    selectedIcon = t?.iconName ?? (widget.isNewVault ? 'flight' : 'savings');
    selectedColorHex = t?.accentColorHex ?? (widget.isNewVault ? '#2563EB' : '#DC2626');
  }

  ImageProvider? _resolveImageProvider(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    try {
      final f = File(trimmed);
      if (f.existsSync()) {
        return FileImage(f);
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    capController.dispose();
    imageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(now)
          ? selectedDate
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
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _saveTargetEngine() async {
    final name = nameController.text.trim().isEmpty
        ? 'Savings Goal'
        : nameController.text.trim();
    final cap = double.tryParse(capController.text.trim()) ?? 100000.0;

    if (cap <= 0) {
      CenterAlert.show(
        context,
        message: 'Please enter a valid amount',
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final vaultId = widget.target?.id ?? 'vault_${DateTime.now().millisecondsSinceEpoch}';
      final imagePath = imageController.text.trim();

      final targetDocData = <String, dynamic>{
        'title': name,
        'targetCap': cap,
        'targetDate': Timestamp.fromDate(selectedDate),
        'isPaused': !isTargetActiveToggle,
        'category': selectedCategory,
        'accentColorHex': selectedColorHex,
        'iconName': selectedIcon,
        'isPrimary': isPrimaryToggle,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (imagePath.isNotEmpty) {
        targetDocData['imageUrl'] = imagePath;
        targetDocData['imagePath'] = imagePath;
      }
      if (widget.isNewVault || widget.target == null) {
        targetDocData['createdAt'] = FieldValue.serverTimestamp();
        targetDocData['currentAccumulation'] = 0.0;
      }

      if (currentUid.isNotEmpty) {
        try {
          await AuthService.firestoreInstance
              .collection('users')
              .doc(currentUid)
              .collection('targets')
              .doc(vaultId)
              .set(targetDocData, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Firestore target doc write warning: $e');
        }
      }

      if (!mounted) return;
      final provider = context.read<SanchayProvider>();

      if (widget.isNewVault || widget.target == null) {
        // Create new vault
        final newVault = SanchayTarget(
          id: vaultId,
          title: name,
          targetCap: cap,
          targetDate: selectedDate,
          isPaused: !isTargetActiveToggle,
          category: selectedCategory,
          accentColorHex: selectedColorHex,
          iconName: selectedIcon,
          imageUrl: imagePath.isNotEmpty ? imagePath : null,
          isPrimary: isPrimaryToggle,
        );
        await provider.createVault(newVault);
      } else {
        // Update existing vault
        final updated = widget.target!.copyWith(
          title: name,
          targetCap: cap,
          targetDate: selectedDate,
          isPaused: !isTargetActiveToggle,
          category: selectedCategory,
          accentColorHex: selectedColorHex,
          iconName: selectedIcon,
          imageUrl: imagePath.isNotEmpty ? imagePath : null,
          isPrimary: isPrimaryToggle,
        );
        await provider.updateVault(updated);
        if (isPrimaryToggle) {
          await provider.setPrimaryVault(updated.id);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      CenterAlert.show(
        context,
        message: widget.isNewVault ? '✓ Goal Vault Created' : '✓ Goal Target Updated',
        subtitle: '$name set to ₹${cap.toStringAsFixed(0)}',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.emerald,
      );
    } catch (e) {
      debugPrint('Error saving savings goal: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        CenterAlert.show(
          context,
          message: 'Could not save goal',
          subtitle: e.toString(),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.crimson,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final remainingDays = selectedDate.difference(DateTime.now()).inDays.clamp(1, 99999);
    final isNew = widget.isNewVault || widget.target == null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.12),
            blurRadius: 36,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.obsidian.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isNew ? Icons.add_circle_outline : Icons.tune_rounded,
                        color: AppColors.obsidian,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNew ? 'NEW SAVINGS TARGET' : 'CONFIGURE GOAL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.crimson,
                          ),
                        ),
                        Text(
                          isNew ? 'Create Multi-Vault Goal' : 'Edit Target Parameters',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Target Name Input
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
              controller: nameController,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.obsidian),
              decoration: InputDecoration(
                hintText: 'E.g., Emergency Buffer, Japan Trip',
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Goal Target Cap
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
              controller: capController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.obsidian),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Category & Icon Chips
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
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isSel = selectedCategory == cat['name'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedCategory = cat['name'] as String;
                        selectedIcon = cat['icon'] as String;
                        selectedColorHex = cat['color'] as String;
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.obsidian : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : AppColors.obsidian,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 4. Accent Color Selector
            Text(
              'ACCENT COLOR THEME',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _colors.map((hex) {
                final isSel = selectedColorHex == hex;
                final c = Color(int.parse('0xFF${hex.replaceAll("#", "")}'));
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedColorHex = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.black : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 5. Target Deadline Date Picker
            Text(
              'TARGET DEADLINE DATE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.obsidian),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('MMMM d, yyyy').format(selectedDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$remainingDays days left',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. Vault Image / Banner (Optional)
            Text(
              'VAULT IMAGE / BANNER (OPTIONAL)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final prov = _resolveImageProvider(imageController.text.trim());
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse('0xFF${selectedColorHex.replaceAll("#", "")}')).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          image: prov != null
                              ? DecorationImage(
                                  image: prov,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: prov == null
                            ? const Icon(Icons.image_outlined, size: 20, color: AppColors.onSurfaceVariant)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: imageController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.obsidian,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Image URL or file path (https://...)',
                        hintStyle: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 7. Active Toggle & Primary Toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Goal Active & Pacing', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: const Text('Include in daily Safe-to-Spend pacing', style: TextStyle(fontSize: 11)),
              value: isTargetActiveToggle,
              activeColor: AppColors.emerald,
              onChanged: (val) => setState(() => isTargetActiveToggle = val),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Set as Primary Vault', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: const Text('Feature this goal on the main dashboard card', style: TextStyle(fontSize: 11)),
              value: isPrimaryToggle,
              activeColor: AppColors.obsidian,
              onChanged: (val) => setState(() => isPrimaryToggle = val),
            ),
            const SizedBox(height: 20),

            // Save Action Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveTargetEngine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isNew ? 'Create Goal Vault' : 'Save Goal Settings',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),

            // Red Delete Vault Button (Only in Edit mode)
            if (!isNew && widget.target != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : () => deleteVault(widget.target!.id),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.crimson),
                label: Text(
                  'Delete Vault',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.crimson,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.crimson.withOpacity(0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppColors.crimson.withOpacity(0.04),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> deleteVault(String vaultId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vault?'),
        content: const Text('This will remove this goal and its allocation history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
      final provider = context.read<SanchayProvider>();
      Navigator.pop(context); // Pop bottom sheet immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault deleted successfully')),
      );

      if (uid.isNotEmpty) {
        AuthService.firestoreInstance
            .collection('users')
            .doc(uid)
            .collection('targets')
            .doc(vaultId)
            .delete()
            .catchError((e) {
          debugPrint('Error deleting vault from Firestore: $e');
        });
        
        try {
          provider.deleteVault(vaultId);
        } catch (_) {}
      }
    }
  }
}
