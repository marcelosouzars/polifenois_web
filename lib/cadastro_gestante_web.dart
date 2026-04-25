import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'login_web.dart';

class CadastroGestanteWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  CadastroGestanteWeb({required this.usuario});

  @override
  _CadastroGestanteWebState createState() => _CadastroGestanteWebState();
}

class _CadastroGestanteWebState extends State<CadastroGestanteWeb> {
  int _indiceMenu = 1; // 1 = Dashboard (Refeições), 0 = Perfil
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final TextEditingController _dataNasc = TextEditingController();
  final TextEditingController _semanas = TextEditingController();
  final TextEditingController _telFixo = TextEditingController();
  final TextEditingController _celular = TextEditingController();
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

  List<dynamic> _refeicoes = [];
  bool _carregandoRefeicoes = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarRefeicoes();
    
    // Carga inicial dos dados
    _dataNasc.text = widget.usuario['data_nascimento'] != null 
        ? widget.usuario['data_nascimento'].toString().split('T')[0] 
        : '';
    _semanas.text = widget.usuario['semana_gestacao']?.toString() ?? '';
    _celular.text = widget.usuario['telefone'] ?? '';
    _telFixo.text = widget.usuario['telefone_fixo'] ?? '';
    _nacionalidade.text = widget.usuario['nacionalidade'] ?? '';
    _natural.text = widget.usuario['naturalidade'] ?? '';
    _mae.text = widget.usuario['nome_mae'] ?? '';
    _medico.text = widget.usuario['nome_medico'] ?? '';
    _crm.text = widget.usuario['crm_medico'] ?? '';
    _nutri.text = widget.usuario['nome_nutricionista'] ?? '';
    _crn.text = widget.usuario['crn_nutricionista'] ?? '';
    _cep.text = widget.usuario['cep'] ?? '';
    _rua.text = widget.usuario['logradouro'] ?? '';
    _num.text = widget.usuario['numero'] ?? '';
    _comp.text = widget.usuario['complemento'] ?? '';
  }

  Future<void> _buscarCEP() async {
    String cepLimpo = _cep.text.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length == 8) {
      final res = await http.get(Uri.parse("https://viacep.com.br/ws/$cepLimpo/json/"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['erro'] == null) setState(() => _rua.text = data['logradouro'] ?? '');
      }
    }
  }

  Future<void> _carregarRefeicoes() async {
    setState(() => _carregandoRefeicoes = true);
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes-gestante/${widget.usuario['id']}"));
      if (res.statusCode == 200) {
        setState(() => _refeicoes = jsonDecode(res.body)['refeicoes']);
      }
    } finally {
      setState(() => _carregandoRefeicoes = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final res = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/atualizar-perfil"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.usuario['id'],
          "data_nascimento": _dataNasc.text,
          "semana_gestacao": int.tryParse(_semanas.text) ?? 0,
          "telefone": _celular.text,
          "telefone_fixo": _telFixo.text,
          "nacionalidade": _nacionalidade.text,
          "naturalidade": _natural.text,
          "nome_mae": _mae.text,
          "nome_medico": _medico.text,
          "crm_medico": _crm.text,
          "nome_nutricionista": _nutri.text,
          "crn_nutricionista": _crn.text,
          "logradouro": _rua.text,
          "numero": _num.text,
          "complemento": _comp.text,
          "cep": _cep.text,
        }),
      );
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dados atualizados!"), backgroundColor: Colors.green));
      }
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      body: Row(
        children: [
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.usuario['foto_perfil_url'] != null && widget.usuario['foto_perfil_url'].toString().isNotEmpty
                          ? CircleAvatar(
                              radius: 35,
                              backgroundImage: NetworkImage(widget.usuario['foto_perfil_url']),
                              backgroundColor: Colors.transparent,
                            )
                          : Icon(Icons.person_pin, size: 60, color: PolifenoisTema.azulPrimario),
                      SizedBox(height: 10),
                      Text(widget.usuario['nome'] ?? 'Gestante', style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                      Text("Semana: ${_semanas.text}", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Dashboard", style: TextStyle(color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.black, fontWeight: _indiceMenu == 1 ? FontWeight.bold : FontWeight.normal)),
                  onTap: () => setState(() => _indiceMenu = 1),
                ),
                ListTile(
                  leading: Icon(Icons.badge, color: _indiceMenu == 0 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Dados Cadastrais", style: TextStyle(color: _indiceMenu == 0 ? PolifenoisTema.azulPrimario : Colors.black, fontWeight: _indiceMenu == 0 ? FontWeight.bold : FontWeight.normal)),
                  onTap: () => setState(() => _indiceMenu = 0),
                ),
                Spacer(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text("Sair", style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb())),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(child: _indiceMenu == 1 ? _buildDashboardRefeicoes() : _buildFormulario()),
        ],
      ),
    );
  }

  Widget _buildDashboardRefeicoes() {
    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Minhas Refeições", style: PolifenoisTema.tituloEstilo),
          SizedBox(height: 10),
          Text("Histórico de consumo registrado via App Mobile.", style: PolifenoisTema.corpoEstilo),
          SizedBox(height: 30),
          Expanded(
            child: _carregandoRefeicoes 
              ? Center(child: CircularProgressIndicator()) 
              : _refeicoes.isEmpty 
                ? Center(child: Text("Nenhuma refeição registrada.", style: TextStyle(color: Colors.grey, fontSize: 18)))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 0.8,
                    ),
                    itemCount: _refeicoes.length,
                    itemBuilder: (context, i) {
                      final r = _refeicoes[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Image.network(r['foto_prato_url'] ?? 'https://via.placeholder.com/300', fit: BoxFit.cover, width: double.infinity)),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['tipo_refeicao'] ?? 'REFEIÇÃO', style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                                  Text("Polifenóis: ${r['total_polifenois_refeicao']}mg", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  Text("Data: ${r['data_hora_registro']}", style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(40),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Meus Dados Cadastrais", style: PolifenoisTema.tituloEstilo),
                Divider(height: 40),
                
                Text("Informações de Saúde", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _dataNasc, decoration: PolifenoisTema.inputDecoracao("Data de Nascimento (AAAA-MM-DD)", Icons.calendar_today))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _semanas, keyboardType: TextInputType.number, decoration: PolifenoisTema.inputDecoracao("Semana de Gestação", Icons.pregnant_woman))),
                ]),
                SizedBox(height: 30),

                Text("Contatos", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _celular, decoration: PolifenoisTema.inputDecoracao("Telefone Celular", Icons.phone_android))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _telFixo, decoration: PolifenoisTema.inputDecoracao("Telefone Fixo", Icons.phone))),
                ]),
                SizedBox(height: 30),

                Text("Dados Pessoais", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _nacionalidade, decoration: PolifenoisTema.inputDecoracao("Nacionalidade", Icons.flag))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _natural, decoration: PolifenoisTema.inputDecoracao("Naturalidade", Icons.location_city))),
                ]),
                SizedBox(height: 15),
                TextFormField(controller: _mae, decoration: PolifenoisTema.inputDecoracao("Nome da Mãe", Icons.woman)),
                SizedBox(height: 30),

                Text("Equipe Médica", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(flex: 2, child: TextFormField(controller: _medico, decoration: PolifenoisTema.inputDecoracao("Nome do Médico", Icons.medical_services))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _crm, decoration: PolifenoisTema.inputDecoracao("CRM", Icons.badge))),
                ]),
                SizedBox(height: 30),

                Text("Endereço Residencial", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _cep, decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map), onChanged: (v) => _buscarCEP())),
                  SizedBox(width: 15),
                  Expanded(flex: 2, child: TextFormField(controller: _rua, decoration: PolifenoisTema.inputDecoracao("Logradouro", Icons.home))),
                ]),
                SizedBox(height: 40),

                _salvando 
                ? Center(child: CircularProgressIndicator()) 
                : ElevatedButton(
                    onPressed: _salvar,
                    style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, minimumSize: Size(double.infinity, 60)),
                    child: Text("SALVAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}