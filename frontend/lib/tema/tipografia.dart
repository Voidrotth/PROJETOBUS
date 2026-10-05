import 'package:flutter/material.dart';
import 'cores.dart';

/// Famílias do design system: Fjalla One (títulos e números), Inter (texto) e Space Mono (tags).
class Fontes {
  Fontes._();

  static const titulo = 'FjallaOne';
  static const corpo = 'Inter';
  static const tag = 'SpaceMono';
}

/// Escala tipográfica: base 16, razão 1,414 (128, 90, 64, 45, 32, 23, 16, 11, 8).
class Tamanhos {
  Tamanhos._();

  static const t128 = 128.0;
  static const t90 = 90.0;
  static const t64 = 64.0;
  static const t45 = 45.0;
  static const t32 = 32.0;
  static const t23 = 23.0;
  static const t16 = 16.0;
  static const t11 = 11.0;
  static const t8 = 8.0;
}

/// Estilos prontos usados nas telas.
class Estilos {
  Estilos._();

  static const tituloPagina = TextStyle(fontFamily: Fontes.corpo, fontSize: Tamanhos.t23, color: Cores.texto);
  static const tituloCartao =
      TextStyle(fontFamily: Fontes.corpo, fontSize: Tamanhos.t16, fontWeight: FontWeight.w500, color: Cores.texto);
  static const valor = TextStyle(fontFamily: Fontes.titulo, fontSize: Tamanhos.t32, height: 1.2, color: Cores.texto);
  static const valorGrande = TextStyle(fontFamily: Fontes.titulo, fontSize: Tamanhos.t45, height: 1.1, color: Cores.texto);
  static const corpo = TextStyle(fontFamily: Fontes.corpo, fontSize: Tamanhos.t16, color: Cores.texto);
  static const pequeno = TextStyle(fontFamily: Fontes.corpo, fontSize: 13, color: Cores.textoApagado);
  static const tag = TextStyle(fontFamily: Fontes.tag, fontSize: Tamanhos.t11, color: Cores.textoApagado);
}
