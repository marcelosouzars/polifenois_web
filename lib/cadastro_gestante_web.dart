import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
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
  
  // ===========================================================================
  // CONTROLADORES SOBERANOS DO MARCELO (MANTIDOS 100%)
  // ===========================================================================
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _rg = TextEditingController();
  final TextEditingController _idade = TextEditingController();
  final TextEditingController _endereco = TextEditingController();
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
    
    // Carga inicial de todos os dados (Preservando sua lógica original)
    _nome.text = widget.usuario['nome'] ?? '';
    _rg.text = widget.usuario['rg'] ?? '';
    _idade.text = widget.usuario['idade']?.toString() ?? '';
    _endereco.text = widget.usuario['endereco'] ?? '';
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

  // ===========================================================================
  // LÓGICA DE DETALHES, EDIÇÃO E EXCLUSÃO
  // ===========================================================================

  void _abrirDetalhesRefeicao(Map<String, dynamic> refeicao) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Edição de Refeição"),
              IconButton(icon: Icon(Icons.delete_forever, color: Colors.red), 
                onPressed: () => _confirmarExclusaoRefeicao(refeicao['id']))
            ],
          ),
          content: Container(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: refeicao['foto_prato_url'] != null && refeicao['foto_prato_url'].length > 500
                          ? Image.memory(base64Decode(refeicao['foto_prato_url']), height: 300, width: double.infinity, fit: BoxFit.cover)
                          : Image.network(refeicao['foto_prato_url'] ?? '', height: 300, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        bottom: 10, right: 10,
                        child: FloatingActionButton.small(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.camera_alt, color: Colors.white), // Ícone corrigido para compatibilidade
                          onPressed: () => _reanalisarAviso(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text("Total de Polifenóis: ${refeicao['total_polifenois_refeicao']} mg", 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                  Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Composição do Prato", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ElevatedButton.icon(
                        onPressed: () => _reanalisarAviso(), 
                        icon: Icon(Icons.add), label: Text("Adicionar Item")
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  FutureBuilder<http.Response>(
                    future: http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes/${refeicao['id']}/itens")),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                      List itens = jsonDecode(snapshot.data!.body);
                      return Column(
                        children: itens.map((it) => Card(
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(Icons.restaurant_menu, color: PolifenoisTema.azulPrimario),
                            title: Text(it['nome_alimento'], style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Peso: ${it['peso_estimado_gramas']}g | Polifenóis: ${it['polifenois_consumidos_item']}mg"),
                            trailing: Wrap(
                              children: [
                                IconButton(icon: Icon(Icons.edit, color: Colors.blue), onPressed: () => _reanalisarAviso()),
                                IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => _reanalisarAviso()),
                              ],
                            ),
                          ),
                        )).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: Text("SALVAR ALTERAÇÕES")),
          ],
        ),
      ),
    );
  }

  void _reanalisarAviso() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Funcionalidade em desenvolvimento: Edição manual de itens e troca de foto em breve!")),
    );
  }

  Future<void> _confirmarExclusaoRefeicao(String id) async {
    bool? deletar = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Excluir Refeição?"),
        content: Text("Esta ação não pode ser desfeita. Deseja continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text("NÃO")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text("SIM, EXCLUIR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (deletar == true) _reanalisarAviso();
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
                      Icon(Icons.person_pin, size: 60, color: PolifenoisTema.azulPrimario),
                      SizedBox(height: 10),
                      Text(_nome.text, style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                      Text("Semana: ${_semanas.text}", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Minhas Refeições", style: TextStyle(color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.black)),
                  onTap: () => setState(() => _indiceMenu = 1),
                ),
                ListTile(
                  leading: Icon(Icons.badge, color: _indiceMenu == 0 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Dados Cadastrais", style: TextStyle(color: _indiceMenu == 0 ? PolifenoisTema.azulPrimario : Colors.black)),
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
          Text("Clique em uma refeição para editar fotos ou alimentos.", style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
          SizedBox(height: 30),
          Expanded(
            child: _carregandoRefeicoes 
              ? Center(child: CircularProgressIndicator()) 
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, 
                    crossAxisSpacing: 15, 
                    mainAxisSpacing: 15, 
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _refeicoes.length,
                  itemBuilder: (context, i) {
                    final r = _refeicoes[i];
                    return GestureDetector(
                      onTap: () => _abrirDetalhesRefeicao(r),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  r['foto_prato_url'] != null && r['foto_prato_url'].toString().length > 500
                                    ? Image.memory(base64Decode(r['foto_prato_url']), fit: BoxFit.cover, width: double.infinity)
                                    : Image.network(r['foto_prato_url'] ?? 'https://via.placeholder.com/300', fit: BoxFit.cover, width: double.infinity),
                                  Positioned(
                                    top: 5, right: 5,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                      child: Icon(Icons.edit, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['tipo_refeicao']?.toString().toUpperCase() ?? 'REFEIÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text("${r['total_polifenois_refeicao']}mg", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                                ],
                              ),
                            )
                          ],
                        ),
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
                Text("Dados Principais e Saúde", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(flex: 2, child: TextFormField(controller: _nome, decoration: PolifenoisTema.inputDecoracao("Nome Completo", Icons.person))),
                  SizedBox(width: 15),
                  Expanded(child: _campoInativo("CPF", widget.usuario['cpf'])),
                  SizedBox(width: 15),
                  Expanded(child: _campoInativo("E-mail", widget.usuario['email'])),
                ]),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _rg, decoration: PolifenoisTema.inputDecoracao("RG", Icons.badge))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _idade, keyboardType: TextInputType.number, decoration: PolifenoisTema.inputDecoracao("Idade", Icons.cake))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _dataNasc, decoration: PolifenoisTema.inputDecoracao("Nascimento (AAAA-MM-DD)", Icons.calendar_today))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _semanas, keyboardType: TextInputType.number, decoration: PolifenoisTema.inputDecoracao("Semana de Gestação", Icons.pregnant_woman))),
                ]),
                SizedBox(height: 30),
                Text("Equipe Médica", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(flex: 2, child: TextFormField(controller: _medico, decoration: PolifenoisTema.inputDecoracao("Nome do Médico", Icons.medical_services))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _crm, decoration: PolifenoisTema.inputDecoracao("CRM", Icons.badge))),
                ]),
                SizedBox(height: 40),
                _salvando ? Center(child: CircularProgressIndicator()) : ElevatedButton(
                  onPressed: () {}, 
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, minimumSize: Size(double.infinity, 60)),
                  child: Text("GUARDAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text(valor ?? '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}