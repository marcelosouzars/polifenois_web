import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'tema_padrao_web.dart'; // Importando o seu tema azul [cite: 1357]
import 'VERIFICACAO_CADASTRO_WEB.DART'; // Importando a tela de verificação [cite: 2361]

void main() {
  runApp(MaterialApp(
    title: 'Vetix Polifenóis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    // Definimos o Cadastro como tela inicial
    home: CadastroWebPage(), 
  ));
}

class CadastroWebPage extends StatefulWidget {
  @override
  _CadastroWebPageState createState() => _CadastroWebPageState();
}

class _CadastroWebPageState extends State<CadastroWebPage> {
  // Controllers seguindo o padrão completo solicitado [cite: 1641, 1649]
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
    // Validação básica antes de enviar
    if (_cpf.text.isEmpty || _email.text.isEmpty || _telefone.text.isEmpty) {
      _pop("Aviso", "CPF, E-mail e Telefone são obrigatórios.");
      return;
    }

    setState(() => _loading = true);
    try {
      // URL real do seu backend no Render [cite: 1655]
      final url = Uri.parse("https://polifenois-backend.onrender.com/signup");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nome": _nome.text,
          "email": _email.text,
          "telefone": _telefone.text, // Campo essencial para SMS [cite: 2362]
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
        // Se o cadastro deu certo, navegamos para a tela de Verificação [cite: 2360]
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
      backgroundColor: PolifenoisTema.azulClaroFundo, // Fundo azul suave [cite: 1427]
      appBar: AppBar(
        title: Text("VETIX - Cadastro de Gestante"),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 700, // Largura maior para ficar elegante na Web [cite: 1445]
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
                    
                    // Campos usando o seu tema_padrao_web.dart
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