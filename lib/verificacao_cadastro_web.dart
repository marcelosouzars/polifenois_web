import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'login_web.dart'; // Import necessário para o redirecionamento

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
        _mostrarAlertaComNavegacao("Sucesso!", "Sua conta foi validada com sucesso. Faça seu login para acessar a plataforma.");
      } else {
        _mostrarAlerta("Erro", result['erro'] ?? "Código inválido.");
      }
    } catch (e) {
      _mostrarAlerta("Erro", "Falha ao conectar com o servidor.");
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

  // Nova função que redireciona para o login após o sucesso
  void _mostrarAlertaComNavegacao(String t, String m) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obriga o usuário a clicar no botão
      builder: (c) => AlertDialog(
        title: Text(t, style: TextStyle(color: Colors.green)),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c); // Fecha o alert
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginWeb()),
                (Route<dynamic> route) => false, // Limpa o histórico de navegação
              );
            },
            child: Text("IR PARA LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
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
                  Icon(Icons.mark_email_read_outlined, size: 60, color: PolifenoisTema.azulPrimario),
                  SizedBox(height: 20),
                  Text("Validar Cadastro", style: PolifenoisTema.tituloEstilo),
                  SizedBox(height: 10),
                  Text("Digite o código de 6 dígitos enviado para você.",
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                  SizedBox(height: 30),
                  TextField(
                    controller: _codigoController,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: PolifenoisTema.inputDecoracao("Código", Icons.lock_clock),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 30),
                  _carregando
                  ? CircularProgressIndicator(color: PolifenoisTema.azulPrimario)
                  : ElevatedButton(
                      onPressed: _validarCodigo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PolifenoisTema.azulPrimario,
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