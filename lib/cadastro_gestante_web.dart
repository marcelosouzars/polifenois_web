import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart'; // Adicione esta biblioteca no pubspec.yaml
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

  // ===========================================================================
  // MÉTODOS DE APOIO
  // ===========================================================================

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

  // NOVA FUNÇÃO: ABRE O DETALHE IGUAL NO MOBILE
  void _abrirDetalhesRefeicao(Map<String, dynamic> refeicao) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Raio-X da Refeição (${refeicao['tipo_refeicao']})"),
        content: Container(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: refeicao['foto_prato_url'] != null && refeicao['foto_prato_url'].length > 500
                    ? Image.memory(base64Decode(refeicao['foto_prato_url']), height: 250, fit: BoxFit.cover)
                    : Image.network(refeicao['foto_prato_url'] ?? 'https://via.placeholder.com/300', height: 250, fit: BoxFit.cover),
                ),
                SizedBox(height: 20),
                Text("Polifenóis Totais: ${refeicao['total_polifenois_refeicao']}mg", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                Divider(height: 30),
                Text("Alimentos Identificados pela IA:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                // Busca os itens específicos dessa refeição
                FutureBuilder<http.Response>(
                  future: http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes/${refeicao['id']}/itens")),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();
                    List itens = jsonDecode(snapshot.data!.body);
                    return Column(
                      children: itens.map((it) => ListTile(
                        leading: Icon(Icons.check_circle, color: PolifenoisTema.azulPrimario),
                        title: Text(it['nome_alimento']),
                        subtitle: Text("${it['peso_estimado_gramas']}g"),
                        trailing: Text("${it['polifenois_consumidos_item']}mg", style: TextStyle(fontWeight: FontWeight.bold)),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("FECHAR")),
          ElevatedButton.icon(
            icon: Icon(Icons.auto_awesome),
            label: Text("REANALISAR FOTO"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => _reanalisarRefeicao(refeicao['id']),
          )
        ],
      ),
    );
  }

  Future<void> _reanalisarRefeicao(String id) async {
    // Abre o seletor de arquivos da WEB
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      String base64Foto = base64Encode(result.files.first.bytes!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enviando nova foto para a IA... Aguarde.")));
      
      // Aqui chamaremos a rota de reanálise (que vamos criar no backend)
      Navigator.pop(context);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final res = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.usuario['id'],
          "nome": _nome.text,
          "rg": _rg.text,
          "idade": int.tryParse(_idade.text),
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
          "endereco": _endereco.text,
          "cpf": widget.usuario['cpf'],
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dados atualizados com sucesso!"), backgroundColor: Colors.green));
      }
    } finally {
      setState(() => _salvando = false);
    }
  }

  // ===========================================================================
  // CONSTRUÇÃO DA INTERFACE (SIDEBAR + CONTEÚDO)
  // ===========================================================================

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
                      Text(_nome.text.isNotEmpty ? _nome.text : 'Gestante', style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario), textAlign: TextAlign.center),
                      Text("Semana: ${_semanas.text}", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Minhas Refeições", style: TextStyle(color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.black, fontWeight: _indiceMenu == 1 ? FontWeight.bold : FontWeight.normal)),
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
          SizedBox(height: 30),
          Expanded(
            child: _carregandoRefeicoes 
              ? Center(child: CircularProgressIndicator()) 
              : _refeicoes.isEmpty 
                ? Center(child: Text("Nenhuma refeição registrada."))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 Colunas para fotos menores e elegantes
                      crossAxisSpacing: 20, 
                      mainAxisSpacing: 20, 
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _refeicoes.length,
                    itemBuilder: (context, i) {
                      final r = _refeicoes[i];
                      return GestureDetector(
                        onTap: () => _abrirDetalhesRefeicao(r),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: r['foto_prato_url'] != null && r['foto_prato_url'].toString().length > 500
                                  ? Image.memory(base64Decode(r['foto_prato_url']), fit: BoxFit.cover, width: double.infinity)
                                  : Image.network(r['foto_prato_url'] ?? 'https://via.placeholder.com/300', fit: BoxFit.cover, width: double.infinity),
                              ),
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['tipo_refeicao']?.toString().toUpperCase() ?? 'REFEIÇÃO', style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                                    Text("Polifenóis: ${r['total_polifenois_refeicao']}mg", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    Text("Data: ${r['data_hora_registro']?.toString().split('T')[0] ?? ''}", style: TextStyle(fontSize: 11)),
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

  // ===========================================================================
  // SEU FORMULÁRIO COMPLETO (MANTIDO ÍNTEGRO)
  // ===========================================================================
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

                Text("Dados Pessoais e Naturais", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _nacionalidade, decoration: PolifenoisTema.inputDecoracao("Nacionalidade", Icons.flag))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _natural, decoration: PolifenoisTema.inputDecoracao("Naturalidade", Icons.location_city))),
                ]),
                SizedBox(height: 15),
                TextFormField(controller: _mae, decoration: PolifenoisTema.inputDecoracao("Nome da Mãe", Icons.woman)),
                SizedBox(height: 30),

                Text("Contactos", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _celular, decoration: PolifenoisTema.inputDecoracao("Telefone Celular", Icons.phone_android))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _telFixo, decoration: PolifenoisTema.inputDecoracao("Telefone Fixo", Icons.phone))),
                ]),
                SizedBox(height: 30),

                Text("Equipa Médica", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
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
                  SizedBox(width: 15),
                  Expanded(flex: 2, child: TextFormField(controller: _endereco, decoration: PolifenoisTema.inputDecoracao("Anotações de Endereço", Icons.note))),
                ]),
                SizedBox(height: 40),

                _salvando 
                ? Center(child: CircularProgressIndicator()) 
                : ElevatedButton(
                    onPressed: _salvar,
                    style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, minimumSize: Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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