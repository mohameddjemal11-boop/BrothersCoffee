import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _coffee = Color(0xFF6F4E37);
  static const _cream = Color(0xFFFFF8EF);
  static const _ink = Color(0xFF2A211C);
  static const _success = Color(0xFF2F7D57);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _coffee,
      brightness: Brightness.light,
      surface: _cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F3EE),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      extensions: const [AppStatusColors(success: _success)],
    );
  }
}

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({required this.success});

  final Color success;

  @override
  AppStatusColors copyWith({Color? success}) {
    return AppStatusColors(success: success ?? this.success);
  }

  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(success: Color.lerp(success, other.success, t)!);
  }
}
