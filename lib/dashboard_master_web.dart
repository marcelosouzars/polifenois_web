import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'tema_padrao_web.dart';
import 'login_web.dart';
import 'gestao_alimentos_web.dart';
import 'logs_acesso_web.dart';

class DashboardMasterWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  DashboardMasterWeb({required this.usuario});

  @override
  _DashboardMasterWebState createState() => _DashboardMasterWebState();
}

class _DashboardMasterWebState extends State<DashboardMasterWeb> {
  int _indiceMenu = 0;
  Map<String, dynamic>? _stats;
  List<dynamic> _pacientes = [];
  List<dynamic> _pacientesFiltradas = [];
  bool _carregandoStats = true;
  bool _carregandoPacientes = true;
  Uint8List? _fotoPerfilBytes;

  // --- FILTROS DA LISTA DE GESTANTES ---
  final TextEditingController _filtroNome = TextEditingController();
  final TextEditingController _filtroCadIni = TextEditingController();
  final TextEditingController _filtroCadFim = TextEditingController();
  final TextEditingController _filtroNascIni = TextEditingController();
  final TextEditingController _filtroNascFim = TextEditingController();
  final TextEditingController _filtroIdadeMin = TextEditingController();
  final TextEditingController _filtroIdadeMax = TextEditingController();
  final TextEditingController _filtroCidade = TextEditingController();
  String _filtroEstado = 'TODOS';
  bool _filtroSemRefeicoes = false;

  static const List<String> _ufs = [
    'TODOS','AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
    'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
  ];

  // --- RELÓGIO DO TOPO ---
  Timer? _relogioTimer;
  DateTime _agora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _buscarEstatisticas();
    _relogioTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _relogioTimer?.cancel();
    super.dispose();
  }

  void _mudarAba(int indice) {
    setState(() => _indiceMenu = indice);
    if (indice == 0) {
      _buscarEstatisticas();
    } else if (indice == 1) {
      _carregarPacientes();
    }
  }

  void _mostrarAvisoDesenvolvimento() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Módulo em Desenvolvimento", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
        content: Text("O módulo de configurações estará disponível nas próximas atualizações do sistema."),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            child: Text("OK", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _buscarEstatisticas() async {
    setState(() => _carregandoStats = true);
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/dashboard-master-stats"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _carregandoStats = false;
        });
      } else {
        setState(() => _carregandoStats = false);
      }
    } catch (e) {
      setState(() => _carregandoStats = false);
    }
  }

  Future<void> _carregarPacientes() async {
    setState(() => _carregandoPacientes = true);
    try {
      final response = await http.get(Uri.parse("https://polifenois-backend.onrender.com/pacientes"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sucesso']) {
          setState(() {
            _pacientes = data['pacientes'] ?? [];
          });
          _aplicarFiltros();
        }
      }
    } catch (e) {
      print("Erro ao carregar pacientes: $e");
    } finally {
      if (mounted) setState(() => _carregandoPacientes = false);
    }
  }

  DateTime? _parseData(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString().split('T')[0]);
    } catch (e) { return null; }
  }

  Future<void> _selecionarData(TextEditingController ctrl) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() => ctrl.text = DateFormat('yyyy-MM-dd').format(escolhida));
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _pacientesFiltradas = _pacientes.where((p) {
        // Nome
        if (_filtroNome.text.isNotEmpty &&
            !(p['nome'] ?? '').toString().toLowerCase().contains(_filtroNome.text.toLowerCase())) {
          return false;
        }

        // Data de cadastro (inicial/final)
        if (_filtroCadIni.text.isNotEmpty || _filtroCadFim.text.isNotEmpty) {
          DateTime? dCad = _parseData(p['data_cadastro']);
          if (dCad == null) return false;
          if (_filtroCadIni.text.isNotEmpty && dCad.isBefore(DateTime.parse(_filtroCadIni.text))) return false;
          if (_filtroCadFim.text.isNotEmpty && dCad.isAfter(DateTime.parse(_filtroCadFim.text).add(Duration(days: 1)))) return false;
        }

        // Nascimento (inicial/final)
        if (_filtroNascIni.text.isNotEmpty || _filtroNascFim.text.isNotEmpty) {
          DateTime? dNasc = _parseData(p['data_nascimento']);
          if (dNasc == null) return false;
          if (_filtroNascIni.text.isNotEmpty && dNasc.isBefore(DateTime.parse(_filtroNascIni.text))) return false;
          if (_filtroNascFim.text.isNotEmpty && dNasc.isAfter(DateTime.parse(_filtroNascFim.text))) return false;
        }

        // Idade (min/max)
        int? idade = int.tryParse(p['idade']?.toString() ?? '');
        if (_filtroIdadeMin.text.isNotEmpty) {
          int min = int.tryParse(_filtroIdadeMin.text) ?? 0;
          if (idade == null || idade < min) return false;
        }
        if (_filtroIdadeMax.text.isNotEmpty) {
          int max = int.tryParse(_filtroIdadeMax.text) ?? 999;
          if (idade == null || idade > max) return false;
        }

        // Estado
        if (_filtroEstado != 'TODOS' && (p['estado'] ?? '').toString() != _filtroEstado) return false;

        // Cidade
        if (_filtroCidade.text.isNotEmpty &&
            !(p['cidade'] ?? '').toString().toLowerCase().contains(_filtroCidade.text.toLowerCase())) {
          return false;
        }

        // Sem histórico de refeições
        if (_filtroSemRefeicoes) {
          int total = int.tryParse(p['total_refeicoes']?.toString() ?? '0') ?? 0;
          if (total > 0) return false;
        }

        return true;
      }).toList();
    });
  }

  void _limparFiltros() {
    _filtroNome.clear();
    _filtroCadIni.clear();
    _filtroCadFim.clear();
    _filtroNascIni.clear();
    _filtroNascFim.clear();
    _filtroIdadeMin.clear();
    _filtroIdadeMax.clear();
    _filtroCidade.clear();
    setState(() => _filtroEstado = 'TODOS');
    setState(() => _filtroSemRefeicoes = false);
    _aplicarFiltros();
  }

  // =========================================================================
  // CRM GIGANTE: PRONTUÁRIO COMPLETO COM TODAS AS COLUNAS + FOTOS
  // =========================================================================
  void _abrirModalPaciente({Map<String, dynamic>? paciente}) {
    bool isEdicao = paciente != null;

    // Controladores - Dados Pessoais
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? (paciente['nome'] ?? '') : '');
    TextEditingController cpfCtrl = TextEditingController(text: isEdicao ? (paciente['cpf'] ?? '') : '');
    TextEditingController rgCtrl = TextEditingController(text: isEdicao ? (paciente['rg'] ?? '') : '');
    TextEditingController nascCtrl = TextEditingController(text: isEdicao && paciente['data_nascimento'] != null ? paciente['data_nascimento'].toString().split('T')[0] : '');
    TextEditingController idadeCtrl = TextEditingController(text: isEdicao ? (paciente['idade']?.toString() ?? '') : '');
    TextEditingController emailCtrl = TextEditingController(text: isEdicao ? (paciente['email'] ?? '') : '');
    TextEditingController celCtrl = TextEditingController(text: isEdicao ? (paciente['telefone'] ?? '') : '');
    TextEditingController fixoCtrl = TextEditingController(text: isEdicao ? (paciente['telefone_fixo'] ?? '') : '');
    TextEditingController nacioCtrl = TextEditingController(text: isEdicao ? (paciente['nacionalidade'] ?? '') : '');
    TextEditingController naturCtrl = TextEditingController(text: isEdicao ? (paciente['naturalidade'] ?? '') : '');
    TextEditingController maeCtrl = TextEditingController(text: isEdicao ? (paciente['nome_mae'] ?? '') : '');

    // Controladores - Endereço
    TextEditingController cepCtrl = TextEditingController(text: isEdicao ? (paciente['cep'] ?? '') : '');
    TextEditingController logradouroCtrl = TextEditingController(text: isEdicao ? (paciente['logradouro'] ?? '') : '');
    TextEditingController numCtrl = TextEditingController(text: isEdicao ? (paciente['numero'] ?? '') : '');
    TextEditingController compCtrl = TextEditingController(text: isEdicao ? (paciente['complemento'] ?? '') : '');
    TextEditingController estadoCtrl = TextEditingController(text: isEdicao ? (paciente['estado'] ?? '') : '');

    // Controladores - Clínico e Acesso
    TextEditingController semanaCtrl = TextEditingController(text: isEdicao ? (paciente['semana_gestacao']?.toString() ?? '') : '');
    TextEditingController medCtrl = TextEditingController(text: isEdicao ? (paciente['nome_medico'] ?? '') : '');
    TextEditingController crmCtrl = TextEditingController(text: isEdicao ? (paciente['crm_medico'] ?? '') : '');
    TextEditingController nutriCtrl = TextEditingController(text: isEdicao ? (paciente['nome_nutricionista'] ?? '') : '');
    TextEditingController crnCtrl = TextEditingController(text: isEdicao ? (paciente['crn_nutricionista'] ?? '') : '');
    TextEditingController senhaCtrl = TextEditingController();

    // --- FOTO DA PACIENTE (NOVO) ---
    Uint8List? fotoPacienteBytes;

    Future<void> selecionarFotoPaciente(StateSetter setModalState) async {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? imagem = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 85);
        if (imagem != null) {
          final bytes = await imagem.readAsBytes();
          setModalState(() { fotoPacienteBytes = bytes; });
          final base64Foto = base64Encode(bytes);
          await http.put(
            Uri.parse("https://polifenois-backend.onrender.com/atualizar-foto-perfil"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"usuario_id": paciente!['id'], "foto_base64": base64Foto}),
          );
        }
      } catch (e) { print("Erro ao selecionar foto da paciente: $e"); }
    }

    // Variaveis da Galeria de Fotos
    List<dynamic> refeicoes = [];
    bool carregandoRefeicoes = isEdicao;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {

          // Se for edição e ainda não carregou as refeições, busca no backend
          if (isEdicao && carregandoRefeicoes && refeicoes.isEmpty) {
            http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes-gestante/${paciente['id']}")).then((res) {
              if (res.statusCode == 200) {
                setModalState(() {
                  refeicoes = jsonDecode(res.body)['refeicoes'] ?? [];
                  carregandoRefeicoes = false;
                });
              }
            });
          }

          return AlertDialog(
            title: Text(isEdicao ? "Prontuário Completo da Paciente" : "Novo Cadastro de Paciente", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
            content: Container(
              width: 900, // Deixa o modal executivo bem largo
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SESSÃO 1: DADOS PESSOAIS
                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("1. DADOS PESSOAIS", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome Completo", Icons.person)),
                              SizedBox(height: 10),
                              TextField(controller: cpfCtrl, decoration: PolifenoisTema.inputDecoracao("CPF", Icons.badge)),
                              SizedBox(height: 10),
                              TextField(controller: rgCtrl, decoration: PolifenoisTema.inputDecoracao("RG", Icons.fingerprint)),
                            ],
                          ),
                        ),
                        SizedBox(width: 20),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: isEdicao ? () => selecionarFotoPaciente(setModalState) : null,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 110, height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade200,
                                      image: fotoPacienteBytes != null
                                        ? DecorationImage(image: MemoryImage(fotoPacienteBytes!), fit: BoxFit.cover)
                                        : (isEdicao && paciente!['foto_perfil_url'] != null && paciente['foto_perfil_url'].toString().length > 100
                                            ? DecorationImage(image: MemoryImage(base64Decode(paciente['foto_perfil_url'])), fit: BoxFit.cover)
                                            : null),
                                    ),
                                    child: (fotoPacienteBytes == null && (!isEdicao || paciente!['foto_perfil_url'] == null || paciente['foto_perfil_url'].toString().length < 100))
                                      ? Icon(Icons.person, size: 55, color: Colors.grey.shade400)
                                      : null,
                                  ),
                                  if (isEdicao)
                                    Positioned(
                                      bottom: 0, right: 0,
                                      child: CircleAvatar(radius: 16, backgroundColor: PolifenoisTema.azulPrimario,
                                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(isEdicao ? "Toque para alterar" : "Salve o cadastro\npara adicionar foto",
                              style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: nascCtrl, decoration: PolifenoisTema.inputDecoracao("Nascimento (AAAA-MM-DD)", Icons.calendar_today))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: idadeCtrl, decoration: PolifenoisTema.inputDecoracao("Idade", Icons.cake))),
                      SizedBox(width: 10),
                      Expanded(flex: 2, child: TextField(controller: emailCtrl, decoration: PolifenoisTema.inputDecoracao("E-mail", Icons.email))),
                    ]),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: celCtrl, decoration: PolifenoisTema.inputDecoracao("Celular", Icons.phone_android))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: fixoCtrl, decoration: PolifenoisTema.inputDecoracao("Fixo", Icons.phone))),
                      SizedBox(width: 10),
                      Expanded(flex: 2, child: TextField(controller: maeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome da Mãe", Icons.woman))),
                    ]),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: nacioCtrl, decoration: PolifenoisTema.inputDecoracao("Nacionalidade", Icons.flag))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: naturCtrl, decoration: PolifenoisTema.inputDecoracao("Naturalidade", Icons.location_city))),
                    ]),

                    SizedBox(height: 25),

                    // SESSÃO 2: ENDEREÇO
                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("2. ENDEREÇO", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Row(children: [
                      Expanded(child: TextField(controller: cepCtrl, decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map))),
                      SizedBox(width: 10),
                      Expanded(flex: 2, child: TextField(controller: logradouroCtrl, decoration: PolifenoisTema.inputDecoracao("Logradouro", Icons.home))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: numCtrl, decoration: PolifenoisTema.inputDecoracao("Número", Icons.numbers))),
                    ]),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(flex: 2, child: TextField(controller: compCtrl, decoration: PolifenoisTema.inputDecoracao("Complemento", Icons.info))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: estadoCtrl, decoration: PolifenoisTema.inputDecoracao("Estado (UF)", Icons.location_on))),
                    ]),

                    SizedBox(height: 25),

                    // SESSÃO 3: DADOS CLÍNICOS
                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("3. DADOS CLÍNICOS E ACESSO", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Row(children: [
                      Expanded(child: TextField(controller: semanaCtrl, decoration: PolifenoisTema.inputDecoracao("Semanas de Gestação", Icons.calendar_month))),
                      if (!isEdicao) ...[
                        SizedBox(width: 10),
                        Expanded(child: TextField(controller: senhaCtrl, decoration: PolifenoisTema.inputDecoracao("Senha Provisória", Icons.lock), obscureText: true)),
                      ]
                    ]),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(flex: 2, child: TextField(controller: medCtrl, decoration: PolifenoisTema.inputDecoracao("Médico Obstetra", Icons.medical_services))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: crmCtrl, decoration: PolifenoisTema.inputDecoracao("CRM", Icons.badge))),
                    ]),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(flex: 2, child: TextField(controller: nutriCtrl, decoration: PolifenoisTema.inputDecoracao("Nutricionista", Icons.local_dining))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: crnCtrl, decoration: PolifenoisTema.inputDecoracao("CRN", Icons.badge))),
                    ]),

                    // SESSÃO 4: GALERIA DE REFEIÇÕES (SÓ NA EDIÇÃO)
                    if (isEdicao) ...[
                      SizedBox(height: 35),
                      Container(
                        padding: EdgeInsets.all(10), color: Colors.green.shade50, width: double.infinity,
                        child: Text("4. HISTÓRICO FOTOGRÁFICO DE REFEIÇÕES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      ),
                      SizedBox(height: 15),
                      if (carregandoRefeicoes)
                        Center(child: CircularProgressIndicator())
                      else if (refeicoes.isEmpty)
                        Text("A paciente ainda não registrou nenhuma refeição no aplicativo.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                      else
                        GridView.builder(
                          shrinkWrap: true, // Importante para rodar dentro do SingleChildScrollView
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
                          ),
                          itemCount: refeicoes.length,
                          itemBuilder: (context, i) {
                            final r = refeicoes[i];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: r['foto_prato_url'] != null && r['foto_prato_url'].toString().length > 500
                                      ? Image.memory(base64Decode(r['foto_prato_url']), fit: BoxFit.cover, width: double.infinity)
                                      : Image.network(r['foto_prato_url'] ?? '', fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r['tipo_refeicao']?.toString().toUpperCase() ?? 'REFEIÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text("${r['total_polifenois_refeicao']} mg", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        )
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("FECHAR / CANCELAR")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _salvarPaciente(
                    isEdicao ? paciente['id'] : null,
                    nomeCtrl.text, cpfCtrl.text, emailCtrl.text, semanaCtrl.text, senhaCtrl.text, !isEdicao,
                    rg: rgCtrl.text, nasc: nascCtrl.text, idade: idadeCtrl.text, cel: celCtrl.text, fixo: fixoCtrl.text,
                    cep: cepCtrl.text, log: logradouroCtrl.text, num: numCtrl.text, comp: compCtrl.text, est: estadoCtrl.text,
                    nac: nacioCtrl.text, nat: naturCtrl.text, mae: maeCtrl.text,
                    med: medCtrl.text, crm: crmCtrl.text, nut: nutriCtrl.text, crn: crnCtrl.text
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                child: Text("SALVAR PRONTUÁRIO", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _salvarPaciente(int? id, String nome, String cpf, String email, String semana, String senha, bool isNovo,
    {String? rg, String? nasc, String? idade, String? cel, String? fixo, String? cep, String? log, String? num, String? comp,
     String? est, String? nac, String? nat, String? mae, String? med, String? crm, String? nut, String? crn}) async {

    setState(() => _carregandoPacientes = true);
    try {
      Uri url = isNovo
          ? Uri.parse("https://polifenois-backend.onrender.com/paciente-admin")
          : Uri.parse("https://polifenois-backend.onrender.com/pacientes/$id");

      var bodyData = {
        "nome": nome, "cpf": cpf, "email": email, "semana_gestacao": semana,
        "rg": rg, "data_nascimento": nasc, "idade": idade, "telefone": cel, "telefone_fixo": fixo,
        "cep": cep, "logradouro": log, "numero": num, "complemento": comp, "estado": est,
        "nacionalidade": nac, "naturalidade": nat, "nome_mae": mae,
        "nome_medico": med, "crm_medico": crm, "nome_nutricionista": nut, "crn_nutricionista": crn
      };
      if (isNovo) bodyData["senha"] = senha;

      var response = isNovo
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarPacientes();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prontuário salvo com sucesso!"), backgroundColor: Colors.green));
      } else {
        setState(() => _carregandoPacientes = false);
      }
    } catch (e) {
      setState(() => _carregandoPacientes = false);
    }
  }

  Future<void> _confirmarExclusaoPaciente(int id, String nome) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmar Exclusão"),
        content: Text("Deseja apagar permanentemente a paciente '$nome' e todo o seu histórico de fotos e refeições?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _pacientes.removeWhere((p) => p['id'] == id));
              await http.delete(Uri.parse("https://polifenois-backend.onrender.com/pacientes/$id"));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Paciente excluída."), backgroundColor: Colors.redAccent));
            },
            child: Text("EXCLUIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmarLiberacao(int idPaciente) {
    final TextEditingController _senhaAdminController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmar Liberação", style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Para liberar o acesso desta paciente, digite sua senha de administrador:"),
            SizedBox(height: 15),
            TextField(
              controller: _senhaAdminController,
              obscureText: true,
              decoration: PolifenoisTema.inputDecoracao("Sua Senha", Icons.lock),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            onPressed: () => _executarLiberacao(idPaciente, _senhaAdminController.text),
            child: Text("CONFIRMAR E LIBERAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executarLiberacao(int idPaciente, String senha) async {
    try {
      final response = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/validar-manual"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_paciente": idPaciente, "id_admin": widget.usuario['id'], "senha_admin": senha}),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context);
        _carregarPacientes();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Acesso liberado com sucesso!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: Senha incorreta."), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Erro ao validar: $e");
    }
  }

  Future<void> _selecionarFoto() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 85);

      if (image != null) {
        final bytes = await image.readAsBytes();
        bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Alterar Foto?"),
            content: Text("Deseja salvar esta imagem como sua foto oficial?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCELAR")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("SALVAR AGORA")),
            ],
          ),
        );

        if (confirmar == true) {
          String base64Foto = base64Encode(bytes);
          final response = await http.put(
            Uri.parse("https://polifenois-backend.onrender.com/atualizar-foto-perfil"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"usuario_id": widget.usuario['id'], "foto_base64": base64Foto}),
          );

          if (response.statusCode == 200) {
            setState(() { _fotoPerfilBytes = bytes; });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Foto atualizada!"), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) { print(e); }
  }

  String _v(dynamic valor) {
    if (valor == null) return "0";
    return valor.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F7F6),
      body: Column(
        children: [
          Container(
            height: 34,
            color: Colors.white,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24),
            child: Text(
              DateFormat('dd/MM/yyyy HH:mm:ss').format(_agora),
              style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
          Divider(height: 1, thickness: 1.2, color: Colors.black87),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 280,
                  color: Color(0xFF1A237E),
                  child: Column(
                    children: [
                      DrawerHeader(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: _fotoPerfilBytes != null
                                    ? MemoryImage(_fotoPerfilBytes!)
                                    : (widget.usuario['foto_perfil_url'] != null && widget.usuario['foto_perfil_url'].toString().length > 100
                                        ? MemoryImage(base64Decode(widget.usuario['foto_perfil_url']))
                                        : null),
                                  child: (_fotoPerfilBytes == null && (widget.usuario['foto_perfil_url'] == null || widget.usuario['foto_perfil_url'].toString().length < 100))
                                      ? Icon(Icons.person, size: 50, color: Colors.white)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: GestureDetector(
                                    onTap: _selecionarFoto,
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.amber,
                                      child: Icon(Icons.camera_alt, size: 15, color: Colors.black),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text("PAINEL MASTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(widget.usuario['nome'] ?? 'Master', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.analytics, color: _indiceMenu == 0 ? Colors.white : Colors.white54),
                        title: Text("Estatísticas Gerais", style: TextStyle(color: _indiceMenu == 0 ? Colors.white : Colors.white54, fontWeight: _indiceMenu == 0 ? FontWeight.bold : FontWeight.normal)),
                        onTap: () => _mudarAba(0),
                        tileColor: _indiceMenu == 0 ? Colors.white.withOpacity(0.1) : Colors.transparent,
                      ),
                      ListTile(
                        leading: Icon(Icons.people, color: _indiceMenu == 1 ? Colors.white : Colors.white54),
                        title: Text("Cadastro de Gestantes", style: TextStyle(color: _indiceMenu == 1 ? Colors.white : Colors.white54, fontWeight: _indiceMenu == 1 ? FontWeight.bold : FontWeight.normal)),
                        onTap: () => _mudarAba(1),
                        tileColor: _indiceMenu == 1 ? Colors.white.withOpacity(0.1) : Colors.transparent,
                      ),
                      ListTile(
                        leading: Icon(Icons.kitchen, color: Colors.white54),
                        title: Text("Base Global de Alimentos", style: TextStyle(color: Colors.white54)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => GestaoAlimentosWeb(usuario: widget.usuario)));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.security, color: Colors.white54),
                        title: Text("Logins do Sistema", style: TextStyle(color: Colors.white54)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => LogsAcessoWeb()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.settings, color: Colors.white54),
                        title: Text("Configurações", style: TextStyle(color: Colors.white54)),
                        onTap: () => _mostrarAvisoDesenvolvimento(),
                      ),
                      Spacer(),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.redAccent),
                        title: Text("Sair", style: TextStyle(color: Colors.redAccent)),
                        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb())),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),

                Expanded(
                  child: _indiceMenu == 0 ? _buildEstatisticas() : _buildListaGestantes(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstatisticas() {
    if (_carregandoStats) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Monitoramento Estratégico", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _buscarEstatisticas,
                      icon: Icon(Icons.refresh, size: 18, color: Colors.white),
                      label: Text("ATUALIZAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A237E), padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              _cardCadastrosRecentes(),
            ],
          ),
          SizedBox(height: 30),
          Wrap(
            spacing: 20, runSpacing: 20,
            children: [
              _cardKPI("TOTAL GESTANTES", _v(_stats?['total_gestantes']), Icons.pregnant_woman, Colors.blue),
              _cardKPI("IDADE MÉDIA", "${_v(_stats?['gestacional']?['idade_media'])} anos", Icons.cake, Colors.orange),
              _cardKPI("SEM REGISTRO", _v(_stats?['engajamento']?['sem_refeicoes']), Icons.no_meals, Colors.red),
            ],
          ),
          SizedBox(height: 40),
          Text("Acompanhamento Clínico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          SizedBox(height: 20),
          Wrap(
            spacing: 20, runSpacing: 20,
            children: [
              _cardKPI("COM MÉDICO", _v(_stats?['saude']?['com_medico']), Icons.medical_services, Colors.green),
              _cardKPI("SEM MÉDICO", _v(_stats?['saude']?['sem_medico']), Icons.warning_amber_rounded, Colors.redAccent),
              _cardKPI("COM NUTRICIONISTA", _v(_stats?['saude']?['com_nutri']), Icons.local_dining, Colors.green),
              _cardKPI("SEM NUTRICIONISTA", _v(_stats?['saude']?['sem_nutri']), Icons.warning_amber_rounded, Colors.redAccent),
            ],
          ),
          SizedBox(height: 40),
          Text("Distribuição por Tempo de Gestação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          SizedBox(height: 20),
          Wrap(
            spacing: 20, runSpacing: 20,
            children: [
              _cardTrimestre("1º Trimestre", "Até 13 sem", _v(_stats?['gestacional']?['trimestre1']), Colors.teal),
              _cardTrimestre("2º Trimestre", "14 a 26 sem", _v(_stats?['gestacional']?['trimestre2']), Colors.indigo),
              _cardTrimestre("3º Trimestre", "27 sem +", _v(_stats?['gestacional']?['trimestre3']), Colors.purple),
            ],
          ),
          SizedBox(height: 40),
          Text("Evolução de Cadastros (Janeiro até hoje)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          SizedBox(height: 20),
          Center(child: _graficoEvolucaoMensal()),
        ],
      ),
    );
  }

  Widget _cardCadastrosRecentes() {
    final trinta = _v(_stats?['cadastros']?['ultimos_30_dias']);
    final semana = _v(_stats?['cadastros']?['ultima_semana']);
    return Container(
      width: 320,
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_up, color: Color(0xFF1A237E), size: 20),
            SizedBox(width: 8),
            Text("Novos cadastros", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 14)),
          ]),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trinta, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Últimos 30 dias", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(semana, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Última semana", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _graficoEvolucaoMensal() {
    final List<dynamic> dados = _stats?['evolucao_mensal'] ?? [];
    const nomesMeses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

    Map<String, int> porMes = {};
    for (var d in dados) {
      porMes[d['mes'].toString()] = int.tryParse(d['total'].toString()) ?? 0;
    }

    int mesAtual = DateTime.now().month;
    int anoAtual = DateTime.now().year;
    List<MapEntry<String, int>> serie = [];
    for (int m = 1; m <= mesAtual; m++) {
      String chave = "$anoAtual-${m.toString().padLeft(2, '0')}";
      serie.add(MapEntry(nomesMeses[m - 1], porMes[chave] ?? 0));
    }

    int maior = serie.isEmpty ? 1 : serie.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (maior == 0) maior = 1;

    return Container(
      width: 700,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: serie.map((e) {
          double alturaMax = 180;
          double altura = e.value == 0 ? 4 : (e.value / maior) * alturaMax;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(e.value.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              SizedBox(height: 4),
              Container(
                width: 30, height: altura,
                decoration: BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              SizedBox(height: 8),
              Text(e.key, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _avatarPaciente(Map paciente) {
    final foto = paciente['foto_perfil_url'];
    final temFoto = foto != null && foto.toString().length > 100;
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: temFoto ? MemoryImage(base64Decode(foto)) : null,
      child: !temFoto ? Icon(Icons.person, size: 20, color: Colors.grey.shade500) : null,
    );
  }

  Widget _campoFiltroData(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _selecionarData(ctrl),
        decoration: PolifenoisTema.inputDecoracao(label, Icons.calendar_today).copyWith(isDense: true),
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _grupoFiltro(String titulo, List<Widget> campos) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5)),
          SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: campos),
        ],
      ),
    );
  }

  Widget _buildPainelFiltros() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, color: PolifenoisTema.azulPrimario, size: 20),
                SizedBox(width: 8),
                Text("Filtros", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                _grupoFiltro("NOME", [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _filtroNome,
                      decoration: PolifenoisTema.inputDecoracao("Buscar por nome", Icons.search).copyWith(isDense: true),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
                _grupoFiltro("DATA DE CADASTRO (INICIAL / FINAL)", [
                  _campoFiltroData("Inicial", _filtroCadIni),
                  SizedBox(width: 8),
                  _campoFiltroData("Final", _filtroCadFim),
                ]),
                _grupoFiltro("NASCIMENTO / ANIVERSÁRIO (INICIAL / FINAL)", [
                  _campoFiltroData("Inicial", _filtroNascIni),
                  SizedBox(width: 8),
                  _campoFiltroData("Final", _filtroNascFim),
                ]),
                _grupoFiltro("IDADE (MÍN. / MÁX.)", [
                  SizedBox(
                    width: 70,
                    child: TextField(controller: _filtroIdadeMin, keyboardType: TextInputType.number,
                      decoration: PolifenoisTema.inputDecoracao("Mín.", Icons.cake).copyWith(isDense: true), style: TextStyle(fontSize: 12)),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(controller: _filtroIdadeMax, keyboardType: TextInputType.number,
                      decoration: PolifenoisTema.inputDecoracao("Máx.", Icons.cake).copyWith(isDense: true), style: TextStyle(fontSize: 12)),
                  ),
                ]),
                _grupoFiltro("LOCALIZAÇÃO (ESTADO / CIDADE)", [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: _filtroEstado,
                      decoration: PolifenoisTema.inputDecoracao("Estado", Icons.location_on).copyWith(isDense: true),
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                      items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                      onChanged: (v) => setState(() => _filtroEstado = v ?? 'TODOS'),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: TextField(controller: _filtroCidade,
                      decoration: PolifenoisTema.inputDecoracao("Cidade", Icons.location_city).copyWith(isDense: true), style: TextStyle(fontSize: 12)),
                  ),
                ]),
                _grupoFiltro("ENGAJAMENTO", [
                  SizedBox(
                    width: 210,
                    child: CheckboxListTile(
                      value: _filtroSemRefeicoes,
                      onChanged: (v) => setState(() => _filtroSemRefeicoes = v ?? false),
                      title: Text("Sem histórico de refeições", style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ]),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _aplicarFiltros,
                  icon: Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text("APLICAR FILTROS", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                ),
                SizedBox(width: 10),
                TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: Icon(Icons.clear, size: 16),
                  label: Text("Limpar filtros (mostrar todos)"),
                ),
                Spacer(),
                Text("${_pacientesFiltradas.length} de ${_pacientes.length} gestantes", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaGestantes() {
    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Cadastro de Gestantes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              Spacer(),
              IconButton(icon: Icon(Icons.refresh, color: Color(0xFF1A237E)), onPressed: _carregarPacientes),
              SizedBox(width: 15),
              ElevatedButton.icon(
                onPressed: () => _abrirModalPaciente(),
                icon: Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                label: Text("INCLUIR PACIENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildPainelFiltros(),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: _carregandoPacientes
                  ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                  : _pacientesFiltradas.isEmpty
                      ? Center(child: Text(_pacientes.isEmpty ? "Nenhuma paciente encontrada." : "Nenhuma paciente corresponde aos filtros.", style: PolifenoisTema.corpoEstilo))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                              columns: [
                                DataColumn(label: Text("Foto", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Nome", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Cidade", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Idade", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Nutricionista", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Sem. Gestação", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                              ],
                              rows: _pacientesFiltradas.map((p) {
                                bool validado = p['email_validado'] == true;
                                return DataRow(
                                  cells: [
                                    DataCell(_avatarPaciente(p)),
                                    DataCell(Text(p['nome'] ?? 'Sem nome')),
                                    DataCell(Text(p['cidade'] ?? '-')),
                                    DataCell(Text(p['idade']?.toString() ?? '-')),
                                    DataCell(Text(p['nome_nutricionista'] ?? '-')),
                                    DataCell(Text(p['semana_gestacao']?.toString() ?? '0')),
                                    DataCell(
                                      Chip(
                                        label: Text(validado ? "Verificado" : "Pendente", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        backgroundColor: validado ? Colors.green.shade600 : Colors.orange.shade600,
                                      )
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit, color: PolifenoisTema.azulPrimario),
                                            tooltip: "Prontuário Completo",
                                            onPressed: () => _abrirModalPaciente(paciente: p),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_forever, color: Colors.red),
                                            tooltip: "Excluir Paciente",
                                            onPressed: () => _confirmarExclusaoPaciente(p['id'], p['nome']),
                                          ),
                                          if (!validado)
                                            ElevatedButton.icon(
                                              icon: Icon(Icons.key, size: 16),
                                              label: Text("Liberar Acesso"),
                                              onPressed: () => _confirmarLiberacao(p['id']),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: PolifenoisTema.azulPrimario,
                                                foregroundColor: Colors.white,
                                              ),
                                            )
                                        ],
                                      )
                                    ),
                                  ]
                                );
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardKPI(String label, String valor, IconData icon, Color cor) {
    return Container(
      width: 250,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor, size: 30),
          SizedBox(height: 15),
          Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _cardTrimestre(String titulo, String subtitulo, String valor, Color cor) {
    return Container(
      width: 340,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cor, cor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: cor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(subtitulo, style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Text(valor, style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}