import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'login_web.dart';

class EsqueciSenhaWeb extends StatefulWidget {
  @override
  _EsqueciSenhaWebState createState() => _EsqueciSenhaWebState();
}

class _EsqueciSenhaWebState extends State<EsqueciSenhaWeb> {
  final _cpf = TextEditingController();
  final _codigo = TextEditingController();
  final _novaSenha = TextEditingController();
  bool _loading = false;
  bool _codigoEnviado = false;

  Future<void> _solicitarCodigo() async {
    if (_cpf.text.isEmpty) return _msg("Aviso", "Informe o CPF.");
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/esqueci-senha"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cpf": _cpf.text.replaceAll(RegExp(r'\D'), '')}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() => _codigoEnviado = true);
        _msg("Verifique seu e-mail", data['mensagem'] ?? "Código enviado.");
      } else {
        _msg("Erro", data['erro'] ?? "CPF não encontrado.");
      }
    } catch (e) {
      _msg("Erro", "Falha ao conectar com o servidor.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redefinirSenha() async {
    if (_codigo.text.isEmpty || _novaSenha.text.isEmpty) return _msg("Aviso", "Preencha o código e a nova senha.");
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/redefinir-senha"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "cpf": _cpf.text.replaceAll(RegExp(r'\D'), ''),
          "codigo": _codigo.text,
          "nova_senha": _novaSenha.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _msg("Sucesso", "Senha redefinida! Faça login com a nova senha.");
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb()));
      } else {
        _msg("Erro", data['erro'] ?? "Código inválido.");
      }
    } catch (e) {
      _msg("Erro", "Falha ao conectar com o servidor.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String t, String m) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(t), content: Text(m),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(title: Text("Recuperar Senha"), backgroundColor: PolifenoisTema.azulPrimario),
      body: Center(
        child: Container(
          width: 400,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_reset, size: 50, color: PolifenoisTema.azulPrimario),
                  SizedBox(height: 20),
                  TextField(controller: _cpf, enabled: !_codigoEnviado, decoration: PolifenoisTema.inputDecoracao("CPF cadastrado", Icons.badge)),
                  SizedBox(height: 20),
                  if (!_codigoEnviado)
                    _loading ? CircularProgressIndicator() : ElevatedButton(
                      onPressed: _solicitarCodigo,
                      style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: PolifenoisTema.azulPrimario),
                      child: Text("ENVIAR CÓDIGO POR E-MAIL", style: TextStyle(color: Colors.white)),
                    ),
                  if (_codigoEnviado) ...[
                    TextField(controller: _codigo, decoration: PolifenoisTema.inputDecoracao("Código recebido", Icons.pin)),
                    SizedBox(height: 15),
                    TextField(controller: _novaSenha, obscureText: true, decoration: PolifenoisTema.inputDecoracao("Nova senha", Icons.lock)),
                    SizedBox(height: 20),
                    _loading ? CircularProgressIndicator() : ElevatedButton(
                      onPressed: _redefinirSenha,
                      style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.green),
                      child: Text("REDEFINIR SENHA", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}