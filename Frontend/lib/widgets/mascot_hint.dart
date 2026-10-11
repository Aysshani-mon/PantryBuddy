import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The PantrySentry mascot popping up with a short speech bubble that
/// points the user at a button ("Tap the (i) above for more info").
///
/// Only the ✕ in the bubble hides it. It pops back up the next time the
/// screen is shown: pushed screens (Recipes) get a fresh hint every time
/// they're opened, and the bottom-nav calls [MascotHint.showAgain] on
/// every tab change so Progress / Impact show it again too.
class MascotHint extends StatefulWidget {
  const MascotHint({super.key, required this.message});

  /// Bubble text — build it with [TextSpan]s and [MascotHint.icon] so the
  /// icon in the sentence looks exactly like the button it refers to.
  final InlineSpan message;

  static final ValueNotifier<int> _showAgain = ValueNotifier<int>(0);

  /// Re-show every hint that was closed (called on bottom-nav tab change).
  static void showAgain() => _showAgain.value++;

  /// An inline icon for the bubble text. [circled] draws the same outlined
  /// circle as the round header buttons (e.g. the info button).
  static InlineSpan icon(IconData icon, {bool circled = false}) {
    final glyph = Icon(icon, size: circled ? 14 : 16, color: AppTheme.ink);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: circled
            ? Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.ink.withValues(alpha: 0.4), width: 1.3),
                ),
                child: glyph,
              )
            : glyph,
      ),
    );
  }

  @override
  State<MascotHint> createState() => _MascotHintState();
}

class _MascotHintState extends State<MascotHint> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    MascotHint._showAgain.addListener(_reopen);
  }

  @override
  void dispose() {
    MascotHint._showAgain.removeListener(_reopen);
    super.dispose();
  }

  void _reopen() {
    if (mounted && _closed) setState(() => _closed = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _closed ? const SizedBox(width: double.infinity) : _buildHint(),
    );
  }

  Widget _buildHint() {
    // Rebuilt from scratch each time it reappears, so the pop-in plays again.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        alignment: Alignment.topRight,
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: AppTheme.paper,
                border: Border.all(color: AppTheme.ink, width: 1.5),
                // Square-ish bottom-right corner = the bubble's "tail",
                // pointing at the mascot.
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text.rich(
                      widget.message,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  // Only the ✕ closes the hint.
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => setState(() => _closed = true),
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.muted),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Mascot sits right under the button it's talking about.
          Image.asset('assets/images/mascot.png', width: 52, height: 52),
        ],
      ),
    );
  }
}
