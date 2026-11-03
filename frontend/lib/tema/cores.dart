import 'package:flutter/material.dart';

/// Tokens de cor: identidade do site da Prefeitura de São Caetano do Sul (azul-marinho e verde-água).
class Cores {
  Cores._();

  // Cores principais
  static const texto = Color(0xFF1B2447);
  /// Fundo cinza-azulado: os cards brancos se destacam (o branco puro cansava na TV)
  static const fundo = Color(0xFFDCE2EC);
  static const primaria = Color(0xFF24305F);
  static const secundaria = Color(0xFFD3D9EA);
  static const destaque = Color(0xFF49A292);
  /// Azul-marinho claro: segunda série dos gráficos que já usam a primária
  static const primariaClara = Color(0xFF8C97C2);

  /// Degradê primário: blue-500 -> green-500
  static const degradePrimario = LinearGradient(colors: [primaria, destaque]);

  // Superfícies e estados usados nas telas
  static const superficie = Colors.white;
  static const borda = white600;
  static const textoApagado = Color(0xFF655E7A);
  static const esqueleto = Color(0xFFDDDDDD);
  static const alerta = Color(0xFFE0A100);
  static const erro = Color(0xFFD03B3B);
  static const vermelho50 = Color(0xFFFBEAEA);

  // Black
  static const black50 = Color(0xFFE7E8E9);
  static const black100 = Color(0xFFB5B7BA);
  static const black200 = Color(0xFF919498);
  static const black300 = Color(0xFF5F646A);
  static const black400 = Color(0xFF40454D);
  static const black500 = Color(0xFF101720);
  static const black600 = Color(0xFF0F151D);
  static const black700 = Color(0xFF0B1017);
  static const black800 = Color(0xFF090D12);
  static const black900 = Color(0xFF070A0D);

  // White
  static const white50 = Color(0xFFFEFEFE);
  static const white100 = Color(0xFFFCFCFC);
  static const white200 = Color(0xFFFAFAFA);
  static const white300 = Color(0xFFF8F8F8);
  static const white400 = Color(0xFFF7F7F7);
  static const white500 = Color(0xFFF5F5F5);
  static const white600 = Color(0xFFDFDFDF);
  static const white700 = Color(0xFFAEAEAE);
  static const white800 = Color(0xFF878787);
  static const white900 = Color(0xFF676767);

  // Blue
  static const blue50 = Color(0xFFE8EFF7);
  static const blue100 = Color(0xFFB8CEE5);
  static const blue200 = Color(0xFF96B7D9);
  static const blue300 = Color(0xFF6696C7);
  static const blue400 = Color(0xFF4881BD);
  static const blue500 = Color(0xFF1A62AC);
  static const blue600 = Color(0xFF18599D);
  static const blue700 = Color(0xFF12467A);
  static const blue800 = Color(0xFF0E365F);
  static const blue900 = Color(0xFF0B2948);

  // Blue-light
  static const blueLight50 = Color(0xFFFBFDFF);
  static const blueLight100 = Color(0xFFF3F8FF);
  static const blueLight200 = Color(0xFFEDF5FF);
  static const blueLight300 = Color(0xFFE4F1FF);
  static const blueLight400 = Color(0xFFDFEEFF);
  static const blueLight500 = Color(0xFFD7EAFF);
  static const blueLight600 = Color(0xFFC4D5E8);
  static const blueLight700 = Color(0xFF99A6B5);
  static const blueLight800 = Color(0xFF76818C);
  static const blueLight900 = Color(0xFF5A626B);

  // Green
  static const green50 = Color(0xFFE6F9EF);
  static const green100 = Color(0xFFB2EBCE);
  static const green200 = Color(0xFF8DE1B7);
  static const green300 = Color(0xFF5AD396);
  static const green400 = Color(0xFF39CB81);
  static const green500 = Color(0xFF08BE62);
  static const green600 = Color(0xFF07AD59);
  static const green700 = Color(0xFF068746);
  static const green800 = Color(0xFF046936);
  static const green900 = Color(0xFF035029);
}
