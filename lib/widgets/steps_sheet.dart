import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StepsSheet extends StatelessWidget {
  const StepsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StepsSheet(),
    );
  }

  static const List<Map<String, dynamic>> _steps = [
    {
      'step': 1,
      'icon': Icons.security_outlined,
      'color': Color(0xFF2563EB),
      'title': 'Connect Permissions',
      'desc': 'Enable notification access for autonomous on-device detection.',
    },
    {
      'step': 2,
      'icon': Icons.notifications_active_outlined,
      'color': Color(0xFF059669),
      'title': 'Detect Transactions',
      'desc': 'Sanchat captures verified bank & UPI alerts with zero spam.',
    },
    {
      'step': 3,
      'icon': Icons.category_outlined,
      'color': Color(0xFFD97706),
      'title': 'Categorize Spending',
      'desc': 'Debits and credits are cleanly sorted into your ledger.',
    },
    {
      'step': 4,
      'icon': Icons.speed_rounded,
      'color': Color(0xFF10B981),
      'title': 'Daily Runway Updates',
      'desc': 'Know exactly what you can safely spend today in real time.',
    },
    {
      'step': 5,
      'icon': Icons.shield_outlined,
      'color': Color(0xFF3B82F6),
      'title': 'Allocate to Vaults',
      'desc': 'Lock money away into custom targets and emergency needs.',
    },
    {
      'step': 6,
      'icon': Icons.military_tech_outlined,
      'color': Color(0xFF8B5CF6),
      'title': 'Discipline Rewards',
      'desc': 'Maintain saving streaks, defeat budget bosses & gain XP.',
    },
    {
      'step': 7,
      'icon': Icons.chat_bubble_outline_rounded,
      'color': Color(0xFF0F172A),
      'title': 'Private 1-on-1 Chat',
      'desc': 'Message friends securely without exposing your finances.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How Sanchat Works',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '7 simple steps to financial clarity',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Steps List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: _steps.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final s = _steps[index];
                  final num = s['step'] as int;
                  final icon = s['icon'] as IconData;
                  final color = s['color'] as Color;
                  final title = s['title'] as String;
                  final desc = s['desc'] as String;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step badge + icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.2), width: 1),
                        ),
                        child: Center(
                          child: Icon(icon, size: 18, color: color),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'STEP $num',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• $title',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Got it button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
