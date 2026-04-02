import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart'; // Importando seu novo arquivo renomeado

class CadastroUsuarioWeb extends StatefulWidget {
  @override
  _CadastroUsuarioWebState createState() => _CadastroUsuarioWebState();
}

class _CadastroUsuarioWebState extends State<CadastroUsuarioWeb> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _rg = TextEditingController();
  final _cpf = TextEditingController();
  final _nascimento = TextEditingController();
  final _endereco = TextEditingController();
  final _idade = TextEditingController();
  final _semana = TextEditingController();
  bool _enviando = false;

  Future<void> _executarCadastro() async {
    if (_cpf.text.isEmpty || _email.text.isEmpty) {
      _mensagem("Aviso", "CPF e E-mail são obrigatórios.");
      return;
    }

    setState(() => _enviando = true);
    try {
      // Substitua pela sua URL real do Render [cite: 1655]
      final url = Uri.parse("https://sua-url-no-render.com/signup");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nome": _nome.text,
          "email": _email.text,
          "senha": _senha.text,
          "rg": _rg.text,
          "cpf": _cpf.text,
          "data_nascimento": _nascimento.text,
          "endereco": _endereco.text,
          "idade": _idade.text,
          "semana_gestacao": _semana.text,
          "tipo_usuario": "gestante"
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 && result['sucesso']) {
        _mensagem("Sucesso!", "Cadastro realizado. Agora valide seu e-mail e telefone.");
      } else {
        _mensagem("Erro", result['erro'] ?? "Falha no cadastro.");
      }
    } catch (e) {
      _mensagem("Erro de Conexão", "Não foi possível falar com o servidor.");
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _mensagem(String t, String m) {
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
      appBar: AppBar(
        title: Text("Novo Cadastro de Gestante", style: TextStyle(color: Colors.white)),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Container(
            width: 700,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Text("Informações Pessoais", style: PolifenoisTema.tituloEstilo),
                    SizedBox(height: 30),
                    TextField(controller: _nome, decoration: PolifenoisTema.inputDecoracao("Nome Completo", Icons.person)),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _cpf, decoration: PolifenoisTema.inputDecoracao("CPF", Icons.badge))),
                        SizedBox(width: 15),
                        Expanded(child: TextField(controller: _rg, decoration: PolifenoisTema.inputDecoracao("RG", Icons.fingerprint))),
                      ],
                    ),
                    SizedBox(height: 15),
                    TextField(controller: _email, decoration: PolifenoisTema.inputDecoracao("E-mail", Icons.email)),
                    SizedBox(height: 15),
                    TextField(controller: _senha, obscureText: true, decoration: PolifenoisTema.inputDecoracao("Senha de Acesso", Icons.lock)),
                    SizedBox(height: 15),
                    TextField(controller: _nascimento, decoration: PolifenoisTema.inputDecoracao("Nascimento (DD/MM/AAAA)", Icons.calendar_today)),
                    SizedBox(height: 15),
                    TextField(controller: _endereco, decoration: PolifenoisTema.inputDecoracao("Endereço Residencial", Icons.home)),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _idade, decoration: PolifenoisTema.inputDecoracao("Idade", Icons.cake))),
                        SizedBox(width: 15),
                        Expanded(child: TextField(controller: _semana, decoration: PolifenoisTema.inputDecoracao("Semana Gestacional", Icons.child_friendly))),
                      ],
                    ),
                    SizedBox(height: 40),
                    _enviando 
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _executarCadastro,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PolifenoisTema.azulPrimario,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("FINALIZAR CADASTRO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
