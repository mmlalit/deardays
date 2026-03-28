import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _CoverColor {
  final String label;
  final Color color;
  const _CoverColor(this.label, this.color);
}

enum ExportFormat {
  byYear('By Year', 'Pages in chronological order', Icons.calendar_today_outlined),
  byChapter('By Chapter', 'Pages grouped by theme', Icons.folder_outlined),
  both('Both', 'Combined timeline + chapters', Icons.auto_stories_outlined);

  const ExportFormat(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

class _ExportScreenState extends State<ExportScreen> {
  String _selectedRange = 'All Time';
  int _selectedColorIndex = 2; // default sand (primary)
  ExportFormat _selectedFormat = ExportFormat.both;
  bool _isExporting = false;

  late final JournalRepository _repository = JournalRepository(
    client: Supabase.instance.client,
  );

  static const _dateRanges = ['All Time', 'Last Year', 'Custom'];

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      DateTime? startDate;
      if (_selectedRange == 'Last Year') {
        startDate = DateTime.now().subtract(const Duration(days: 365));
      }

      // Fetch all entries with pagination to avoid truncation.
      final entries = <JournalEntry>[];
      const pageSize = 500;
      while (true) {
        final page = await _repository.getEntries(
          startDate: startDate,
          limit: pageSize,
          offset: entries.length,
        );
        entries.addAll(page);
        if (page.length < pageSize) break;
      }

      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No entries to export.')),
          );
        }
        return;
      }

      final coverColor = _coverColors[_selectedColorIndex].color;
      final pdfDoc = await _buildPdfDocument(entries, coverColor);

      final formatSuffix = switch (_selectedFormat) {
        ExportFormat.byYear => 'Timeline',
        ExportFormat.byChapter => 'Chapters',
        ExportFormat.both => 'Combined',
      };

      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) => pdfDoc.save(),
          name: 'DearDays_$formatSuffix.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<pw.Document> _buildPdfDocument(
    List<JournalEntry> entries,
    Color coverColor,
  ) async {
    final pdf = pw.Document();
    final pdfCoverColor = PdfColor.fromInt(coverColor.value);

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Container(
          color: pdfCoverColor,
          width: double.infinity,
          height: double.infinity,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'A PERSONAL JOURNEY',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  letterSpacing: 3,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'My DearDays\nJournal',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  lineSpacing: 6,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                '${entries.length} entries \u2022 ${_selectedFormat.label}',
                style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xCCFFFFFF),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Entry pages
    for (final entry in entries) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          build: (context) {
            final dateStr = DateFormat.yMMMMd().format(entry.entryDate);
            final moodStr = entry.mood != null ? ' \u2022 ${entry.mood}' : '';

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$dateStr$moodStr',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.SizedBox(height: 16),
                pw.Text(
                  entry.content,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    lineSpacing: 6,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  static const _coverColors = [
    _CoverColor('Sage', Color(0xFF8FAE8B)),
    _CoverColor('Navy', Color(0xFF1E293B)),
    _CoverColor('Sand', Color(0xFFD4A373)),
    _CoverColor('Charcoal', Color(0xFF4A4A4A)),
    _CoverColor('Rose', Color(0xFFC08B8B)),
  ];

  @override
  Widget build(BuildContext context) {
    final coverColor = _coverColors[_selectedColorIndex].color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            const DearDaysHeader(
              title: 'Export Your Story',
              mode: HeaderMode.push,
            ),

            // ── Scrollable body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── Book cover preview ──
                    _buildBookCoverPreview(coverColor),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'COVER PAGE',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.of(context).textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Select Date Range ──
                    _sectionTitle('SELECT DATE RANGE'),
                    const SizedBox(height: 10),
                    Row(
                      children: _dateRanges.map((range) {
                        final selected = _selectedRange == range;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedRange = range),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.of(context).accent
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.of(context).accent
                                      : AppColors.of(context).border,
                                ),
                              ),
                              child: Text(
                                range,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      selected ? Colors.white : AppColors.of(context).textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // ── Select Cover Color ──
                    _sectionTitle('SELECT COVER COLOR'),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_coverColors.length, (i) {
                        final cc = _coverColors[i];
                        final selected = _selectedColorIndex == i;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColorIndex = i),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cc.color,
                                  shape: BoxShape.circle,
                                  border: selected
                                      ? Border.all(
                                          color: AppColors.of(context).textPrimary, width: 2.5)
                                      : null,
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color:
                                                cc.color.withAlpha(89),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cc.label,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppColors.of(context).textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),

                    // ── Export Format ──
                    _sectionTitle('EXPORT FORMAT'),
                    const SizedBox(height: 10),
                    ...ExportFormat.values.map((format) {
                      final selected = _selectedFormat == format;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedFormat = format),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.of(context).accentFaint
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.of(context).accent
                                    : AppColors.of(context).border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  format.icon,
                                  size: 22,
                                  color: selected
                                      ? AppColors.of(context).accent
                                      : AppColors.of(context).textMuted,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        format.label,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? AppColors.of(context).accent
                                              : AppColors.of(context)
                                                  .textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        format.description,
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.of(context)
                                              .textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.of(context).accent
                                          : AppColors.of(context).border,
                                      width: selected ? 2 : 1.5,
                                    ),
                                    color: selected
                                        ? AppColors.of(context).accent
                                        : Colors.transparent,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check,
                                          size: 13, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // ── Digital Edition ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.of(context).textPrimary.withAlpha(10),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.insert_drive_file_outlined,
                              size: 32, color: AppColors.of(context).accent),
                          const SizedBox(height: 10),
                          Text(
                            'Digital Edition',
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.of(context).textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Perfect for sharing and tablets',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.of(context).textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isExporting ? null : _exportPdf,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.of(context).textPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                disabledBackgroundColor: AppColors.of(context).accent.withAlpha(128),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isExporting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                'Download PDF \u2014 ${_selectedFormat.label}',
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Print Edition ──
                    _sectionTitle('PRINT EDITION'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrintCard(
                            icon: Icons.menu_book_outlined,
                            title: 'Softcover',
                            price: '\$29.99',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildPrintCard(
                            icon: Icons.book_outlined,
                            title: 'Hardcover',
                            price: '\$39.99',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Order Print Copy button ──
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Print ordering coming soon!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Order Print Copy',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Book cover preview (tilted) ──
  Widget _buildBookCoverPreview(Color coverColor) {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(-0.12)
          ..rotateZ(-0.03),
        child: Container(
          width: 200,
          height: 280,
          decoration: BoxDecoration(
            color: coverColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.of(context).textPrimary.withAlpha(38),
                blurRadius: 24,
                offset: const Offset(6, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Floral / gradient placeholder
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withAlpha(89),
                      Colors.white.withAlpha(13),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'A PERSONAL JOURNEY',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: Colors.white.withAlpha(191),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The Story\nof Sarah',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '2023 \u2014 2024 Edition',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(178),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section title ──
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.of(context).textMuted,
      ),
    );
  }

  // ── Print card ──
  Widget _buildPrintCard({
    required IconData icon,
    required String title,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).textPrimary.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF1E293B)),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.of(context).textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
