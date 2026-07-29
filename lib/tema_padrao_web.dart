//
// TEMA_PADRAO_WEB.DART
//
import 'package:flutter/material.dart';

class PolifenoisTema {
  // Cores Principais
  static const Color azulPrimario = Color(0xFF1A5276); // Azul Profundo Executivo
  static const Color azulClaroFundo = Color(0xFFF0F4F8); // Azul muito claro para o fundo
  static const Color cinzaTexto = Color(0xFF455A64); // Cinza azulado para leitura
  static const Color brancoCard = Colors.white;
  static const Color azulDestaque = Color(0xFF2980B9); // Para links e cliques

  // Estilo de Texto
  static TextStyle tituloEstilo = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: azulPrimario,
    fontFamily: 'Roboto',
  );

  static TextStyle corpoEstilo = TextStyle(
    fontSize: 16,
    color: cinzaTexto,
  );

  // Decoração de Campos (Inputs)
  static InputDecoration inputDecoracao(String rotulo, IconData icone) {
    return InputDecoration(
      labelText: rotulo,
      prefixIcon: Icon(icone, color: azulPrimario),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade50),
      ),
    );
  }
}
