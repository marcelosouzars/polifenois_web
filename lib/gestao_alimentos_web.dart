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

  // =========================================================================
  // MODAL PARA INCLUIR OU EDITAR
  // =========================================================================
  void _abrirModalAlimento({Map<String, dynamic>? alimento}) {
    bool isEdicao = alimento != null;
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? (alimento['nome_alimento'] ?? '') : '');
    TextEditingController poliCtrl = TextEditingController(text: isEdicao ? alimento['polifenois_mg_100g'].toString() : '');
    TextEditingController compoundCtrl = TextEditingController(text: isEdicao ? (alimento['compound'] ?? '') : '');
    TextEditingController categoriaCtrl = TextEditingController(text: isEdicao ? (alimento['categoria'] ?? '') : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdicao ? "Editar Registro" : "Novo Registro", style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome do Alimento", Icons.fastfood)),
            SizedBox(height: 15),
            TextField(controller: categoriaCtrl, decoration: PolifenoisTema.inputDecoracao("Categoria / Grupo", Icons.category)),
            SizedBox(height: 15),
            TextField(controller: compoundCtrl, decoration: PolifenoisTema.inputDecoracao("Composto Químico", Icons.biotech)),
            SizedBox(height: 15),
            TextField(controller: poliCtrl, decoration: PolifenoisTema.inputDecoracao("Polifenóis (mg/100g)", Icons.science), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _salvarAlimento(isEdicao ? alimento['codigo_origem'] : null, nomeCtrl.text, poliCtrl.text, compoundCtrl.text, categoriaCtrl.text, !isEdicao);
            },
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            child: Text("SALVAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarAlimento(String? codOrigem, String nome, String poli, String compound, String categoria, bool isNovo) async {
    setState(() => _carregando = true);
    try {
      Uri url = isNovo 
          ? Uri.parse("https://polifenois-backend.onrender.com/base-nutricional")
          : Uri.parse("https://polifenois-backend.onrender.com/base-nutricional/$codOrigem");

      var bodyData = {
        "nome": nome,
        "total_polifenois": poli,
        "compound": compound,
        "categoria": categoria
      };

      if (isNovo) {
        bodyData["origem_dados"] = "BRA"; // Padrão manual
      }

      var response = isNovo 
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData));

      if (response.statusCode == 200) {
        _buscarAlimentos(pagina: _paginaAtual);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Salvo com sucesso!"), backgroundColor: Colors.green));
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  // =========================================================================
  // LÓGICA DE EXCLUSÃO COM TRUQUE DE INTERFACE (OTIMISTA)
  // =========================================================================
  Future<void> _confirmarExclusao(String codOrigem, String nomeAlimento) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmar Exclusão"),
        content: Text("Deseja realmente apagar o registro '$nomeAlimento'? Esta ação não poderá ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _executarExclusaoVisual(codOrigem);
            },
            child: Text("EXCLUIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executarExclusaoVisual(String codOrigem) async {
    // 1. Truque de interface: Some da tela na mesma hora
    setState(() {
      _alimentos.removeWhere((a) => a['codigo_origem'] == codOrigem);
    });

    // 2. Apaga no banco de dados em background
    try {
      final response = await http.delete(Uri.parse("https://polifenois-backend.onrender.com/base-nutricional/$codOrigem"));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Item removido."), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      print("Erro ao excluir no banco: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(title: Text("Super Base Nutricional Global", style: TextStyle(color: Colors.white)), backgroundColor: PolifenoisTema.azulPrimario, iconTheme: IconThemeData(color: Colors.white)),
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
                Expanded(
                  child: TextField(
                    controller: _buscaController, 
                    decoration: PolifenoisTema.inputDecoracao("Buscar por alimento, composto ou categoria...", Icons.search), 
                    onSubmitted: (_) => _buscarAlimentos(pagina: 1)
                  )
                ),
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
                  : _alimentos.isEmpty
                    ? Center(child: Text("Nenhum registro encontrado.", style: PolifenoisTema.corpoEstilo))
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Container(
                                width: double.infinity,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                                  columns: [
                                    DataColumn(label: Text("Origem", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                    DataColumn(label: Text("Código", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                    DataColumn(label: Text("Categoria", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                    DataColumn(label: Text("Nome / Composto", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                    DataColumn(label: Text("Polifenóis", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                    DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                  ],
                                  rows: _alimentos.map((a) {
                                    String exibicaoNome = a['nome_alimento']?.toString() ?? 'N/A';
                                    if (a['compound'] != null && a['compound'].toString().trim().isNotEmpty) {
                                      exibicaoNome += " (${a['compound']})";
                                    }
                                    return DataRow(cells: [
                                      DataCell(Chip(
                                        label: Text(a['origem_dados']?.toString() ?? 'BRA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        backgroundColor: a['origem_dados'] == 'EUR' ? Colors.blue : (a['origem_dados'] == 'USA' ? Colors.red : Colors.green),
                                      )),
                                      DataCell(Text(a['codigo_origem']?.toString() ?? '-')),
                                      DataCell(Text(a['categoria']?.toString() ?? 'Geral', style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic))),
                                      DataCell(Text(exibicaoNome)),
                                      DataCell(Text("${a['polifenois_mg_100g']?.toString() ?? '0'} ${a['units'] ?? 'mg'}")),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit, color: PolifenoisTema.azulPrimario), 
                                              tooltip: "Editar Registro",
                                              onPressed: () => _abrirModalAlimento(alimento: a)
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_forever, color: Colors.red), 
                                              tooltip: "Excluir",
                                              onPressed: () => _confirmarExclusao(a['codigo_origem'], a['nome_alimento'])
                                            ),
                                          ],
                                        )
                                      )
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text("Página $_paginaAtual de $_totalPaginas"),
                                SizedBox(width: 20),
                                ElevatedButton(
                                  onPressed: _paginaAtual > 1 ? () => _buscarAlimentos(pagina: _paginaAtual - 1) : null,
                                  child: Icon(Icons.arrow_back_ios, size: 16),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _paginaAtual < _totalPaginas ? () => _buscarAlimentos(pagina: _paginaAtual + 1) : null,
                                  child: Icon(Icons.arrow_forward_ios, size: 16),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}