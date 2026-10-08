import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class CreateTargetModal extends StatefulWidget {
  const CreateTargetModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateTargetModal(),
    );
  }

  @override
  State<CreateTargetModal> createState() => _CreateTargetModalState();
}

class _CreateTargetModalState extends State<CreateTargetModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _capController = TextEditingController();

  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 90));
  String _selectedCategory = 'General';
  int _selectedColorValue = 0xFFDC2626;

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

  void _submitCreate() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_capController.text.replaceAll(',', '')) ?? 0.0;
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Title and Amount')));
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (uid.isEmpty) return;

    final docRef = AuthService.firestoreInstance.collection('users').doc(uid).collection('targets').doc();
    
    // 1. POP IMMEDIATELY (Zero UI lag)
    Navigator.of(context).pop();

    final targetPayload = {
      'id': docRef.id,
      'title': title,
      'targetCap': amount,
      'currentAccumulation': 0.0,
      'category': _selectedCategory,
      'colorValue': _selectedColorValue,
      'deadline': Timestamp.fromDate(_selectedDeadline),
      'targetDate': Timestamp.fromDate(_selectedDeadline),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 2. Commit to Firestore
    docRef.set(targetPayload).catchError((e) {
      debugPrint("Failed to save target: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                  child: Icon(Icons.add_task_rounded, color: Color(_selectedColorValue), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEW SAVINGS VAULT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(_selectedColorValue),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Create Goal Target',
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
                hintText: 'e.g. Japan Vacation Fund, Emergency Reserve',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.outline,
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
                hintText: '50000',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.outline,
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

            // 3. Date Picker for Target Deadline
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
            const SizedBox(height: 24),

            // 6. Submit Button (Instant Zero-Latency Execution)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(_selectedColorValue),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                          const Icon(Icons.check_circle_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Save & Activate Goal',
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
          ],
        ),
      ),
    );
  }
}
