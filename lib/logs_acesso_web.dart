import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'tema_padrao_web.dart';

class LogsAcessoWeb extends StatefulWidget {
  @override
  _LogsAcessoWebState createState() => _LogsAcessoWebState();
}

class _LogsAcessoWebState extends State<LogsAcessoWeb> {
  List<dynamic> _logs = [];
  List<dynamic> _logsFiltrados = [];
  bool _carregando = true;
  final TextEditingController _busca = TextEditingController();
  String _filtroPlataforma = 'TODOS';

  @override
  void initState() {
    super.initState();
    _carregarLogs();
  }

  Future<void> _carregarLogs() async {
    setState(() => _carregando = true);
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/logs-acesso"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _logs = data['logins'] ?? [];
        });
        _aplicarFiltro();
      }
    } catch (e) {
      print("Erro ao carregar logs: $e");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _aplicarFiltro() {
    setState(() {
      _logsFiltrados = _logs.where((l) {
        if (_busca.text.isNotEmpty &&
            !(l['nome_usuario'] ?? '').toString().toLowerCase().contains(_busca.text.toLowerCase())) {
          return false;
        }
        if (_filtroPlataforma != 'TODOS' && (l['plataforma'] ?? '') != _filtroPlataforma) return false;
        return true;
      }).toList();
    });
  }

  String _formatarDataHora(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) { return '-'; }
  }

  String _formatarHora(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('HH:mm:ss').format(dt);
    } catch (e) { return '-'; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text("Logins do Sistema"),
        backgroundColor: Color(0xFF1A237E),
      ),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Histórico de Acessos (Web e App Mobile)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _carregarLogs,
                  icon: Icon(Icons.refresh, size: 18, color: Colors.white),
                  label: Text("ATUALIZAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A237E)),
                ),
              ],
            ),
            SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _busca,
                        onChanged: (_) => _aplicarFiltro(),
                        decoration: PolifenoisTema.inputDecoracao("Buscar por nome de usuário", Icons.search),
                      ),
                    ),
                    SizedBox(width: 16),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _filtroPlataforma,
                        decoration: PolifenoisTema.inputDecoracao("Plataforma", Icons.devices),
                        items: ['TODOS', 'WEB', 'APP MOBILE']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _filtroPlataforma = v ?? 'TODOS');
                          _aplicarFiltro();
                        },
                      ),
                    ),
                    Spacer(),
                    Text("${_logsFiltrados.length} de ${_logs.length} registros", style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: _carregando
                    ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                    : _logsFiltrados.isEmpty
                        ? Center(child: Text("Nenhum login registrado.", style: PolifenoisTema.corpoEstilo))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                                columns: [
                                  DataColumn(label: Text("Usuário", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                  DataColumn(label: Text("Tipo", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                  DataColumn(label: Text("Data", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                  DataColumn(label: Text("Hora", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                  DataColumn(label: Text("IP", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                  DataColumn(label: Text("Plataforma", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                ],
                                rows: _logsFiltrados.map((l) {
                                  final plataforma = (l['plataforma'] ?? 'WEB').toString();
                                  return DataRow(cells: [
                                    DataCell(Text(l['nome_usuario'] ?? 'Desconhecido')),
                                    DataCell(Text((l['tipo_usuario'] ?? '-').toString().toUpperCase())),
                                    DataCell(Text(_formatarDataHora(l['data_hora']))),
                                    DataCell(Text(_formatarHora(l['data_hora']))),
                                    DataCell(Text(l['ip_origem'] ?? '-')),
                                    DataCell(
                                      Chip(
                                        label: Text(plataforma, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        backgroundColor: plataforma == 'APP MOBILE' ? Colors.deepPurple : Colors.blueGrey,
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}