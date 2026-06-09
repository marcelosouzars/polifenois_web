import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
        bodyData["origem_dados"] = "BRA"; 
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
    setState(() {
      _alimentos.removeWhere((a) => a['codigo_origem'] == codOrigem);
    });

    try {
      final response = await http.delete(Uri.parse("https://polifenois-backend.onrender.com/base-nutricional/$codOrigem"));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Item removido."), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      print("Erro ao excluir no banco: $e");
    }
  }

  // =========================================================================
  // GERAÇÃO DE PDF E IMPRESSÃO (CORRIGIDO PARA MULTIPAGE)
  // =========================================================================
  Future<void> _imprimirLista() async {
    final pdf = pw.Document();

    // A MÁGICA: Usar MultiPage faz o Flutter criar páginas infinitas automaticamente
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text("Relatório - Base Global de Alimentos", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            pw.Text("Gerado pelo Sistema Polifenóis Vetix", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Origem', 'Código', 'Categoria', 'Nome / Composto', 'Polifenóis'],
              data: _alimentos.map((a) {
                String nome = a['nome_alimento']?.toString() ?? 'N/A';
                if (a['compound'] != null && a['compound'].toString().trim().isNotEmpty) {
                  nome += " (${a['compound']})";
                }
                return [
                  a['origem_dados']?.toString() ?? 'BRA',
                  a['codigo_origem']?.toString() ?? '-',
                  a['categoria']?.toString() ?? 'Geral',
                  nome,
                  "${a['polifenois_mg_100g']?.toString() ?? '0'} ${a['units'] ?? 'mg'}"
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Alimentos_Vetix.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(title: Text("Base Global de Alimentos", style: TextStyle(color: Colors.white)), backgroundColor: PolifenoisTema.azulPrimario, iconTheme: IconThemeData(color: Colors.white)),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3, 
                  child: TextField(
                    controller: _buscaController, 
                    decoration: PolifenoisTema.inputDecoracao("Buscar por alimento, composto ou categoria...", Icons.search), 
                    onSubmitted: (_) => _buscarAlimentos(pagina: 1)
                  )
                ),
                SizedBox(width: 15),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filtroOrigem,
                      items: ["TODOS", "EUR", "USA", "BRA"].map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) { setState(() => _filtroOrigem = v!); _buscarAlimentos(); },
                    ),
                  ),
                ),
                SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () => _buscarAlimentos(pagina: 1), 
                  icon: Icon(Icons.search, color: Colors.white, size: 18),
                  label: Text("BUSCAR", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20)),
                ),
                SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () => _abrirModalAlimento(), 
                  icon: Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                  label: Text("INCLUIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20)),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _imprimirLista,
                                  icon: Icon(Icons.print, size: 18, color: Colors.white),
                                  label: Text("IMPRIMIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                  ),
                                ),
                                Row(
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