import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

void main() => runApp(MaterialApp(home: CadastroWebPage(), debugShowCheckedModeBanner: false));

class CadastroWebPage extends StatefulWidget {
  @override
  _CadastroWebPageState createState() => _CadastroWebPageState();
}

class _CadastroWebPageState extends State<CadastroWebPage> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _rg = TextEditingController();
  final _cpf = TextEditingController();
  final _nasc = TextEditingController();
  final _end = TextEditingController();
  final _idade = TextEditingController();
  final _semana = TextEditingController();
  bool _loading = false;

  Future<void> _enviar() async {
    setState(() => _loading = true);
    try {
      // ATENÇÃO: COLOQUE A URL DO SEU BACKEND NO RENDER AQUI [cite: 790]
      final url = Uri.parse("https://polifenois-backend.onrender.com/signup");
      
      final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nome": _nome.text,
          "email": _email.text,
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

      if (response.statusCode == 201) {
        _pop("Sucesso", "Gestante cadastrada com sucesso!");
      } else {
        _pop("Erro", "O servidor recusou o cadastro. Verifique os dados.");
      }
    } catch (e) {
      _pop("Erro de Rede", "Falha de conexão com o Render.");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _pop(String t, String m) => showDialog(context: context, builder: (c) => AlertDialog(title: Text(t), content: Text(m), actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("VETIX - Cadastro de Gestante"), backgroundColor: Colors.green[800]),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450, padding: EdgeInsets.all(20),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(controller: _nome, decoration: InputDecoration(labelText: "Nome Completo")),
                    TextField(controller: _email, decoration: InputDecoration(labelText: "E-mail")),
                    TextField(controller: _senha, decoration: InputDecoration(labelText: "Senha"), obscureText: true),
                    Row(children: [
                      Expanded(child: TextField(controller: _cpf, decoration: InputDecoration(labelText: "CPF"))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: _rg, decoration: InputDecoration(labelText: "RG"))),
                    ]),
                    TextField(
                      controller: _nasc, 
                      decoration: InputDecoration(labelText: "Nascimento (DD/MM/AAAA)"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, DataMaskFormatter()],
                    ),
                    TextField(controller: _end, decoration: InputDecoration(labelText: "Endereço")),
                    Row(children: [
                      Expanded(child: TextField(controller: _idade, decoration: InputDecoration(labelText: "Idade"))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: _semana, decoration: InputDecoration(labelText: "Semana Gestação"))),
                    ]),
                    SizedBox(height: 25),
                    _loading ? CircularProgressIndicator() : ElevatedButton(
                      onPressed: _enviar, 
                      child: Text("CADASTRAR PACIENTE"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white, minimumSize: Size(double.infinity, 50)),
                    )
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