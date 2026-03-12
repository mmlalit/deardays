import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/share/data/models/share_card_config.dart';
import 'package:deardays/features/share/presentation/widgets/share_card_preview.dart';
import 'package:deardays/features/share/services/share_card_renderer.dart';
import 'package:deardays/services/ai/ai_service.dart';

class ShareCardScreen extends StatefulWidget {
  final JournalEntry entry;

  const ShareCardScreen({super.key, required this.entry});

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  late TextEditingController _captionController;
  late ShareCardConfig _config;
  bool _isLoadingAi = false;
  bool _isSaving = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    final fallback = _generateFallbackSummary();
    _config = ShareCardConfig(
      platform: SharePlatform.instagram,
      displayText: fallback,
      showDate: true,
      showMood: true,
      showLocation: widget.entry.locationName != null,
      photoUrl: _firstPhotoUrl(),
    );
    _captionController = TextEditingController(text: fallback);
    _captionController.addListener(_onCaptionChanged);

    // Try AI summary
    if (AiService().isConfigured) {
      _generateAiSummary();
    }
  }

  @override
  void dispose() {
    _captionController.removeListener(_onCaptionChanged);
    _captionController.dispose();
    super.dispose();
  }

  String? _firstPhotoUrl() {
    final photos =
        widget.entry.media.where((m) => m.mediaType == 'photo').toList();
    if (photos.isEmpty) return null;
    return photos.first.storagePath;
  }

  String _generateFallbackSummary() {
    final text = widget.entry.polishedContent ?? widget.entry.content;
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final twoSentences = sentences.take(2).join(' ').trim();
    if (twoSentences.length <= 120) return twoSentences;
    return '${twoSentences.substring(0, 117)}...';
  }

  Future<void> _generateAiSummary() async {
    setState(() => _isLoadingAi = true);
    try {
      final text = widget.entry.polishedContent ?? widget.entry.content;
      final summary = await AiService().generateShareSummary(text);
      if (mounted) {
        _captionController.text = summary;
        setState(() {
          _config = _config.copyWith(displayText: summary);
          _isLoadingAi = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAi = false);
      }
    }
  }

  void _onCaptionChanged() {
    setState(() {
      _config = _config.copyWith(displayText: _captionController.text);
    });
  }

  void _selectPlatform(SharePlatform platform) {
    HapticFeedback.lightImpact();
    setState(() {
      _config = _config.copyWith(platform: platform);
    });
  }

  void _selectStyle(CardStyle style) {
    HapticFeedback.lightImpact();
    setState(() {
      _config = _config.copyWith(style: style);
    });
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final bytes = await ShareCardRenderer.renderToPng(_repaintKey);

      if (!ShareCardRenderer.supportsNativeShare) {
        // Windows fallback
        final path = await ShareCardRenderer.saveToGallery(bytes);
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved and path copied to clipboard:\n$path'),
            ),
          );
        }
      } else {
        final dateStr =
            DateFormat('MMMM d, yyyy').format(widget.entry.entryDate);
        await ShareCardRenderer.shareImage(bytes, subject: 'DearDays - $dateStr');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final bytes = await ShareCardRenderer.renderToPng(_repaintKey);
      final path = await ShareCardRenderer.saveToGallery(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _config.displayText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Platform tabs
                    _buildPlatformTabs(colors),
                    const SizedBox(height: 20),

                    // Live card preview
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withAlpha(20),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ShareCardPreview(
                            config: _config,
                            entry: widget.entry,
                            repaintKey: _repaintKey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Caption editor
                    _buildCaptionSection(colors),
                    const SizedBox(height: 20),

                    // Style selector
                    _buildStyleSelector(colors),
                    const SizedBox(height: 20),

                    // Toggle chips
                    _buildToggleChips(colors),
                    const SizedBox(height: 28),

                    // Action buttons
                    _buildActionButtons(colors),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.close_rounded,
                size: 24,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Share Memory',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Platform tabs (Instagram, WhatsApp, X) ───────────────────────────────

  Widget _buildPlatformTabs(AppPalette colors) {
    return Row(
      children: SharePlatform.values.map((platform) {
        final isActive = _config.platform == platform;
        return Expanded(
          child: GestureDetector(
            onTap: () => _selectPlatform(platform),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? colors.accentFaint : colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? colors.accent : colors.border,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    platform.icon,
                    size: 22,
                    color: isActive ? colors.accent : colors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    platform.label,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Caption editor ───────────────────────────────────────────────────────

  Widget _buildCaptionSection(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Caption',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: _isLoadingAi
              ? _buildShimmer(colors)
              : TextField(
                  controller: _captionController,
                  maxLines: 3,
                  minLines: 2,
                  style: GoogleFonts.newsreader(
                    fontSize: 15,
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                    hintText: 'Write your caption...',
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textMuted,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        if (AiService().isConfigured)
          GestureDetector(
            onTap: _isLoadingAi ? null : _generateAiSummary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u2728', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  'Regenerate',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isLoadingAi ? colors.textMuted : colors.accent,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShimmer(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 200,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Style selector ───────────────────────────────────────────────────────

  Widget _buildStyleSelector(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Style',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: CardStyle.values.map((style) {
            final isActive = _config.style == style;
            return Expanded(
              child: GestureDetector(
                onTap: () => _selectStyle(style),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? colors.accentFaint : colors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? colors.accent : colors.border,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildStyleThumb(style, isActive, colors),
                      const SizedBox(height: 6),
                      Text(
                        _styleName(style),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? colors.accent
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStyleThumb(
    CardStyle style,
    bool isActive,
    AppPalette colors,
  ) {
    const double size = 28;
    switch (style) {
      case CardStyle.minimal:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Center(
            child: Container(width: 14, height: 2, color: const Color(0xFF888888)),
          ),
        );
      case CardStyle.vibrant:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case CardStyle.dark:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Container(width: 14, height: 2, color: const Color(0xFF888888)),
          ),
        );
      case CardStyle.nature:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F5ED), Color(0xFFE8DFD0)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text('\u{1F33F}', style: TextStyle(fontSize: 12)),
          ),
        );
    }
  }

  String _styleName(CardStyle style) {
    switch (style) {
      case CardStyle.minimal:
        return 'Minimal';
      case CardStyle.vibrant:
        return 'Vibrant';
      case CardStyle.dark:
        return 'Dark';
      case CardStyle.nature:
        return 'Nature';
    }
  }

  // ─── Toggle chips ─────────────────────────────────────────────────────────

  Widget _buildToggleChips(AppPalette colors) {
    return Row(
      children: [
        _buildChip('Date', _config.showDate, colors, (v) {
          setState(() => _config = _config.copyWith(showDate: v));
        }),
        const SizedBox(width: 8),
        _buildChip('Mood', _config.showMood, colors, (v) {
          setState(() => _config = _config.copyWith(showMood: v));
        }),
        if (widget.entry.locationName != null) ...[
          const SizedBox(width: 8),
          _buildChip('Location', _config.showLocation, colors, (v) {
            setState(() => _config = _config.copyWith(showLocation: v));
          }),
        ],
      ],
    );
  }

  Widget _buildChip(
    String label,
    bool isActive,
    AppPalette colors,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!isActive);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.accentFaint : colors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? colors.accent : colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? colors.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────────────────

  Widget _buildActionButtons(AppPalette colors) {
    final isWindows = !ShareCardRenderer.supportsNativeShare;
    final shareLabel = isWindows
        ? (_isSharing ? 'Saving...' : 'Save & Copy Path')
        : (_isSharing ? 'Sharing...' : 'Share');

    return Column(
      children: [
        // Share / Save+Copy — primary
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _share,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isWindows ? Icons.save_alt_rounded : Icons.share_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
            label: Text(
              shareLabel,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: colors.accent.withAlpha(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Save to Gallery
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _saveToGallery,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : Icon(Icons.download_rounded, size: 20, color: colors.accent),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Image',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Copy Text
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton.icon(
            onPressed: _copyText,
            icon: Icon(Icons.copy_rounded, size: 18, color: colors.textSecondary),
            label: Text(
              'Copy Text',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
