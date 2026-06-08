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
  String _filtroOrigem = "TODOS";
  TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buscarAlimentos();
  }

  Future<void> _buscarAlimentos({int pagina = 1}) async {
    setState(() => _carregando = true);
    try {
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

  void _abrirModalAlimento({Map<String, dynamic>? alimento}) {
    bool isEdicao = alimento != null;
    // Ajustado para os nomes corretos do seu banco atual:
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? (alimento['nome_alimento'] ?? '') : '');
    TextEditingController poliCtrl = TextEditingController(text: isEdicao ? alimento['polifenois_mg_100g'].toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdicao ? "Editar Alimento" : "Novo Alimento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome", Icons.fastfood)),
            SizedBox(height: 15),
            TextField(controller: poliCtrl, decoration: PolifenoisTema.inputDecoracao("Polifenóis (mg/100g)", Icons.science), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _salvarAlimento(isEdicao ? alimento['codigo_origem'] : null, nomeCtrl.text, poliCtrl.text, !isEdicao);
            },
            child: Text("SALVAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarAlimento(String? codOrigem, String nome, String poli, bool isNovo) async {
    setState(() => _carregando = true);
    try {
      // Nota: Certifique-se que sua rota PUT no backend aceite 'codigo_origem'
      Uri url = isNovo 
          ? Uri.parse("https://polifenois-backend.onrender.com/alimentos-usda")
          : Uri.parse("https://polifenois-backend.onrender.com/alimentos-usda/$codOrigem");

      var response = isNovo 
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"nome": nome, "polifenois": poli}))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"nome": nome, "polifenois": poli}));

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
      appBar: AppBar(title: Text("Base de Alimentos - Super Base"), backgroundColor: PolifenoisTema.azulPrimario),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
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
                child: _carregando ? Center(child: CircularProgressIndicator()) : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text("Origem")),
                      DataColumn(label: Text("Código")),
                      DataColumn(label: Text("Nome")),
                      DataColumn(label: Text("Polifenóis")),
                      DataColumn(label: Text("Ações")),
                    ],
                    rows: _alimentos.map((a) => DataRow(cells: [
                      DataCell(Chip(label: Text(a['origem_dados'] ?? 'N/A'))),
                      DataCell(Text(a['codigo_origem']?.toString() ?? '')),
                      DataCell(Text(a['nome_alimento'] ?? '')),
                      DataCell(Text(a['polifenois_mg_100g']?.toString() ?? '0')),
                      DataCell(IconButton(icon: Icon(Icons.edit), onPressed: () => _abrirModalAlimento(alimento: a)))
                    ])).toList(),
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