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

  List<dynamic> _refeicoes = [];
  bool _carregandoRefeicoes = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarRefeicoes();
    _celular.text = widget.usuario['telefone'] ?? '';
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
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Perfil salvo!"), backgroundColor: Colors.green));
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
          // MENU LATERAL (SIDEBAR)
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // VERIFICA SE TEM FOTO CADASTRADA, SE NÃO, MOSTRA O ÍCONE PADRÃO
                      widget.usuario['foto_perfil_url'] != null && widget.usuario['foto_perfil_url'].toString().isNotEmpty
                          ? CircleAvatar(
                              radius: 35,
                              backgroundImage: NetworkImage(widget.usuario['foto_perfil_url']),
                              backgroundColor: Colors.transparent,
                            )
                          : Icon(Icons.person_pin, size: 60, color: PolifenoisTema.azulPrimario),
                      
                      SizedBox(height: 10),
                      Text(widget.usuario['nome'] ?? 'Gestante', style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                      Text("Semana: ${widget.usuario['semana_gestacao'] ?? '?'}", style: TextStyle(fontSize: 12, color: Colors.grey)),
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

          // CONTEÚDO PRINCIPAL
          Expanded(
            child: _indiceMenu == 1 ? _buildDashboardRefeicoes() : _buildFormulario(),
          ),
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.no_meals, size: 80, color: Colors.grey[300]),
                        SizedBox(height: 20),
                        Text("Nenhuma refeição registrada até o momento.", style: TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.8,
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
                            Expanded(
                              child: Image.network(
                                r['foto_prato_url'] ?? 'https://via.placeholder.com/300',
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['tipo_refeicao'] ?? 'REFEIÇÃO', style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                                  Text("Data: ${r['data_hora_registro']}", style: TextStyle(fontSize: 12)),
                                  Divider(),
                                  Text("Peso Total: ${r['peso_total_refeicao']}g"),
                                  Text("Polifenóis: ${r['total_polifenois_refeicao']}mg", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      Text("${r['latitude']}, ${r['longitude']}", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  )
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
                SizedBox(height: 10),
                Text("Complete seu perfil para um acompanhamento preciso.", style: PolifenoisTema.corpoEstilo),
                Divider(height: 40),
                
                Row(children: [
                  Expanded(child: _campoInativo("CPF", widget.usuario['cpf'])),
                  SizedBox(width: 15),
                  Expanded(child: _campoInativo("E-mail", widget.usuario['email'])),
                ]),
                SizedBox(height: 20),

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
                SizedBox(height: 15),
                Row(children: [
                  Expanded(flex: 2, child: TextFormField(controller: _nutri, decoration: PolifenoisTema.inputDecoracao("Nome do Nutricionista", Icons.local_dining))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _crn, decoration: PolifenoisTema.inputDecoracao("CRN", Icons.badge))),
                ]),
                SizedBox(height: 30),

                Text("Endereço Residencial", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _cep, decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map), onChanged: (v) => _buscarCEP())),
                  SizedBox(width: 15),
                  Expanded(flex: 2, child: TextFormField(controller: _rua, decoration: PolifenoisTema.inputDecoracao("Logradouro", Icons.home))),
                ]),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _num, decoration: PolifenoisTema.inputDecoracao("Número", Icons.numbers))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _comp, decoration: PolifenoisTema.inputDecoracao("Complemento", Icons.info))),
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

  Widget _campoInativo(String label, String? valor) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(valor ?? '-', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}