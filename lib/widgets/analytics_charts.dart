import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import 'ai_intelligence_modal.dart';
import 'glass_card.dart';

// Palette mapping for high-precision financial visual hierarchy
const Map<String, Color> categoryColorPalette = {
  'Food & Dining': Color(0xFFDC2626), // Crimson
  'Transit': Color(0xFF0284C7),       // Sky Ocean
  'Bills & Utilities': Color(0xFFD97706), // Amber
  'Lifestyle': Color(0xFF7C3AED),     // Electric Violet
  'Investment': Color(0xFF059669),    // Emerald
  'Direct Inflow': Color(0xFF10B981), // Mint
  'Salary': Color(0xFF047857),        // Deep Emerald
  'General': Color(0xFF64748B),       // Slate
};

Color getCategoryColor(String category) {
  return categoryColorPalette[category] ?? const Color(0xFF475569);
}

// =========================================================================
// 1. Interactive Liquidity & Expense Donut Pie Chart
// =========================================================================
class CategoryDonutChart extends StatefulWidget {
  const CategoryDonutChart({super.key});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;
  String _selectedCategory = '';
  double _selectedAmount = 0.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final breakdown = provider.categoryExpenseBreakdown;
    final totalExpense = breakdown.values.fold(0.0, (acc, val) => acc + val);

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.crimsonFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pie_chart_outline, size: 18, color: AppColors.crimson),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CAPITAL ALLOCATION',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.crimson,
                            ),
                          ),
                          Text(
                            'Where Your Money Went',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${breakdown.length} Categories',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart Graphic & Center Display
          if (breakdown.isEmpty || totalExpense <= 0)
            _buildEmptyDonut(context, provider)
          else
            Column(
              children: [
                SizedBox(
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  _selectedCategory = '';
                                  _selectedAmount = 0.0;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                                final keys = breakdown.keys.toList();
                                if (_touchedIndex >= 0 && _touchedIndex < keys.length) {
                                  _selectedCategory = keys[_touchedIndex];
                                  _selectedAmount = breakdown[_selectedCategory] ?? 0.0;
                                }
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 3,
                          centerSpaceRadius: 56,
                          sections: _generateSections(breakdown, totalExpense),
                        ),
                      ),

                      // Center Display inside Donut Hole
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCategory.isNotEmpty
                                ? _selectedCategory.toUpperCase()
                                : 'TOTAL OUTFLOW',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.formatCurrency(
                              _selectedCategory.isNotEmpty ? _selectedAmount : totalExpense,
                              isSigned: true,
                              isDebit: true,
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.crimson,
                            ),
                          ),
                          if (_selectedCategory.isNotEmpty)
                            Text(
                              '${((_selectedAmount / totalExpense) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Interactive Category Legends Grid
                _buildLegendGrid(context, provider, breakdown, totalExpense),
              ],
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections(Map<String, double> breakdown, double total) {
    final List<PieChartSectionData> list = [];
    final entries = breakdown.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 28.0 : 20.0;
      final color = getCategoryColor(entries[i].key);

      list.add(
        PieChartSectionData(
          color: color,
          value: entries[i].value,
          title: '', // Kept clean with center display and legend
          radius: radius,
          badgePositionPercentageOffset: 0.98,
        ),
      );
    }
    return list;
  }

  Widget _buildEmptyDonut(BuildContext context, SanchayProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surfaceContainerHigh,
                width: 14,
              ),
            ),
            child: const Center(
              child: Icon(Icons.bubble_chart_outlined, color: AppColors.onSurfaceVariant, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Zero Outflows Recorded',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Donut allocation breakdown activates as soon as expenses arrive via UPI or manual ledger entry.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendGrid(
    BuildContext context,
    SanchayProvider provider,
    Map<String, double> breakdown,
    double total,
  ) {
    final entries = breakdown.entries.toList();

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: entries.map((e) {
        final color = getCategoryColor(e.key);
        final pct = ((e.value / total) * 100).toStringAsFixed(0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.surfaceContainerHigh.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                e.key,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                provider.formatCurrency(e.value),
                style: AppTheme.monoNumeric(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($pct%)',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppColors.slateWhisper,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// =========================================================================
// 2. Capital Velocity & Spending Trend Diagram (7-Day Rolling Bar Trend)
// =========================================================================
class SpendingVelocityChart extends StatefulWidget {
  const SpendingVelocityChart({super.key});

  @override
  State<SpendingVelocityChart> createState() => _SpendingVelocityChartState();
}

class _SpendingVelocityChartState extends State<SpendingVelocityChart> {
  int _touchedBarIndex = -1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final days = provider.rolling7DaysSpending;
    final benchmark = provider.dailyTargetBenchmark;
    final highest = provider.highestDaySpending;

    // Y-Axis ceiling with headroom
    final maxY = (highest > benchmark ? highest : benchmark) * 1.25;

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixedGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart, size: 20, color: AppColors.obsidian),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAPITAL VELOCITY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.obsidian,
                        ),
                      ),
                      Text(
                        "This Week's Spending",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              // Target Benchmark Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pace Target: ${provider.formatCurrency(benchmark)}/d',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bar Chart Graphic
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 2000.0 : maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.obsidian,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = days[groupIndex];
                      final amt = item['amount'] as double;
                      return BarTooltipItem(
                        '${item['label']}\n',
                        const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: provider.formatCurrency(amt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.spot == null) {
                        _touchedBarIndex = -1;
                        return;
                      }
                      _touchedBarIndex = response.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                        final item = days[index];
                        final isToday = item['isToday'] as bool;
                        final isTouched = index == _touchedBarIndex;

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isToday ? 'Today' : item['label'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: (isToday || isTouched) ? FontWeight.w700 : FontWeight.w500,
                              color: isToday
                                  ? AppColors.crimson
                                  : (isTouched ? AppColors.obsidian : AppColors.onSurfaceVariant),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 3 : 500,
                  getDrawingHorizontalLine: (val) {
                    return FlLine(
                      color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _generateBarGroups(days, benchmark),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Analytical Insights Bar (Tap opens AI Intelligence Cockpit)
          InkWell(
            onTap: () => AIIntelligenceModal.show(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 15, color: AppColors.emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            highest > 0
                                ? 'Peak: ${provider.formatCurrency(highest)} • AI Health: ${provider.healthScore.totalScore}/100'
                                : 'AI Health: ${provider.healthScore.totalScore}/100 • Zero Spikes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            highest > benchmark ? 'Over Pace' : 'Under Target',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: highest > benchmark ? AppColors.crimson : AppColors.emerald,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 14, color: AppColors.onSurfaceVariant),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups(
    List<Map<String, dynamic>> days,
    double benchmark,
  ) {
    return List.generate(days.length, (i) {
      final item = days[i];
      final amt = item['amount'] as double;
      final isHighest = item['isHighest'] as bool;
      final isTouched = i == _touchedBarIndex;

      final gradientColors = isHighest
          ? [
              const Color(0xFFDC2626),
              const Color(0xFFE11D48),
            ]
          : [
              const Color(0xFF0F172A),
              const Color(0xFF334155),
            ];

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: amt <= 0 ? 50.0 : amt, // subtle minimal floor pill
            width: isTouched ? 16 : 13,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: amt <= 0
                  ? [
                      AppColors.surfaceContainerHigh.withOpacity(0.5),
                      AppColors.surfaceContainerHigh.withOpacity(0.3),
                    ]
                  : gradientColors,
            ),
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: benchmark,
              color: AppColors.surfaceContainerLow.withOpacity(0.4),
            ),
          ),
        ],
      );
    });
  }
}
