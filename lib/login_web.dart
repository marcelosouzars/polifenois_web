//
// LOGIN_WEB.DART
//
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'tema_padrao_web.dart';
import 'cadastro_usuario_web.dart';
import 'dashboard_admin_web.dart';
import 'cadastro_gestante_web.dart';
import 'dashboard_master_web.dart'; // Import do novo Dashboard Master
import 'esqueci_senha_web.dart'; // NOVO: fluxo de recuperação de senha

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
        String tipo = res['usuario']['tipo_usuario'] ?? 'gestante';

        // --- NOVA LÓGICA DE ROTEAMENTO SÓCIO MARCELO ---
        if (tipo == 'master') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardMasterWeb(usuario: res['usuario']))
          );
        } else if (tipo == 'admin' || tipo == 'medico') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardAdminWeb(usuario: res['usuario']))
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CadastroGestanteWeb(usuario: res['usuario']))
          );
        }
      } else {
        _msg("Erro", res['erro'] ?? "Falha no login.");
      }
    } catch (e) {
      _msg("Erro", "Falha ao conectar com o servidor.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String t, String m) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: PolifenoisTema.azulClaroFundo,
          image: DecorationImage(
            image: AssetImage("assets/mosaico.jpg"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
          ),
        ),
        child: Center(
          child: Container(
            width: 400,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset("assets/logo.png", height: 90),
                        SizedBox(height: 15),
                        Text("Acesso Polifenóis", style: PolifenoisTema.tituloEstilo),
                        SizedBox(height: 30),
                        TextField(controller: _cpf, decoration: PolifenoisTema.inputDecoracao("CPF", Icons.badge)),
                        SizedBox(height: 15),
                        TextField(controller: _senha, obscureText: true, decoration: PolifenoisTema.inputDecoracao("Senha", Icons.key)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EsqueciSenhaWeb())),
                            child: Text("Esqueci minha senha", style: TextStyle(color: PolifenoisTema.azulPrimario, fontSize: 13)),
                          ),
                        ),
                        SizedBox(height: 10),
                        _loading
                            ? CircularProgressIndicator(color: PolifenoisTema.azulPrimario)
                            : ElevatedButton(
                                onPressed: _entrar,
                                style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, minimumSize: Size(double.infinity, 55)),
                                child: Text("ENTRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                        SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CadastroUsuarioWeb())),
                          child: Text("Cadastre-se aqui", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}