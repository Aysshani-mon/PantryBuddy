import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.markSize = 400,
    this.showWordmark = true,
    this.wordmarkFontSize = 22,
    this.direction = Axis.vertical,
  });

  /// Size (width & height) of the icon mark.
  final double markSize;

  /// Kept for API compatibility with existing call sites — the wordmark
  /// was intentionally removed, so this no longer has any effect.
  final bool showWordmark;
  final double wordmarkFontSize;
  final Axis direction;

  /// Uses the tightly-cropped wordmark (no tagline or empty margins), so
  /// it no longer takes up a huge square of whitespace. [markSize] keeps
  /// its old meaning roughly: the logo is drawn a quarter of that tall.
  Widget _buildMark(BuildContext context) {
    return Image.asset('assets/images/logo_wordmark.png', height: markSize * 0.25);
  }

  @override
  Widget build(BuildContext context) {
    return _buildMark(context);
  }
}