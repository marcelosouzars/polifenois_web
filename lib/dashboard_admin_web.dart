import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'login_web.dart';
import 'gestao_alimentos_web.dart';

class DashboardAdminWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;

  DashboardAdminWeb({required this.usuario});

  @override
  _DashboardAdminWebState createState() => _DashboardAdminWebState();
}

class _DashboardAdminWebState extends State<DashboardAdminWeb> {
  List<dynamic> _pacientes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarPacientes();
  }

  Future<void> _carregarPacientes() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/pacientes"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sucesso']) {
          setState(() {
            _pacientes = data['pacientes'] ?? [];
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar pacientes: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

    // Variaveis da Galeria de Fotos
    List<dynamic> refeicoes = [];
    bool carregandoRefeicoes = isEdicao;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          
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
              width: 900, 
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("1. DADOS PESSOAIS", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Row(children: [
                      Expanded(flex: 2, child: TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome Completo", Icons.person))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: cpfCtrl, decoration: PolifenoisTema.inputDecoracao("CPF", Icons.badge))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: rgCtrl, decoration: PolifenoisTema.inputDecoracao("RG", Icons.fingerprint))),
                    ]),
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
                          shrinkWrap: true, 
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
    
    setState(() => _loading = true);
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
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
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
        body: jsonEncode({
          "id_paciente": idPaciente,
          "id_admin": widget.usuario['id'], 
          "senha_admin": senha 
        }),
      );
      
      if (response.statusCode == 200) {
        Navigator.pop(context); 
        _carregarPacientes(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Acesso da paciente liberado com sucesso!"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: Senha de administrador incorreta."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Erro ao validar: $e");
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

  @override
  Widget build(BuildContext context) {
    String nomeUsuario = widget.usuario['nome'] ?? 'Administrador';

    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(
        title: Text("Vetix Dashboard Clínico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text("Olá, $nomeUsuario", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb()));
            },
          )
        ],
      ),
      body: Row(
        children: [
          // MENU LATERAL
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings, size: 50, color: PolifenoisTema.azulPrimario),
                        SizedBox(height: 10),
                        Text("Painel Clínico", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.people, color: PolifenoisTema.azulPrimario),
                  title: Text("Gestantes", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                  selected: true,
                  selectedTileColor: PolifenoisTema.azulClaroFundo,
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.pie_chart, color: PolifenoisTema.cinzaTexto),
                  title: Text("Estatísticas Nutricionais", style: TextStyle(color: PolifenoisTema.cinzaTexto)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Módulo em desenvolvimento.")));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.kitchen, color: PolifenoisTema.cinzaTexto),
                  title: Text("Base Global de Alimentos", style: TextStyle(color: PolifenoisTema.cinzaTexto)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => GestaoAlimentosWeb(usuario: widget.usuario)));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: PolifenoisTema.cinzaTexto),
                  title: Text("Configurações", style: TextStyle(color: PolifenoisTema.cinzaTexto)),
                  onTap: () => _mostrarAvisoDesenvolvimento(),
                ),
              ],
            ),
          ),

          // TABELA DE PACIENTES
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Visão Geral de Pacientes", style: PolifenoisTema.tituloEstilo),
                      Spacer(),
                      IconButton(icon: Icon(Icons.refresh, color: PolifenoisTema.azulPrimario), onPressed: _carregarPacientes),
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
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: _loading
                          ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                          : _pacientes.isEmpty
                              ? Center(child: Text("Nenhuma paciente encontrada no banco de dados.", style: PolifenoisTema.corpoEstilo))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                                      columns: [
                                        DataColumn(label: Text("Nome", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("CPF", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("E-mail", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("Sem. Gestação", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                      ],
                                      rows: _pacientes.map((p) {
                                        bool validado = p['email_validado'] == true;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(p['nome'] ?? 'Sem nome')),
                                            DataCell(Text(p['cpf'] ?? '-')),
                                            DataCell(Text(p['email'] ?? '-')),
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
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}