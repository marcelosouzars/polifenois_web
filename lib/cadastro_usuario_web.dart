import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'tema_padrao_web.dart'; // Importando o tema azul [cite: 2646]
import 'verificacao_cadastro_web.dart'; // Importando a tela de verificação 

class CadastroUsuarioWeb extends StatefulWidget {
  @override
  _CadastroUsuarioWebState createState() => _CadastroUsuarioWebState();
}

class _CadastroUsuarioWebState extends State<CadastroUsuarioWeb> {
  // Controllers para capturar os dados do formulário [cite: 1374, 1641]
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _senha = TextEditingController();
  final _rg = TextEditingController();
  final _cpf = TextEditingController();
  final _nasc = TextEditingController();
  final _end = TextEditingController();
  final _idade = TextEditingController();
  final _semana = TextEditingController();
  bool _loading = false;

  Future<void> _enviar() async {
    // Validação básica de campos obrigatórios [cite: 2429, 2888]
    if (_cpf.text.isEmpty || _email.text.isEmpty || _telefone.text.isEmpty) {
      _pop("Aviso", "CPF, E-mail e Telefone são obrigatórios.");
      return;
    }

    setState(() => _loading = true);
    try {
      // URL real do seu backend no Render [cite: 1216, 1655]
      final url = Uri.parse("https://polifenois-backend.onrender.com/signup");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nome": _nome.text,
          "email": _email.text,
          "telefone": _telefone.text, // Campo para SMS [cite: 3189, 3207]
          "senha": _senha.text,
          "rg": _rg.text,
          "cpf": _cpf.text,
          "data_nascimento": _nasc.text,
          "endereco": _end.text,
          "idade": _idade.text,
          "semana_gestacao": _semana.text,
          "tipo_usuario": "gestante"
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 && result['sucesso']) {
        // Navega para a tela de Verificação após o cadastro [cite: 3054]
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificacaoCadastroWeb(email: _email.text),
          ),
        );
      } else {
        _pop("Erro", result['erro'] ?? "O servidor recusou o cadastro.");
      }
    } catch (e) {
      _pop("Erro de Rede", "Falha de conexão com o Render.");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _pop(String t, String m) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t, style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Text(m),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo, // Fundo azul clínico [cite: 2652, 2703]
      appBar: AppBar(
        title: Text("VETIX - Cadastro de Gestante"),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 700, // Largura para visualização Web [cite: 1689, 2947]
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Text("Informações da Paciente", style: PolifenoisTema.tituloEstilo),
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
                    
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _email, decoration: PolifenoisTema.inputDecoracao("E-mail", Icons.email))),
                        SizedBox(width: 15),
                        Expanded(child: TextField(controller: _telefone, decoration: PolifenoisTema.inputDecoracao("Telefone (DDD + Número)", Icons.phone_android))),
                      ],
                    ),
                    SizedBox(height: 15),
                    
                    TextField(controller: _senha, decoration: PolifenoisTema.inputDecoracao("Senha", Icons.lock), obscureText: true),
                    SizedBox(height: 15),
                    
                    TextField(
                      controller: _nasc, 
                      decoration: PolifenoisTema.inputDecoracao("Nascimento (DD/MM/AAAA)", Icons.calendar_today),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, DataMaskFormatter()],
                    ),
                    SizedBox(height: 15),
                    
                    TextField(controller: _end, decoration: PolifenoisTema.inputDecoracao("Endereço", Icons.home)),
                    SizedBox(height: 15),
                    
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _idade, decoration: PolifenoisTema.inputDecoracao("Idade", Icons.cake))),
                        SizedBox(width: 15),
                        Expanded(child: TextField(controller: _semana, decoration: PolifenoisTema.inputDecoracao("Semana Gestação", Icons.child_friendly))),
                      ],
                    ),
                    
                    SizedBox(height: 40),
                    
                    _loading 
                    ? CircularProgressIndicator(color: PolifenoisTema.azulPrimario) 
                    : ElevatedButton(
                        onPressed: _enviar, 
                        child: Text("FINALIZAR CADASTRO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PolifenoisTema.azulPrimario,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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

// Formata a data enquanto o usuário digita [cite: 2341]
class DataMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (text.length > 8) return oldValue;
    var newText = "";
    for (var i = 0; i < text.length; i++) {
      newText += text[i];
      if ((i == 1 || i == 3) && i != text.length - 1) newText += "/";
    }
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}