import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart'; // [cite: 2691, 2796]

class VerificacaoCadastroWeb extends StatefulWidget {
  final String email;
  VerificacaoCadastroWeb({required this.email});

  @override
  _VerificacaoCadastroWebState createState() => _VerificacaoCadastroWebState();
}

class _VerificacaoCadastroWebState extends State<VerificacaoCadastroWeb> {
  final _codigoController = TextEditingController();
  bool _carregando = false;

  Future<void> _validarCodigo() async {
    setState(() => _carregando = true);
    try {
      // URL real do seu backend no Render [cite: 3044]
      final url = Uri.parse("https://polifenois-backend.onrender.com/verificar-codigo");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "codigo": _codigoController.text,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['sucesso']) {
        _mostrarAlerta("Sucesso!", "Sua conta foi validada. Agora você pode fazer login."); [cite: 3055]
      } else {
        _mostrarAlerta("Erro", result['erro'] ?? "Código inválido."); [cite: 3057]
      }
    } catch (e) {
      _mostrarAlerta("Erro", "Falha ao conectar com o servidor."); [cite: 3060]
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _mostrarAlerta(String t, String m) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t, style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo, [cite: 2652, 2703]
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(32),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 60, color: PolifenoisTema.azulPrimario), [cite: 3091]
                  SizedBox(height: 20),
                  Text("Validar Cadastro", style: PolifenoisTema.tituloEstilo), [cite: 3093]
                  SizedBox(height: 10),
                  Text("Digite o código de 6 dígitos enviado para você.",
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])), [cite: 3095]
                  SizedBox(height: 30),
                  TextField(
                    controller: _codigoController,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: PolifenoisTema.inputDecoracao("Código", Icons.lock_clock), [cite: 3102]
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 30),
                  _carregando
                  ? CircularProgressIndicator(color: PolifenoisTema.azulPrimario)
                  : ElevatedButton(
                      onPressed: _validarCodigo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PolifenoisTema.azulPrimario, [cite: 2751]
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("CONFIRMAR CÓDIGO", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}