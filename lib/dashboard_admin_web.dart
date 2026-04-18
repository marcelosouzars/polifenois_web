import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'login_web.dart';

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

  @override
  Widget build(BuildContext context) {
    // Tratamento seguro do nome para evitar Tela Vermelha
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
                        Text("Painel Master", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold, fontSize: 18)),
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
                                        DataColumn(label: Text("Status de Cadastro", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
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