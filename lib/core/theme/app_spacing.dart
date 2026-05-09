import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double pill = 20.0;
  static const double full = 999.0;
}

class AppTypography {
  AppTypography._();

  static const TextStyle brand = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3,
  );
  static const TextStyle h1 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const TextStyle h2 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle h3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
  static const TextStyle bodyLarge = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
  static const TextStyle caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const TextStyle small = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  static const TextStyle micro = TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
  static const TextStyle mini = TextStyle(fontSize: 10, fontWeight: FontWeight.w500);

  static const TextStyle label = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const TextStyle button = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const TextStyle buttonLarge = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
}
