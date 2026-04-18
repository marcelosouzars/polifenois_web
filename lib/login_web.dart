import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'cadastro_usuario_web.dart';
import 'dashboard_admin_web.dart'; 

class LoginWeb extends StatefulWidget {
  @override
  _LoginWebState createState() => _LoginWebState();
}

class _LoginWebState extends State<LoginWeb> {
  final _cpf = TextEditingController();
  final _senha = TextEditingController();
  bool _loading = false;

  Future<void> _entrar() async {
    if (_cpf.text.isEmpty || _senha.text.isEmpty) {
      _msg("Aviso", "Preencha CPF e Senha.");
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "cpf": _cpf.text.replaceAll(RegExp(r'\D'), ''),
          "senha": _senha.text
        }),
      );

      final res = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Trava de segurança: Se vier nulo, assume 'gestante'
        String tipo = res['usuario']['tipo_usuario'] ?? 'gestante';

        if (tipo == 'admin' || tipo == 'medico') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardAdminWeb(usuario: res['usuario'])),
          );
        } else {
          _msg("Sucesso", "Bem-vinda, ${res['usuario']['nome'] ?? 'Paciente'}! Área da paciente em construção.");
        }
      } else {
        _msg("Erro", res['erro'] ?? "Falha no login. Verifique seus dados.");
      }
    } catch (e) {
      _msg("Erro de Conexão", "Falha ao conectar com o servidor Render. Verifique sua internet.");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _msg(String t, String m) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t, style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      body: Center(
        child: Container(
          width: 400,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_hospital, size: 60, color: PolifenoisTema.azulPrimario),
                  SizedBox(height: 15),
                  Text("Acesso Polifenóis", style: PolifenoisTema.tituloEstilo),
                  SizedBox(height: 30),
                  TextField(controller: _cpf, decoration: PolifenoisTema.inputDecoracao("CPF", Icons.badge)),
                  SizedBox(height: 15),
                  TextField(controller: _senha, obscureText: true, decoration: PolifenoisTema.inputDecoracao("Senha", Icons.key)),
                  SizedBox(height: 30),
                  _loading
                      ? CircularProgressIndicator(color: PolifenoisTema.azulPrimario)
                      : ElevatedButton(
                          onPressed: _entrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PolifenoisTema.azulPrimario,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CadastroUsuarioWeb())),
                    child: Text("Não tem conta? Cadastre-se aqui", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}