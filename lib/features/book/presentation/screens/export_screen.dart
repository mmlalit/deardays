import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

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

class _ExportScreenState extends State<ExportScreen> {
  String _selectedRange = 'All Time';
  int _selectedColorIndex = 2; // default sand (primary)

  static const _dateRanges = ['All Time', 'Last Year', 'Custom'];

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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 22, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Export Your Story',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
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
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.black38,
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
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                range,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      selected ? Colors.white : Colors.black87,
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
                                          color: Colors.black87, width: 2.5)
                                      : null,
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color:
                                                cc.color.withOpacity(0.35),
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
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // ── Digital Edition ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.insert_drive_file_outlined,
                              size: 32, color: AppColors.primary),
                          const SizedBox(height: 10),
                          Text(
                            'Digital Edition',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Perfect for sharing and tablets',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Download High-Quality PDF',
                                style: GoogleFonts.inter(
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
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Order Print Copy',
                          style: GoogleFonts.inter(
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
                color: Colors.black.withOpacity(0.15),
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
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'A PERSONAL JOURNEY',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The Story\nof Sarah',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
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
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
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
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: Colors.black45,
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
