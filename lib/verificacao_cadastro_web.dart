import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart'; // Importante para o formatters
import 'tema_padrao_web.dart';

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
    if (_codigoController.text.length < 6) {
      _mostrarAlerta("Aviso", "O código deve ter 6 dígitos.");
      return;
    }

    setState(() => _carregando = true);
    try {
      // URL DIRETA DO RENDER (Sem localhost!)
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
        _mostrarAlerta("Sucesso!", "Sua conta foi validada. Agora você pode fazer login.");
      } else {
        _mostrarAlerta("Erro", result['erro'] ?? "Código inválido.");
      }
    } catch (e) {
      _mostrarAlerta("Erro de Conexão", "Não foi possível alcançar o servidor no Render.");
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
      backgroundColor: PolifenoisTema.azulClaroFundo,
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
                  Icon(Icons.security, size: 60, color: PolifenoisTema.azulPrimario),
                  SizedBox(height: 20),
                  Text("Validação", style: PolifenoisTema.tituloEstilo),
                  SizedBox(height: 10),
                  Text("Digite o código enviado para:\n${widget.email}", 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  SizedBox(height: 30),
                  TextField(
                    controller: _codigoController,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10),
                    decoration: PolifenoisTema.inputDecoracao("CÓDIGO", Icons.vpn_key),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  ),
                  SizedBox(height: 30),
                  _carregando 
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _validarCodigo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PolifenoisTema.azulPrimario,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("VALIDAR CONTA", style: TextStyle(fontWeight: FontWeight.bold)),
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