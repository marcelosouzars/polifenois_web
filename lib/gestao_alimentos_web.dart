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
          "https://polifenois-backend.onrender.com/base-nutricional?busca=${_buscaController.text}&pagina=$pagina&origem=$_filtroOrigem");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _alimentos = data['alimentos'] ?? [];
          _paginaAtual = data['pagina'];
          _totalPaginas = data['totalPaginas'];
          _carregando = false;
        });
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      print("Erro ao carregar alimentos: $e");
      setState(() => _carregando = false);
    }
  }

  void _abrirModalAlimento({Map<String, dynamic>? alimento}) {
    bool isEdicao = alimento != null;
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? (alimento['nome_alimento'] ?? '') : '');
    TextEditingController poliCtrl = TextEditingController(text: isEdicao ? alimento['polifenois_mg_100g'].toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdicao ? "Editar Alimento" : "Novo Alimento Brasileiro"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome", Icons.fastfood)),
            SizedBox(height: 15),
            TextField(controller: poliCtrl, decoration: PolifenoisTema.inputDecoracao("Polifenóis (mg/100g)", Icons.science), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          if (isEdicao)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _excluirAlimento(alimento['codigo_origem']);
              },
              child: Text("EXCLUIR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _salvarAlimento(isEdicao ? alimento['codigo_origem'] : null, nomeCtrl.text, poliCtrl.text, !isEdicao);
            },
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            child: Text("SALVAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarAlimento(String? codOrigem, String nome, String poli, bool isNovo) async {
    setState(() => _carregando = true);
    try {
      Uri url = isNovo 
          ? Uri.parse("https://polifenois-backend.onrender.com/base-nutricional")
          : Uri.parse("https://polifenois-backend.onrender.com/base-nutricional/$codOrigem");

      var response = isNovo 
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"nome": nome, "total_polifenois": poli, "origem_dados": "BRA"}))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"nome": nome, "total_polifenois": poli}));

      if (response.statusCode == 200) {
        _buscarAlimentos(pagina: _paginaAtual);
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _excluirAlimento(String codOrigem) async {
    // Truque visual: Remove da tela instantaneamente
    setState(() {
      _alimentos.removeWhere((a) => a['codigo_origem'] == codOrigem);
    });

    // Avisa o backend por baixo dos panos
    try {
      await http.delete(Uri.parse("https://polifenois-backend.onrender.com/base-nutricional/$codOrigem"));
    } catch (e) {
      print("Erro ao excluir no banco: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(title: Text("Super Base Nutricional", style: TextStyle(color: Colors.white)), backgroundColor: PolifenoisTema.azulPrimario, iconTheme: IconThemeData(color: Colors.white)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirModalAlimento(),
        backgroundColor: PolifenoisTema.azulPrimario,
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: _buscaController, decoration: PolifenoisTema.inputDecoracao("Buscar por alimento...", Icons.search))),
                SizedBox(width: 15),
                DropdownButton<String>(
                  value: _filtroOrigem,
                  items: ["TODOS", "EUR", "USA", "BRA"].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) { setState(() => _filtroOrigem = v!); _buscarAlimentos(); },
                ),
                SizedBox(width: 15),
                ElevatedButton(
                  onPressed: () => _buscarAlimentos(pagina: 1), 
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20)),
                  child: Text("BUSCAR", style: TextStyle(color: Colors.white))
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: _carregando 
                  ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario)) 
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Container(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                          columns: [
                            DataColumn(label: Text("Origem", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                            DataColumn(label: Text("Código", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                            DataColumn(label: Text("Nome do Alimento", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                            DataColumn(label: Text("Polifenóis (mg)", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                            DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                          ],
                          rows: _alimentos.map((a) => DataRow(cells: [
                            DataCell(Chip(
                              label: Text(a['origem_dados']?.toString() ?? 'BRA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: a['origem_dados'] == 'EUR' ? Colors.blue : (a['origem_dados'] == 'USA' ? Colors.red : Colors.green),
                            )),
                            DataCell(Text(a['codigo_origem']?.toString() ?? '-')),
                            DataCell(Text(a['nome_alimento']?.toString() ?? 'N/A')),
                            DataCell(Text(a['polifenois_mg_100g']?.toString() ?? '0')),
                            DataCell(IconButton(icon: Icon(Icons.edit, color: PolifenoisTema.azulPrimario), onPressed: () => _abrirModalAlimento(alimento: a)))
                          ])).toList(),
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