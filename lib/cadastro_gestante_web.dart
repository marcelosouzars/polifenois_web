import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';

class CadastroGestanteWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;

  CadastroGestanteWeb({required this.usuario});

  @override
  _CadastroGestanteWebState createState() => _CadastroGestanteWebState();
}

class _CadastroGestanteWebState extends State<CadastroGestanteWeb> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final TextEditingController _cep = TextEditingController();
  final TextEditingController _rua = TextEditingController();
  final TextEditingController _num = TextEditingController();
  final TextEditingController _comp = TextEditingController();
  final TextEditingController _nacionalidade = TextEditingController();
  final TextEditingController _natural = TextEditingController();
  final TextEditingController _mae = TextEditingController();
  final TextEditingController _medico = TextEditingController();
  final TextEditingController _crm = TextEditingController();
  final TextEditingController _nutri = TextEditingController();
  final TextEditingController _crn = TextEditingController();
  final TextEditingController _telFixo = TextEditingController();
  final TextEditingController _celular = TextEditingController();
  final TextEditingController _email = TextEditingController();

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Preenchendo com os dados que já vieram do banco no login
    _celular.text = widget.usuario['telefone'] ?? '';
    _email.text = widget.usuario['email'] ?? '';
    _nacionalidade.text = widget.usuario['nacionalidade'] ?? '';
    _natural.text = widget.usuario['naturalidade'] ?? '';
    _mae.text = widget.usuario['nome_mae'] ?? '';
    _medico.text = widget.usuario['nome_medico'] ?? '';
    _crm.text = widget.usuario['crm_medico'] ?? '';
    _nutri.text = widget.usuario['nome_nutricionista'] ?? '';
    _crn.text = widget.usuario['crn_nutricionista'] ?? '';
    _telFixo.text = widget.usuario['telefone_fixo'] ?? '';
    _cep.text = widget.usuario['cep'] ?? '';
    _rua.text = widget.usuario['logradouro'] ?? '';
    _num.text = widget.usuario['numero'] ?? '';
    _comp.text = widget.usuario['complemento'] ?? '';
  }

  // BUSCA DE CEP VIA API PÚBLICA (VIACEP)
  Future<void> _buscarCEP() async {
    String cepLimpo = _cep.text.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length == 8) {
      final res = await http.get(Uri.parse("https://viacep.com.br/ws/$cepLimpo/json/"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['erro'] == null) {
          setState(() {
            _rua.text = data['logradouro'] ?? '';
          });
        }
      }
    }
  }

  // ENVIAR DADOS PARA O BACKEND
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _salvando = true);

    try {
      final response = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/atualizar-perfil"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.usuario['id'],
          "nacionalidade": _nacionalidade.text,
          "naturalidade": _natural.text,
          "nome_mae": _mae.text,
          "nome_medico": _medico.text,
          "crm_medico": _crm.text,
          "nome_nutricionista": _nutri.text,
          "crn_nutricionista": _crn.text,
          "telefone_fixo": _telFixo.text,
          "logradouro": _rua.text,
          "numero": _num.text,
          "complemento": _comp.text,
          "cep": _cep.text,
          "telefone": _celular.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Perfil atualizado com sucesso!"), backgroundColor: Colors.green)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao atualizar o perfil."), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro de conexão com o servidor."), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(
        title: Text("Completar Perfil - Polifenóis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32),
          child: Container(
            width: 800, // Largura controlada para não espalhar muito na tela web
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Olá, ${widget.usuario['nome']}.", style: PolifenoisTema.tituloEstilo),
                      SizedBox(height: 10),
                      Text("Por favor, complete seus dados de saúde e endereço.", style: PolifenoisTema.corpoEstilo),
                      SizedBox(height: 30),
                      
                      // DADOS PESSOAIS
                      Text("Dados Pessoais e Familiares", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: PolifenoisTema.azulPrimario)),
                      Divider(),
                      SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _nacionalidade, decoration: PolifenoisTema.inputDecoracao("Nacionalidade", Icons.flag))),
                        SizedBox(width: 15),
                        Expanded(child: TextFormField(controller: _natural, decoration: PolifenoisTema.inputDecoracao("Naturalidade (Cidade onde nasceu)", Icons.location_city))),
                      ]),
                      SizedBox(height: 15),
                      TextFormField(controller: _mae, decoration: PolifenoisTema.inputDecoracao("Nome da Mãe", Icons.woman)),
                      SizedBox(height: 30),

                      // ENDEREÇO
                      Text("Endereço", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: PolifenoisTema.azulPrimario)),
                      Divider(),
                      SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: _cep, 
                          decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map),
                          onChanged: (v) => _buscarCEP(), // Executa a busca ao digitar
                        )),
                        SizedBox(width: 15),
                        Expanded(flex: 2, child: TextFormField(controller: _rua, decoration: PolifenoisTema.inputDecoracao("Endereço (Rua)", Icons.home))),
                      ]),
                      SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _num, decoration: PolifenoisTema.inputDecoracao("Número", Icons.numbers))),
                        SizedBox(width: 15),
                        Expanded(child: TextFormField(controller: _comp, decoration: PolifenoisTema.inputDecoracao("Complemento", Icons.info))),
                      ]),
                      SizedBox(height: 30),

                      // CONTATOS
                      Text("Contatos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: PolifenoisTema.azulPrimario)),
                      Divider(),
                      SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: _celular, 
                          decoration: PolifenoisTema.inputDecoracao("Telefone Celular *", Icons.phone_android),
                          validator: (value) => value!.isEmpty ? "Campo obrigatório" : null,
                        )),
                        SizedBox(width: 15),
                        Expanded(child: TextFormField(controller: _telFixo, decoration: PolifenoisTema.inputDecoracao("Telefone Fixo (Opcional)", Icons.phone))),
                      ]),
                      SizedBox(height: 15),
                      TextFormField(
                        controller: _email, 
                        decoration: PolifenoisTema.inputDecoracao("E-mail *", Icons.email),
                        validator: (value) {
                          if (value!.isEmpty) return "Campo obrigatório";
                          if (!value.contains("@")) return "E-mail inválido";
                          return null;
                        },
                      ),
                      SizedBox(height: 30),

                      // DADOS CLÍNICOS
                      Text("Acompanhamento Profissional (Opcional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: PolifenoisTema.azulPrimario)),
                      Divider(),
                      SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _medico, decoration: PolifenoisTema.inputDecoracao("Nome do Médico", Icons.medical_services))),
                        SizedBox(width: 15),
                        Expanded(child: TextFormField(controller: _crm, decoration: PolifenoisTema.inputDecoracao("CRM do Médico", Icons.badge))),
                      ]),
                      SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _nutri, decoration: PolifenoisTema.inputDecoracao("Nome do Nutricionista", Icons.local_dining))),
                        SizedBox(width: 15),
                        Expanded(child: TextFormField(controller: _crn, decoration: PolifenoisTema.inputDecoracao("CRN do Nutricionista", Icons.badge))),
                      ]),
                      
                      SizedBox(height: 40),
                      
                      // BOTÃO SALVAR
                      _salvando 
                      ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                      : ElevatedButton(
                          onPressed: _salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PolifenoisTema.azulPrimario, 
                            minimumSize: Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          child: Text("SALVAR DADOS DO PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                    ],
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