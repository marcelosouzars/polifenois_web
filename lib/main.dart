import 'package:flutter/material.dart';
import 'cadastro_usuario_web.dart'; // Importa a tela de cadastro separada 

void main() {
  runApp(MaterialApp(
    title: 'Vetix Polifenóis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    // Definimos a tela de Cadastro como a tela inicial [cite: 1364]
    home: CadastroUsuarioWeb(), 
  ));
}