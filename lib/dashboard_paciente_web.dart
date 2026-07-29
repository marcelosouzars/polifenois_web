//
// DASHBOARD_PACIENTE_WEB.DART
//
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';

class DashboardPacienteWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  DashboardPacienteWeb({required this.usuario});
  @override
  _DashboardPacienteWebState createState() => _DashboardPacienteWebState();
}

class _DashboardPacienteWebState extends State<DashboardPacienteWeb> {
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _buscarCEP() async {
    if (_cep.text.length == 8) {
      final res = await http.get(Uri.parse("https://viacep.com.br/ws/${_cep.text}/json/"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _rua.text = data['logradouro'] ?? ''; });
      }
    }
  }

  Future<void> _salvar() async {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Perfil atualizado com sucesso!"), backgroundColor: Colors.green));
    }
  }

  @override
  void initState() {
    super.initState();
    _celular.text = widget.usuario['telefone'] ?? '';
    _email.text = widget.usuario['email'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Completar Perfil - Polifenóis"), backgroundColor: PolifenoisTema.azulPrimario),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Olá, ${widget.usuario['nome']}. Por favor, complete seus dados profissionais e de saúde.", style: PolifenoisTema.tituloEstilo),
              SizedBox(height: 30),
              Row(children: [
                Expanded(child: TextFormField(controller: _nacionalidade, decoration: PolifenoisTema.inputDecoracao("Nacionalidade", Icons.flag))),
                SizedBox(width: 15),
                Expanded(child: TextFormField(controller: _natural, decoration: PolifenoisTema.inputDecoracao("Naturalidade (Cidade)", Icons.location_city))),
              ]),
              SizedBox(height: 15),
              TextFormField(controller: _mae, decoration: PolifenoisTema.inputDecoracao("Nome da Mãe", Icons.woman)),
              SizedBox(height: 15),
              Row(children: [
                Expanded(child: TextFormField(controller: _cep, decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map), onChanged: (v) => _buscarCEP())),
                SizedBox(width: 15),
                Expanded(flex: 2, child: TextFormField(controller: _rua, decoration: PolifenoisTema.inputDecoracao("Endereço (Rua)", Icons.home))),
              ]),
              SizedBox(height: 15),
              Row(children: [
                Expanded(child: TextFormField(controller: _num, decoration: PolifenoisTema.inputDecoracao("Número", Icons.numbers))),
                SizedBox(width: 15),
                Expanded(child: TextFormField(controller: _comp, decoration: PolifenoisTema.inputDecoracao("Complemento", Icons.info))),
              ]),
              SizedBox(height: 15),
              Row(children: [
                Expanded(child: TextFormField(controller: _medico, decoration: PolifenoisTema.inputDecoracao("Nome do Médico", Icons.medical_services))),
                SizedBox(width: 15),
                Expanded(child: TextFormField(controller: _crm, decoration: PolifenoisTema.inputDecoracao("CRM", Icons.badge))),
              ]),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _salvar,
                style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, minimumSize: Size(double.infinity, 60)),
                child: Text("SALVAR DADOS DO PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
