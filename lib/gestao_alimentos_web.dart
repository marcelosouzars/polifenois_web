import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';

class GestaoAlimentosWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  GestaoAlimentosWeb({required this.usuario});

  @override
  _GestaoAlimentosWebState createState() => _GestaoAlimentosWebState();
}

class _GestaoAlimentosWebState extends State<GestaoAlimentosWeb> {
  List<dynamic> _alimentos = [];
  bool _carregando = true;
  int _paginaAtual = 1;
  int _totalPaginas = 1;
  String _filtroOrigem = "TODOS"; // Novo filtro de origem
  TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buscarAlimentos();
  }

  Future<void> _buscarAlimentos({int pagina = 1}) async {
    setState(() => _carregando = true);
    try {
      // Agora enviamos o filtro de origem para o Backend
      final url = Uri.parse(
          "https://polifenois-backend.onrender.com/alimentos-usda?busca=${_buscaController.text}&pagina=$pagina&origem=$_filtroOrigem");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _alimentos = data['alimentos'] ?? [];
          _paginaAtual = data['pagina'];
          _totalPaginas = data['totalPaginas'];
          _carregando = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar alimentos: $e");
      setState(() => _carregando = false);
    }
  }

  // MODAL DE EDIÇÃO (MANTIDO)
  void _abrirModalAlimento({Map<String, dynamic>? alimento}) {
    bool isEdicao = alimento != null;
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? alimento['nome_en'] : '');
    TextEditingController poliCtrl = TextEditingController(text: isEdicao ? alimento['total_polifenois'].toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdicao ? "Editar Alimento" : "Novo Alimento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome", Icons.fastfood)),
            SizedBox(height: 15),
            TextField(controller: poliCtrl, decoration: PolifenoisTema.inputDecoracao("Polifenóis (mg)", Icons.science), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _salvarAlimento(isEdicao ? alimento['ndb_no'] : null, nomeCtrl.text, poliCtrl.text, !isEdicao);
            },
            child: Text("SALVAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarAlimento(String? ndbNo, String nome, String poli, bool isNovo) async {
    setState(() => _carregando = true);
    try {
      Uri url = isNovo 
          ? Uri.parse("https://polifenois-backend.onrender.com/alimentos-usda")
          : Uri.parse("https://polifenois-backend.onrender.com/alimentos-usda/$ndbNo");

      var response = isNovo 
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"nome": nome, "total_polifenois": poli}))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"nome": nome, "total_polifenois": poli}));

      if (response.statusCode == 200) {
        _buscarAlimentos(pagina: _paginaAtual);
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(title: Text("Base de Alimentos"), backgroundColor: PolifenoisTema.azulPrimario),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            // BARRA DE FILTROS E BUSCA
            Row(
              children: [
                Expanded(child: TextField(controller: _buscaController, decoration: PolifenoisTema.inputDecoracao("Buscar...", Icons.search))),
                SizedBox(width: 15),
                DropdownButton<String>(
                  value: _filtroOrigem,
                  items: ["TODOS", "EUR", "USA", "BRA"].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) { setState(() => _filtroOrigem = v!); _buscarAlimentos(); },
                ),
                SizedBox(width: 15),
                ElevatedButton(onPressed: () => _buscarAlimentos(pagina: 1), child: Text("BUSCAR")),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: Card(
                child: _carregando ? Center(child: CircularProgressIndicator()) : DataTable(
                  columns: [
                    DataColumn(label: Text("Origem")),
                    DataColumn(label: Text("Nome")),
                    DataColumn(label: Text("Polifenóis")),
                    DataColumn(label: Text("Ações")),
                  ],
                  rows: _alimentos.map((a) => DataRow(cells: [
                    DataCell(Chip(label: Text(a['origem_dados'] ?? 'N/A'))),
                    DataCell(Text(a['nome_alimento'] ?? a['nome_en'] ?? '')),
                    DataCell(Text(a['total_polifenois']?.toString() ?? '0')),
                    DataCell(IconButton(icon: Icon(Icons.edit), onPressed: () => _abrirModalAlimento(alimento: a)))
                  ])).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}