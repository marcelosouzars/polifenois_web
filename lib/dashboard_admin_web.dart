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
            _pacientes = data['pacientes'];
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
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(
        title: Text("Vetix Dashboard Clínico", style: TextStyle(color: Colors.white)),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Center(child: Text("Dr(a). ${widget.usuario['nome']}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
          // MENU LATERAL (DRAWER FIXO)
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: PolifenoisTema.azulClaroFundo),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_hospital, size: 50, color: PolifenoisTema.azulPrimario),
                        SizedBox(height: 10),
                        Text("Painel de Controle", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.people, color: PolifenoisTema.azulPrimario),
                  title: Text("Pacientes", style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: true,
                  selectedTileColor: Colors.blue.shade50,
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.restaurant_menu, color: PolifenoisTema.cinzaTexto),
                  title: Text("Relatório Polifenóis"),
                  onTap: () {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Em desenvolvimento...")));
                  },
                ),
              ],
            ),
          ),
          
          // CONTEÚDO PRINCIPAL (TABELA DE PACIENTES)
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Gestantes Cadastradas", style: PolifenoisTema.tituloEstilo),
                  SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: _loading 
                          ? Center(child: CircularProgressIndicator())
                          : _pacientes.isEmpty
                              ? Center(child: Text("Nenhuma paciente cadastrada ainda.", style: PolifenoisTema.corpoEstilo))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.grey.shade100),
                                      columns: [
                                        DataColumn(label: Text("Nome", style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text("CPF", style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text("E-mail", style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text("Idade", style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text("Sem. Gestação", style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text("Status Conta", style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _pacientes.map((p) {
                                        bool validado = p['email_validado'] == true;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(p['nome'] ?? '-')),
                                            DataCell(Text(p['cpf'] ?? '-')),
                                            DataCell(Text(p['email'] ?? '-')),
                                            DataCell(Text(p['idade']?.toString() ?? '-')),
                                            DataCell(Text(p['semana_gestacao']?.toString() ?? '-')),
                                            DataCell(
                                              Chip(
                                                label: Text(validado ? "Validado" : "Pendente", style: TextStyle(color: Colors.white, fontSize: 12)),
                                                backgroundColor: validado ? Colors.green : Colors.orange,
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