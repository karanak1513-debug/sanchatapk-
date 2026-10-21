import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../services/file_export_service.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

class DataExportModal extends StatefulWidget {
  const DataExportModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DataExportModal(),
    );
  }

  @override
  State<DataExportModal> createState() => _DataExportModalState();
}

class _DataExportModalState extends State<DataExportModal> {
  // 'CSV' | 'JSON'
  String _selectedFormat = 'CSV';

  // 'ledger' | 'vaults' | 'full'
  String _selectedScope = 'ledger';

  bool _isExporting = false;
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final txCount = provider.transactions.length;
    final vaultCount = provider.targets.length;

    // Generate preview string
    final String exportContent;
    final String exportFilename;
    final int recordCount;

    if (_selectedFormat == 'CSV') {
      if (_selectedScope == 'vaults') {
        exportContent = FileExportService.generateVaultsCsv(targets: provider.targets);
        exportFilename = 'sanchay_vaults.csv';
        recordCount = vaultCount;
      } else {
        exportContent = FileExportService.generateLedgerCsv(
          transactions: provider.transactions,
          userEmail: provider.userEmail,
        );
        exportFilename = 'sanchay_ledger.csv';
        recordCount = txCount;
      }
    } else {
      exportContent = FileExportService.generateStateBackupJson(
        transactions: provider.transactions,
        targets: provider.targets,
        userName: provider.userName,
        userEmail: provider.userEmail,
        currentSavings: provider.currentSavings,
        safeToSpend: provider.safeToSpend,
      );
      exportFilename = 'sanchay_backup.json';
      recordCount = txCount + vaultCount;
    }

    final approxKb = (exportContent.length / 1024).toStringAsFixed(1);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.obsidian.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
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
                const SizedBox(height: 16),

                // Header
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
                          child: const Icon(Icons.file_download_outlined, color: AppColors.obsidian, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GENUINE FILE EXPORT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: AppColors.crimson,
                              ),
                            ),
                            Text(
                              'Export Financial Data',
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Format Selector (CSV vs JSON)
                Text(
                  'EXPORT FORMAT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormatSelectorCard(
                        id: 'CSV',
                        title: 'CSV Spreadsheet',
                        subtitle: 'Excel & Google Sheets RFC 4180 format',
                        icon: Icons.table_chart_rounded,
                        accentColor: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormatSelectorCard(
                        id: 'JSON',
                        title: 'JSON Backup',
                        subtitle: 'Full cryptographic state backup',
                        icon: Icons.code_rounded,
                        accentColor: AppColors.obsidian,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Scope Selector (if CSV)
                if (_selectedFormat == 'CSV') ...[
                  Text(
                    'DATA SCOPE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildScopeChip(
                        id: 'ledger',
                        label: 'Transactions ($txCount)',
                      ),
                      const SizedBox(width: 8),
                      _buildScopeChip(
                        id: 'vaults',
                        label: 'Multi-Vault Goals ($vaultCount)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // Metadata Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                  ),
                  child: Column(
                    children: [
                      _buildMetaRow('Target Filename', exportFilename),
                      _buildMetaRow('Record Count', '$recordCount items'),
                      _buildMetaRow('Estimated Size', '$approxKb KB'),
                      _buildMetaRow('Compliance', _selectedFormat == 'CSV' ? 'RFC 4180 Escaped' : 'JSON Schema v2.0'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Preview Toggle
                InkWell(
                  onTap: () => setState(() => _showPreview = !_showPreview),
                  child: Row(
                    children: [
                      Icon(_showPreview ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.obsidian),
                      const SizedBox(width: 4),
                      Text(
                        _showPreview ? 'Hide File Preview' : 'Show File Preview',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.obsidian),
                      ),
                    ],
                  ),
                ),

                if (_showPreview) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        exportContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Primary Action: Genuine Save & Share File
                ElevatedButton(
                  onPressed: _isExporting ? null : () => _triggerFileExport(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isExporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.share_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Save & Share $_selectedFormat File',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),

                // Secondary Action: Copy text
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: exportContent));
                    CenterAlert.show(
                      context,
                      message: '✓ Copied to Clipboard',
                      subtitle: 'Ready to paste into sheets or code editor',
                      icon: Icons.copy,
                      iconColor: AppColors.emerald,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Raw Text to Clipboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.obsidian,
                    side: const BorderSide(color: AppColors.surfaceContainerHigh),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSelectorCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSel = _selectedFormat == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSel ? accentColor.withOpacity(0.08) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSel ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isSel ? accentColor : AppColors.onSurfaceVariant, size: 20),
                if (isSel)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSel ? AppColors.obsidian : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip({required String id, required String label}) {
    final isSel = _selectedScope == id;
    return InkWell(
      onTap: () => setState(() => _selectedScope = id),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppColors.obsidian : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : AppColors.obsidian,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.obsidian)),
        ],
      ),
    );
  }

  Future<void> _triggerFileExport(SanchayProvider provider) async {
    setState(() => _isExporting = true);
    try {
      final FileExportResult res;
      if (_selectedFormat == 'CSV') {
        if (_selectedScope == 'vaults') {
          res = await provider.exportVaultsCsvFile();
        } else {
          res = await provider.exportLedgerCsvFile();
        }
      } else {
        res = await provider.exportStateBackupJsonFile();
      }

      if (!mounted) return;
      setState(() => _isExporting = false);

      if (res.success) {
        Navigator.of(context).pop();
        CenterAlert.show(
          context,
          message: '✓ File Exported Successfully',
          subtitle: '${res.filename} (${res.formattedSize})',
          icon: Icons.check_circle_outline,
          iconColor: AppColors.emerald,
        );
      } else {
        CenterAlert.show(
          context,
          message: 'Export failed',
          subtitle: res.errorMessage ?? 'Could not export file',
          icon: Icons.error_outline,
          iconColor: AppColors.crimson,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        CenterAlert.show(
          context,
          message: 'Export failed',
          subtitle: e.toString(),
          icon: Icons.error_outline,
          iconColor: AppColors.crimson,
        );
      }
    }
  }
}
