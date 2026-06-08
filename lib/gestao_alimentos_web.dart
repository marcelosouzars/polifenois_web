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
  TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buscarAlimentos();
  }

  // =====================================================================
  // BUSCAR ALIMENTOS (READ)
  // =====================================================================
  Future<void> _buscarAlimentos({int pagina = 1}) async {
    setState(() => _carregando = true);
    try {
      final url = Uri.parse(
          "https://polifenois-backend.onrender.com/alimentos-usda?busca=${_buscaController.text}&pagina=$pagina");
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

  // =====================================================================
  // MODAL PARA CRIAR / EDITAR (CREATE & UPDATE)
  // =====================================================================
  void _abrirModalAlimento({Map<String, dynamic>? alimento}) {
    bool isEdicao = alimento != null;
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? alimento['nome_en'] : '');
    TextEditingController poliCtrl = TextEditingController(text: isEdicao ? alimento['total_polifenois'].toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdicao ? "Editar Alimento" : "Novo Alimento", style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: PolifenoisTema.inputDecoracao("Nome do Alimento", Icons.fastfood),
            ),
            SizedBox(height: 15),
            TextField(
              controller: poliCtrl,
              decoration: PolifenoisTema.inputDecoracao("Total de Polifenóis (mg/100g)", Icons.science),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            onPressed: () async {
              if (nomeCtrl.text.isEmpty) return;
              Navigator.pop(context);
              
              if (isEdicao) {
                await _salvarAlimento(alimento['ndb_no'], nomeCtrl.text, poliCtrl.text, false);
              } else {
                await _salvarAlimento(null, nomeCtrl.text, poliCtrl.text, true);
              }
            },
            child: Text("SALVAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // REQUISIÇÕES DE SALVAR (POST / PUT)
  // =====================================================================
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Alimento salvo com sucesso!"), backgroundColor: Colors.green));
        _buscarAlimentos(pagina: _paginaAtual);
      }
    } catch (e) {
      print("Erro ao salvar: $e");
      setState(() => _carregando = false);
    }
  }

  // =====================================================================
  // EXCLUIR ALIMENTO (DELETE) - COM UX OTIMIZADA (TRUQUE VISUAL)
  // =====================================================================
  Future<void> _confirmarExclusao(String ndbNo, String nome) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Excluir Alimento?"),
        content: Text("Tem certeza que deseja apagar '$nome' do banco de dados? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Fecha a modal de confirmação
              
              // TRUQUE DE UX: Remoção otimista da tela imediatamente
              setState(() {
                _alimentos.removeWhere((item) => item['ndb_no'] == ndbNo);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Excluído com sucesso!"), backgroundColor: Colors.redAccent, duration: Duration(seconds: 2))
              );

              // Comunicação em Background com o Banco de Dados
              try {
                final res = await http.delete(Uri.parse("https://polifenois-backend.onrender.com/alimentos-usda/$ndbNo"));
                if (res.statusCode != 200) {
                  // Se falhar no servidor, avisa e recarrega a tabela para garantir consistência visual x banco
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro de sincronização. Recarregando..."), backgroundColor: Colors.orange));
                  _buscarAlimentos(pagina: _paginaAtual);
                }
              } catch (e) {
                print("Erro ao excluir no servidor: $e");
                _buscarAlimentos(pagina: _paginaAtual);
              }
            },
            child: Text("EXCLUIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(
        title: Text("Base de Alimentos Nutricionais", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: PolifenoisTema.azulPrimario,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            // BARRA SUPERIOR: BUSCA E BOTÃO NOVO
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    decoration: PolifenoisTema.inputDecoracao("Pesquisar alimento por nome...", Icons.search),
                    onSubmitted: (_) => _buscarAlimentos(pagina: 1),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _buscarAlimentos(pagina: 1),
                  icon: Icon(Icons.search, color: Colors.white),
                  label: Text("BUSCAR", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _abrirModalAlimento(),
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text("NOVO ALIMENTO", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                ),
              ],
            ),
            SizedBox(height: 30),

            // TABELA DE DADOS
            Expanded(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: _carregando
                    ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                    : _alimentos.isEmpty
                        ? Center(child: Text("Nenhum alimento encontrado.", style: PolifenoisTema.corpoEstilo))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.grey.shade100),
                                    columns: [
                                      DataColumn(label: Text("Código (NDB)", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                      DataColumn(label: Text("Nome do Alimento", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                      DataColumn(label: Text("Total Polifenóis (mg)", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                      DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                    ],
                                    rows: _alimentos.map((alimento) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(alimento['ndb_no'] ?? '')),
                                          DataCell(Text(alimento['nome_en'] ?? '')),
                                          DataCell(Text(alimento['total_polifenois']?.toString() ?? '0')),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.edit, color: Colors.orange),
                                                  tooltip: "Editar",
                                                  onPressed: () => _abrirModalAlimento(alimento: alimento),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete, color: Colors.red),
                                                  tooltip: "Excluir",
                                                  onPressed: () => _confirmarExclusao(alimento['ndb_no'], alimento['nome_en']),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ]
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              // CONTROLES DE PAGINAÇÃO
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