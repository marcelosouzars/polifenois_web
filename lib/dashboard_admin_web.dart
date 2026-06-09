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
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/pacientes"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sucesso']) {
          setState(() {
            _pacientes = data['pacientes'] ?? [];
            _loading = false;
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar pacientes: $e");
      setState(() => _loading = false);
    }
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
                  Text("Visão Geral de Pacientes", style: PolifenoisTema.tituloEstilo),
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
                                              validado
                                                ? Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 5), Text("Liberado")])
                                                : ElevatedButton.icon(
                                                    icon: Icon(Icons.key, size: 16),
                                                    label: Text("Liberar Acesso"),
                                                    onPressed: () => _confirmarLiberacao(p['id']),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: PolifenoisTema.azulPrimario,
                                                      foregroundColor: Colors.white,
                                                    ),
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