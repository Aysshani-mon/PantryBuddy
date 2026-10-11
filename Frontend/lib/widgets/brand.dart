import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Forest-green header for top-level tabs that don't use an [AppBar]
/// (Progress, Impact). Matches the AppBar style: rounded bottom corners,
/// serif title, light text. Handles the status-bar inset itself, so the
/// screen shouldn't wrap it in a SafeArea.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing, this.bottom});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Optional extra content under the title row (e.g. a MascotHint).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // Light status-bar icons over the dark header (phones).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, top + 18, 16, 20),
        decoration: const BoxDecoration(
          color: AppTheme.forest,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 26,
                          letterSpacing: -0.3,
                          color: AppTheme.onForest,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(color: AppTheme.onForestMuted, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            if (bottom != null) Padding(padding: const EdgeInsets.only(top: 8), child: bottom),
          ],
        ),
      ),
    );
  }
}

/// Round outlined icon button for use on the forest header.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.onForest,
        minimumSize: const Size(42, 42),
        shape: CircleBorder(side: BorderSide(color: AppTheme.onForest.withValues(alpha: 0.35), width: 1.5)),
      ),
    );
  }
}

/// Serif section title with an optional count, subtitle and "View all"
/// style action on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.count,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int? count;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title + count take all the free space, so the action always
            // sits flush right whatever the title length.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 21,
                        letterSpacing: -0.2,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.muted)),
                  ],
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
      ],
    );
  }
}

/// Small rounded status label ("2 days", "Due today", "Donated").
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, required this.fill});

  final String label;

  /// Text colour.
  final Color color;

  /// Background colour.
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Outlined rounded-square badge holding an icon — used at the start of
/// list cards (storage location, recipe, etc.).
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.fill, this.iconColor = AppTheme.ink, this.size = 44});

  final IconData icon;
  final Color fill;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppTheme.ink, width: 1.5),
      ),
      child: Icon(icon, size: size * 0.48, color: iconColor),
    );
  }
}

/// Sand-coloured track that a [TabBar] sits in, so the selected tab shows
/// as a forest pill (see tabBarTheme in AppTheme).
class BrandTabTrack extends StatelessWidget {
  const BrandTabTrack({super.key, required this.child, this.margin = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.sand, borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}
