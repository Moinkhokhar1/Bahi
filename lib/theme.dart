import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BahiColors {
  final Color paper, card, ink, muted, line, blue, blueInk, blueSoft, gold, goldInk, goldSoft,
      green, greenSoft, red, redSoft;
  const BahiColors({
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.blue,
    required this.blueInk,
    required this.blueSoft,
    required this.gold,
    required this.goldInk,
    required this.goldSoft,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
  });

  static const light = BahiColors(
    paper: Color(0xFFF2F4FA),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF131A35),
    muted: Color(0xFF5A6383),
    line: Color(0xFFDDE1EE),
    blue: Color(0xFF2743C4),
    blueInk: Color(0xFFFFFFFF),
    blueSoft: Color(0xFFE5E9FC),
    gold: Color(0xFFF3AB00),
    goldInk: Color(0xFF2B2000),
    goldSoft: Color(0xFFFFF1C9),
    green: Color(0xFF12805C),
    greenSoft: Color(0xFFDBF2E8),
    red: Color(0xFFC43636),
    redSoft: Color(0xFFFDE4E4),
  );

  static const dark = BahiColors(
    paper: Color(0xFF0E1120),
    card: Color(0xFF171B2F),
    ink: Color(0xFFE9ECFA),
    muted: Color(0xFF97A0C4),
    line: Color(0xFF293050),
    blue: Color(0xFF8196FF),
    blueInk: Color(0xFF0A0F2E),
    blueSoft: Color(0xFF232B59),
    gold: Color(0xFFF6B93B),
    goldInk: Color(0xFF2B2000),
    goldSoft: Color(0xFF3B3010),
    green: Color(0xFF4FD1A1),
    greenSoft: Color(0xFF12372C),
    red: Color(0xFFFF8080),
    redSoft: Color(0xFF3D1D24),
  );
}

extension BahiColorsX on BuildContext {
  BahiColors get bahi =>
      Theme.of(this).brightness == Brightness.dark ? BahiColors.dark : BahiColors.light;
}

ThemeData buildBahiTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? BahiColors.dark : BahiColors.light;
  final headingFont = GoogleFonts.bricolageGrotesque();
  final bodyFont = GoogleFonts.figtree();

  final base = ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: c.paper,
    primaryColor: c.blue,
    colorScheme: (brightness == Brightness.dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: c.blue,
      onPrimary: c.blueInk,
      secondary: c.gold,
      onSecondary: c.goldInk,
      surface: c.card,
      onSurface: c.ink,
      error: c.red,
    ),
    fontFamily: bodyFont.fontFamily,
    textTheme: GoogleFonts.figtreeTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: c.ink, displayColor: c.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: c.paper,
      foregroundColor: c.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: headingFont.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 21,
        color: c.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
    ),
    dividerColor: c.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.blue, width: 1.6),
      ),
      labelStyle: TextStyle(color: c.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.blue,
        foregroundColor: c.blueInk,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.line),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.blue),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? c.blue : c.card),
    ),
    useMaterial3: true,
  );
  return base;
}