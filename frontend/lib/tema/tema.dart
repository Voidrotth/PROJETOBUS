import 'package:flutter/material.dart';
import 'cores.dart';
import 'espacamento.dart';
import 'tipografia.dart';

/// Tema do aplicativo montado com os tokens do design system.
ThemeData criarTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.primaria,
    primary: Cores.primaria,
    onPrimary: Colors.white,
    secondary: Cores.destaque,
    secondaryContainer: Cores.secundaria,
    surface: Cores.superficie,
    onSurface: Cores.texto,
    error: Cores.erro,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: esquema, fontFamily: Fontes.corpo);
  const cantos = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Esp.raio)));

  return base.copyWith(
    scaffoldBackgroundColor: Cores.fundo,
    textTheme: base.textTheme.apply(bodyColor: Cores.texto, displayColor: Cores.texto),
    dividerTheme: const DividerThemeData(color: Cores.borda, thickness: 1, space: 1),
    cardTheme: const CardThemeData(
      color: Cores.superficie,
      elevation: 2,
      shadowColor: Color(0x3324305F),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.superficie,
      foregroundColor: Cores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Cores.primaria,
        shape: cantos,
        textStyle: const TextStyle(fontFamily: Fontes.corpo, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.texto,
        side: const BorderSide(color: Cores.texto),
        shape: cantos,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: cantos)),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Cores.superficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(Esp.raio))),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Cores.borda),
        borderRadius: BorderRadius.all(Radius.circular(Esp.raio)),
      ),
    ),
  );
}
