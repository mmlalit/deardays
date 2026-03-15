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
      style: CardStyle.minimal,
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
    final photos = widget.entry.media.where((m) => m.mediaType == 'photo').toList();
    if (photos.isEmpty) return null;
    return photos.first.storagePath;
  }

  String _generateFallbackSummary() {
    final text = widget.entry.polishedContent ?? widget.entry.content;
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final twoSentences = sentences.take(2).join(' ').trim();
    if (twoSentences.length <= 140) return twoSentences;
    return '${twoSentences.substring(0, 137)}...';
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
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  void _onCaptionChanged() {
    setState(() => _config = _config.copyWith(displayText: _captionController.text));
  }

  void _selectPlatform(SharePlatform platform) {
    HapticFeedback.lightImpact();
    setState(() => _config = _config.copyWith(platform: platform));
  }

  void _selectStyle(CardStyle style) {
    HapticFeedback.lightImpact();
    setState(() => _config = _config.copyWith(style: style));
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 120));
      final bytes = await ShareCardRenderer.renderToPng(_repaintKey);

      if (!ShareCardRenderer.supportsNativeShare) {
        final path = await ShareCardRenderer.saveToGallery(bytes);
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image saved & path copied:\n$path')),
          );
        }
      } else {
        final dateStr = DateFormat('MMMM d, yyyy').format(widget.entry.entryDate);
        await ShareCardRenderer.shareImage(bytes, subject: 'DearDays — $dateStr');
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
      await Future.delayed(const Duration(milliseconds: 120));
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
                    _buildPlatformTabs(colors),
                    const SizedBox(height: 20),
                    Center(child: _buildPreviewArea(colors)),
                    const SizedBox(height: 24),
                    _buildCaptionSection(colors),
                    const SizedBox(height: 20),
                    _buildStyleSelector(colors),
                    const SizedBox(height: 20),
                    _buildToggleChips(colors),
                    const SizedBox(height: 28),
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
              child: Icon(Icons.close_rounded, size: 24, color: colors.textPrimary),
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

  // ─── Platform tabs ────────────────────────────────────────────────────────

  Widget _buildPlatformTabs(AppPalette colors) {
    return Row(
      children: SharePlatform.values.map((platform) {
        final isActive = _config.platform == platform;
        return Expanded(
          child: GestureDetector(
            onTap: () => _selectPlatform(platform),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    platform.icon,
                    size: 18,
                    color: isActive ? colors.accent : colors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _platformShortLabel(platform),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? colors.accent : colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _platformShortLabel(SharePlatform platform) {
    switch (platform) {
      case SharePlatform.instagram:
        return 'Instagram\nStory';
      case SharePlatform.whatsapp:
        return 'WhatsApp\nStatus';
      case SharePlatform.memoryCard:
        return 'Memory\nCard';
    }
  }

  // ─── Preview area — platform-specific chrome ──────────────────────────────

  Widget _buildPreviewArea(AppPalette colors) {
    switch (_config.platform) {
      case SharePlatform.instagram:
        return _buildIGMockup(colors);
      case SharePlatform.whatsapp:
        return _buildWAMockup(colors);
      case SharePlatform.memoryCard:
        return _buildMemoryCardFrame(colors);
    }
  }

  // Instagram Story phone chrome
  Widget _buildIGMockup(AppPalette colors) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // IG story header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(180), width: 2),
                    color: Colors.white.withAlpha(30),
                  ),
                  child: Icon(Icons.person, size: 16, color: Colors.white.withAlpha(180)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Story',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Just now',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        color: Colors.white.withAlpha(140),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.more_horiz, size: 18, color: Colors.white.withAlpha(180)),
              ],
            ),
          ),

          // Story card (full-width, no padding)
          ClipRect(
            child: ShareCardPreview(
              config: _config,
              entry: widget.entry,
              repaintKey: _repaintKey,
            ),
          ),

          // IG footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Icon(Icons.camera_alt_outlined, size: 20, color: Colors.white.withAlpha(180)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha(70)),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Send message',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.white.withAlpha(110),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.favorite_border_rounded, size: 20, color: Colors.white.withAlpha(180)),
                const SizedBox(width: 10),
                Icon(Icons.send_outlined, size: 18, color: Colors.white.withAlpha(180)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WhatsApp Status chrome
  Widget _buildWAMockup(AppPalette colors) {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: const Color(0xFFECE5DD),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WA header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF075E54),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 18, color: Colors.white.withAlpha(200)),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(40),
                  ),
                  child: Icon(Icons.person, size: 16, color: Colors.white.withAlpha(200)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friend',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'online',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.videocam_outlined, size: 20, color: Colors.white.withAlpha(200)),
                const SizedBox(width: 14),
                Icon(Icons.call_outlined, size: 18, color: Colors.white.withAlpha(200)),
              ],
            ),
          ),

          // Status card (with padding)
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ShareCardPreview(
                config: _config,
                entry: widget.entry,
                repaintKey: _repaintKey,
              ),
            ),
          ),

          // WA footer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.emoji_emotions_outlined, size: 20, color: const Color(0xFF8696A0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Type a message',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF8696A0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.mic, size: 20, color: const Color(0xFF8696A0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Memory Card — print-style frame
  Widget _buildMemoryCardFrame(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(20),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ShareCardPreview(
              config: _config,
              entry: widget.entry,
              repaintKey: _repaintKey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Memory Card  ·  4:5',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
              letterSpacing: 0.5,
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
          'CAPTION',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            letterSpacing: 1.2,
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
                  maxLines: 4,
                  minLines: 2,
                  style: GoogleFonts.newsreader(
                    fontSize: 15,
                    color: colors.textPrimary,
                    height: 1.55,
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
                const Text('✨', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  _isLoadingAi ? 'Generating...' : 'Regenerate with AI',
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
            height: 13,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 13,
            width: 180,
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
          'STYLE',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: CardStyle.values.map((style) {
            final isActive = _config.style == style;
            return Expanded(
              child: GestureDetector(
                onTap: () => _selectStyle(style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                      _buildStyleThumb(style, isActive),
                      const SizedBox(height: 6),
                      Text(
                        _styleName(style),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? colors.accent : colors.textSecondary,
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

  Widget _buildStyleThumb(CardStyle style, bool isActive) {
    const double size = 28;
    switch (style) {
      case CardStyle.minimal:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1410),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Container(width: 14, height: 1.5, color: Colors.white.withAlpha(140)),
          ),
        );
      case CardStyle.scrapbook:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFF2EAD8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFC49A6C), width: 1.5),
          ),
          child: const Center(
            child: Text('📎', style: TextStyle(fontSize: 12)),
          ),
        );
      case CardStyle.dark:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Container(width: 14, height: 1.5, color: const Color(0xFFD4AF37).withAlpha(180)),
          ),
        );
      case CardStyle.classic:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 2, color: const Color(0xFFCCCCCC)),
                      const SizedBox(height: 3),
                      Container(height: 2, width: 14, color: const Color(0xFFE0E0E0)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  String _styleName(CardStyle style) {
    switch (style) {
      case CardStyle.minimal:
        return 'Minimal';
      case CardStyle.scrapbook:
        return 'Scrapbook';
      case CardStyle.dark:
        return 'Dark';
      case CardStyle.classic:
        return 'Classic';
    }
  }

  // ─── Toggle chips ─────────────────────────────────────────────────────────

  Widget _buildToggleChips(AppPalette colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip('Date', _config.showDate, colors, (v) {
          setState(() => _config = _config.copyWith(showDate: v));
        }),
        _buildChip('Mood', _config.showMood, colors, (v) {
          setState(() => _config = _config.copyWith(showMood: v));
        }),
        if (widget.entry.locationName != null)
          _buildChip('Location', _config.showLocation, colors, (v) {
            setState(() => _config = _config.copyWith(showLocation: v));
          }),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.accentFaint : colors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? colors.accent : colors.border),
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
    return Column(
      children: [
        // Primary share button — platform-aware
        SizedBox(
          width: double.infinity,
          height: 54,
          child: GestureDetector(
            onTap: (_isSharing || _isSaving) ? null : _share,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _platformGradient(_config.platform),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _platformGradient(_config.platform).first.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSharing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    Icon(_config.platform.icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    _isSharing
                        ? 'Sharing...'
                        : 'Share to ${_platformShareLabel(_config.platform)}',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary: save image
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: (_isSharing || _isSaving) ? null : _saveToGallery,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
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

  List<Color> _platformGradient(SharePlatform platform) {
    switch (platform) {
      case SharePlatform.instagram:
        return const [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)];
      case SharePlatform.whatsapp:
        return const [Color(0xFF25D366), Color(0xFF128C7E)];
      case SharePlatform.memoryCard:
        return const [Color(0xFF4B7CF3), Color(0xFF7C3AED)];
    }
  }

  String _platformShareLabel(SharePlatform platform) {
    switch (platform) {
      case SharePlatform.instagram:
        return 'Instagram';
      case SharePlatform.whatsapp:
        return 'WhatsApp';
      case SharePlatform.memoryCard:
        return 'Share';
    }
  }
}
