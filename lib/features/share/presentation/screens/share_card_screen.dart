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
  bool _isSharingIG = false;
  bool _isSharingWA = false;

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

  Future<void> _shareToInstagram() async {
    setState(() => _isSharingIG = true);
    try {
      // Switch to Instagram format before rendering
      if (_config.platform != SharePlatform.instagram) {
        setState(() {
          _config = _config.copyWith(platform: SharePlatform.instagram);
        });
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 100));
      final bytes = await ShareCardRenderer.renderToPng(_repaintKey);

      if (!ShareCardRenderer.supportsNativeShare) {
        await _windowsFallback(bytes, 'Instagram');
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
      if (mounted) setState(() => _isSharingIG = false);
    }
  }

  Future<void> _shareToWhatsApp() async {
    setState(() => _isSharingWA = true);
    try {
      // Switch to WhatsApp format before rendering
      if (_config.platform != SharePlatform.whatsapp) {
        setState(() {
          _config = _config.copyWith(platform: SharePlatform.whatsapp);
        });
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 100));
      final bytes = await ShareCardRenderer.renderToPng(_repaintKey);

      if (!ShareCardRenderer.supportsNativeShare) {
        await _windowsFallback(bytes, 'WhatsApp');
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
      if (mounted) setState(() => _isSharingWA = false);
    }
  }

  Future<void> _windowsFallback(Uint8List bytes, String platform) async {
    final path = await ShareCardRenderer.saveToGallery(bytes);
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$platform image saved & path copied:\n$path'),
        ),
      );
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

                    // Platform tabs (Instagram / WhatsApp)
                    _buildPlatformTabs(colors),
                    const SizedBox(height: 20),

                    // Phone mockup with live card preview
                    Center(child: _buildPhoneMockup(colors)),
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

                    // Two share buttons + save
                    _buildShareButtons(colors),
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

  // ─── Platform tabs (Instagram / WhatsApp only) ────────────────────────────

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
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? colors.accentFaint : colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? colors.accent : colors.border,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    platform.icon,
                    size: 20,
                    color: isActive ? colors.accent : colors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    platform.label,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
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

  // ─── Phone mockup with platform-specific preview ──────────────────────────

  Widget _buildPhoneMockup(AppPalette colors) {
    final isIG = _config.platform == SharePlatform.instagram;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isIG ? 240 : 320,
      decoration: BoxDecoration(
        color: isIG ? Colors.black : const Color(0xFFECE5DD),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(20),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Platform header
          if (isIG) _buildIGHeader() else _buildWAHeader(colors),
          // Card preview
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isIG ? 0 : 10,
              vertical: isIG ? 0 : 6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isIG ? 0 : 12),
              child: ShareCardPreview(
                config: _config,
                entry: widget.entry,
                repaintKey: _repaintKey,
              ),
            ),
          ),
          // Platform footer
          if (isIG) _buildIGFooter() else _buildWAFooter(colors),
        ],
      ),
    );
  }

  // ─── Instagram Story mockup elements ──────────────────────────────────────

  Widget _buildIGHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
        children: [
          // Profile pic placeholder
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(180), width: 2),
              color: Colors.white.withAlpha(30),
            ),
            child: Icon(Icons.person, size: 18, color: Colors.white.withAlpha(180)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Story',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Just now',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: Colors.white.withAlpha(150),
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.more_horiz, size: 20, color: Colors.white.withAlpha(180)),
        ],
      ),
    );
  }

  Widget _buildIGFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Row(
        children: [
          // Camera icon
          _igFooterIcon(Icons.camera_alt_outlined),
          const SizedBox(width: 12),
          // Message field
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(80)),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                'Send message',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white.withAlpha(120),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Heart
          _igFooterIcon(Icons.favorite_border_rounded),
          const SizedBox(width: 12),
          // Send
          _igFooterIcon(Icons.send_outlined),
        ],
      ),
    );
  }

  Widget _igFooterIcon(IconData icon) {
    return Icon(icon, size: 22, color: Colors.white.withAlpha(180));
  }

  // ─── WhatsApp chat bubble mockup elements ─────────────────────────────────

  Widget _buildWAHeader(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_back, size: 20, color: Colors.white.withAlpha(200)),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(40),
            ),
            child: Icon(Icons.person, size: 18, color: Colors.white.withAlpha(200)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Friend',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'online',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: Colors.white.withAlpha(180),
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.videocam_outlined, size: 22, color: Colors.white.withAlpha(200)),
          const SizedBox(width: 16),
          Icon(Icons.call_outlined, size: 20, color: Colors.white.withAlpha(200)),
        ],
      ),
    );
  }

  Widget _buildWAFooter(AppPalette colors) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Timestamp + read receipt
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: const Color(0xFF8696A0),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 14, color: const Color(0xFF53BDEB)),
              ],
            ),
          ),
          // Message input bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.emoji_emotions_outlined, size: 22, color: const Color(0xFF8696A0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Type a message',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: const Color(0xFF8696A0),
                    ),
                  ),
                ),
                Icon(Icons.attach_file, size: 20, color: const Color(0xFF8696A0)),
                const SizedBox(width: 10),
                Icon(Icons.camera_alt, size: 20, color: const Color(0xFF8696A0)),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
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

  // ─── Share buttons — Instagram + WhatsApp side by side ────────────────────

  Widget _buildShareButtons(AppPalette colors) {
    return Column(
      children: [
        // Two share buttons side by side
        Row(
          children: [
            // Instagram Story button
            Expanded(
              child: _buildShareButton(
                label: 'Instagram',
                icon: Icons.camera_alt_rounded,
                isLoading: _isSharingIG,
                gradient: const [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                onTap: _isSharingIG ? null : _shareToInstagram,
              ),
            ),
            const SizedBox(width: 12),
            // WhatsApp button
            Expanded(
              child: _buildShareButton(
                label: 'WhatsApp',
                icon: Icons.chat_rounded,
                isLoading: _isSharingWA,
                gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
                onTap: _isSharingWA ? null : _shareToWhatsApp,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Save image — secondary
        SizedBox(
          width: double.infinity,
          height: 48,
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
      ],
    );
  }

  Widget _buildShareButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required List<Color> gradient,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withAlpha(50),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              isLoading ? 'Sharing...' : label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
