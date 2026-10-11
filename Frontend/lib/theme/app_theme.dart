import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PantrySentry design tokens (Iteration 3 UI refresh).
///
/// Look: deep forest-green headers on a warm cream canvas, with cards that
/// have a crisp dark outline and a small solid "ledge" underneath (see
/// [LedgeBorder]) so they read as solid, tappable objects. Headings use
/// Fraunces (a warm serif), everything else Figtree (a clean sans). Both
/// fonts are bundled in assets/fonts, so nothing loads from the network.
///
/// The original token names (seedColor, basilLight, paprika, honey, ocean,
/// ink, ...) are kept so every existing screen picks up the new palette
/// without code changes.
class AppTheme {
  // ---- Fonts -----------------------------------------------------------
  static const displayFont = 'Fraunces';
  static const bodyFont = 'Figtree';

  // ---- Brand palette ---------------------------------------------------
  /// Header / hero background — a blend of the two greens in the logo.
  static const forest = Color(0xFF1F6527);

  /// Primary green (the logo's leaf green): buttons, links, selected states.
  static const seedColor = Color(0xFF2F7F28);
  static const basilLight = Color(0xFFE3F0DA);

  /// Waste / danger.
  static const paprika = Color(0xFFC9472F);
  static const paprikaLight = Color(0xFFF8E3DC);

  /// "Expiring soon" / caution text colour.
  static const honey = Color(0xFFB7791F);
  static const honeyLight = Color(0xFFFCEFD2);

  /// Warm accent for a few key actions (Add item, recipe ideas, FAB).
  static const saffron = Color(0xFFF2B84B);

  /// Cold storage / informational.
  static const ocean = Color(0xFF2C6E7F);
  static const oceanLight = Color(0xFFDDEBEE);

  /// Text and outlines — a very dark green rather than black.
  static const ink = Color(0xFF17301F);

  /// Secondary text.
  static const muted = Color(0xFF5C6B60);

  /// App canvas (warm cream) and card surface (off-white).
  static const backgroundColor = Color(0xFFF8F2E6);
  static const paper = Color(0xFFFFFDF8);

  /// Track behind segmented controls / tabs.
  static const sand = Color(0xFFEEE4CF);

  /// Input borders.
  static const borderColor = Color(0xFFB9AE95);

  /// Hairlines and dividers.
  static const lineColor = Color(0xFFD9CCB0);

  /// Light text on [forest] backgrounds.
  static const onForest = Color(0xFFF8F2E6);
  static const onForestMuted = Color(0xFFD6EAD1);

  /// Small uppercase labels on [forest] backgrounds.
  static const onForestKicker = Color(0xFFBFDDB8);

  // ---- Reusable styles ---------------------------------------------------
  /// Headline stat numbers (counts, litres, kg) — serif, tabular figures.
  static const TextStyle statNumberStyle = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Small uppercase label ("HOUSEHOLD", "CONSUMED").
  static const TextStyle kicker = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: muted,
  );

  /// Outlined panel with the small solid ledge underneath — the same look
  /// as [Card]s, for hand-built containers.
  static BoxDecoration panel({Color color = paper, double radius = 18}) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ink, width: 1.5),
        boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 3))],
      );

  /// A "hero" card — solid colour fill — for the headline content on a
  /// screen. Same outline + ledge as [panel].
  static BoxDecoration heroFill(Color color) => panel(color: color, radius: 22);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor).copyWith(
      primary: seedColor,
      onPrimary: Colors.white,
      primaryContainer: basilLight,
      onPrimaryContainer: forest,
      secondary: saffron,
      onSecondary: ink,
      secondaryContainer: honeyLight,
      onSecondaryContainer: ink,
      tertiary: honey,
      error: paprika,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFBF7EE),
      surfaceContainer: const Color(0xFFF6EFDF),
      surfaceContainerHigh: sand,
      surfaceContainerHighest: const Color(0xFFE8DCC2),
      outline: borderColor,
      outlineVariant: lineColor,
      surfaceTint: Colors.transparent,
    );

    const display = TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w600, color: ink);
    final base = ThemeData(useMaterial3: true, fontFamily: bodyFont).textTheme;
    final textTheme = base.copyWith(
      displayLarge: base.displayLarge?.merge(display),
      displayMedium: base.displayMedium?.merge(display),
      displaySmall: base.displaySmall?.merge(display),
      headlineLarge: base.headlineLarge?.merge(display),
      headlineMedium: base.headlineMedium?.merge(display),
      headlineSmall: base.headlineSmall?.merge(display).copyWith(fontSize: 26, letterSpacing: -0.3, height: 1.15),
      titleLarge: base.titleLarge?.merge(display).copyWith(fontSize: 21, letterSpacing: -0.2),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: ink),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: ink),
      bodyLarge: base.bodyLarge?.copyWith(color: ink),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.4, color: ink.withValues(alpha: 0.82)),
      bodySmall: base.bodySmall?.copyWith(color: muted),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    final roundedInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borderColor, width: 1.5),
    );

    // Primary buttons: green fill, dark outline + ledge. Disabled buttons
    // drop to sand with a soft outline so they clearly look inactive.
    final primaryButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? sand : seedColor),
      foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? muted : Colors.white),
      overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.12)),
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 14, 20, 17)),
      minimumSize: WidgetStateProperty.all(const Size(64, 50)),
      textStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 16)),
      side: WidgetStateProperty.resolveWith((s) => BorderSide(
          color: s.contains(WidgetState.disabled) ? lineColor : ink, width: 1.5)),
      shape: WidgetStateProperty.all(const LedgeBorder(radius: 14)),
    );

    // Note: no `fontFamily:` here on purpose — ThemeData would apply it on
    // top of textTheme and replace Fraunces on the headings. Figtree comes
    // from `base` above instead.
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: forest,
        foregroundColor: onForest,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 64,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w600,
          fontSize: 23,
          letterSpacing: -0.2,
          color: onForest,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: paper,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: LedgeBorder(radius: 18),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: roundedInput,
        enabledBorder: roundedInput,
        focusedBorder: roundedInput.copyWith(borderSide: const BorderSide(color: seedColor, width: 2)),
        errorBorder: roundedInput.copyWith(borderSide: const BorderSide(color: paprika, width: 1.8)),
        focusedErrorBorder: roundedInput.copyWith(borderSide: const BorderSide(color: paprika, width: 2)),
        hintStyle: const TextStyle(color: Color(0xFF8A948C), fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: seedColor, fontWeight: FontWeight.w700),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: ink, width: 1.5),
          textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seedColor,
          textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: saffron,
        foregroundColor: ink,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        shape: LedgeBorder(radius: 18),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? seedColor : sand),
        labelStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: WidgetStateColor.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.white : ink),
        ),
        checkmarkColor: Colors.white,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? forest : sand),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? onForest : muted),
          side: WidgetStateProperty.all(const BorderSide(color: sand, width: 1)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
          textStyle: WidgetStateProperty.all(
              const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 14)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: forest,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: bodyFont,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? forest : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? onForest : muted, size: 22);
        }),
      ),
      // Tabs sit on a sand "track" (see BrandTabTrack) with the selected
      // tab as a forest pill.
      tabBarTheme: TabBarThemeData(
        labelColor: onForest,
        unselectedLabelColor: muted,
        labelStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 14),
        indicator: BoxDecoration(color: forest, borderRadius: BorderRadius.circular(11)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: ink, width: 1.5),
        ),
        titleTextStyle: const TextStyle(
            fontFamily: displayFont, fontWeight: FontWeight.w600, fontSize: 21, color: ink),
        contentTextStyle: TextStyle(fontFamily: bodyFont, fontSize: 14.5, height: 1.4, color: ink.withValues(alpha: 0.85)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: lineColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lineColor),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: forest,
        actionTextColor: saffron,
        contentTextStyle: const TextStyle(fontFamily: bodyFont, color: onForest, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: seedColor,
        linearTrackColor: sand,
      ),
      dividerTheme: const DividerThemeData(color: lineColor, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: seedColor,
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),
    );
  }
}

/// Rounded outline with a thicker bottom edge, so a card or button looks
/// like a solid object sitting on the page. Painted inside the shape's
/// bounds, so it works with clipping and in lists without extra spacing.
class LedgeBorder extends OutlinedBorder {
  const LedgeBorder({
    super.side = const BorderSide(color: AppTheme.ink, width: 1.5),
    this.radius = 18,
    this.ledge = 3,
  });

  final double radius;

  /// Extra thickness of the bottom edge, on top of [side]'s width.
  final double ledge;

  RRect _outer(Rect rect) => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  RRect _inner(Rect rect) {
    final w = side.style == BorderStyle.none ? 0.0 : side.width;
    final bottom = w + (side.style == BorderStyle.none ? 0.0 : ledge);
    final inner = Rect.fromLTRB(
      rect.left + w,
      rect.top + w,
      math.max(rect.left + w, rect.right - w),
      math.max(rect.top + w, rect.bottom - bottom),
    );
    return RRect.fromRectAndRadius(inner, Radius.circular(math.max(0, radius - w)));
  }

  @override
  EdgeInsetsGeometry get dimensions {
    if (side.style == BorderStyle.none) return EdgeInsets.zero;
    return EdgeInsets.fromLTRB(side.width, side.width, side.width, side.width + ledge);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_inner(rect));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_outer(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    if (rect.height <= side.width * 2 + ledge || rect.width <= side.width * 2) return;
    canvas.drawDRRect(_outer(rect), _inner(rect), Paint()..color = side.color);
  }

  @override
  ShapeBorder scale(double t) => LedgeBorder(side: side.scale(t), radius: radius * t, ledge: ledge * t);

  @override
  LedgeBorder copyWith({BorderSide? side, double? radius, double? ledge}) => LedgeBorder(
        side: side ?? this.side,
        radius: radius ?? this.radius,
        ledge: ledge ?? this.ledge,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is LedgeBorder) {
      return LedgeBorder(
        side: BorderSide.lerp(a.side, side, t),
        radius: a.radius + (radius - a.radius) * t,
        ledge: a.ledge + (ledge - a.ledge) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is LedgeBorder) {
      return LedgeBorder(
        side: BorderSide.lerp(side, b.side, t),
        radius: radius + (b.radius - radius) * t,
        ledge: ledge + (b.ledge - ledge) * t,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is LedgeBorder && other.side == side && other.radius == radius && other.ledge == ledge;

  @override
  int get hashCode => Object.hash(side, radius, ledge);
}

/// Days-left -> colour, used consistently across item cards / lists.
Color urgencyColor(int daysLeft) {
  if (daysLeft < 0) return const Color(0xFF8E2E1E); // overdue
  if (daysLeft <= 1) return AppTheme.paprika;
  if (daysLeft <= 3) return const Color(0xFFC0602A);
  if (daysLeft <= 7) return AppTheme.honey;
  return AppTheme.seedColor;
}

/// Soft background to pair with [urgencyColor] (status pills).
Color urgencyFill(int daysLeft) {
  if (daysLeft < 0) return const Color(0xFF8E2E1E);
  if (daysLeft <= 1) return AppTheme.paprikaLight;
  if (daysLeft <= 7) return AppTheme.honeyLight;
  return AppTheme.basilLight;
}
