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
  bool _isLoading = true;
  int _paginaAtual = 1;
  int _totalPaginas = 1;
  int _totalRegistros = 0;
  
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = "";

  @override
  void initState() {
    super.initState();
    _buscarAlimentos();
  }

  Future<void> _buscarAlimentos({int pagina = 1}) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
        "https://polifenois-backend.onrender.com/alimentos-usda?busca=$_termoBusca&pagina=$pagina&limite=50"
      );
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sucesso']) {
          setState(() {
            _alimentos = data['alimentos'];
            _paginaAtual = data['pagina'];
            _totalPaginas = data['totalPaginas'];
            _totalRegistros = data['total'];
            _isLoading = false;
          });
        }
      } else {
        _mostrarErro("Falha ao carregar a base de dados.");
      }
    } catch (e) {
      print("Erro ao buscar alimentos: $e");
      _mostrarErro("Erro de conexão com o servidor.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _pesquisar() {
    setState(() {
      _termoBusca = _buscaController.text;
    });
    _buscarAlimentos(pagina: 1);
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(
        title: Text("Base Nutricional Internacional (USDA)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Consulta de Alimentos e Polifenóis", style: PolifenoisTema.tituloEstilo),
            SizedBox(height: 10),
            Text("Total de registros encontrados: $_totalRegistros", style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 20),
            
            // BARRA DE PESQUISA
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    onSubmitted: (_) => _pesquisar(),
                    decoration: PolifenoisTema.inputDecoracao("Pesquisar alimento em inglês (ex: Apple, Tea, Chocolate)", Icons.search),
                  ),
                ),
                SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: _pesquisar,
                  icon: Icon(Icons.search, color: Colors.white),
                  label: Text("BUSCAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PolifenoisTema.azulPrimario,
                    minimumSize: Size(150, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                )
              ],
            ),
            SizedBox(height: 30),

            // TABELA DE DADOS
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                    : _alimentos.isEmpty
                        ? Center(child: Text("Nenhum alimento encontrado.", style: PolifenoisTema.corpoEstilo))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.grey[200]),
                                      columns: [
                                        DataColumn(label: Text("Código NDB", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("Nome do Alimento (USDA)", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                        DataColumn(label: Text("Polifenóis Totais (mg/100g)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]))),
                                        DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                      ],
                                      rows: _alimentos.map((a) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(a['ndb_no'].toString())),
                                            DataCell(Text(a['nome_en'] ?? 'Desconhecido')),
                                            DataCell(Text("${a['total_polifenois']} mg", style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataCell(
                                              IconButton(
                                                icon: Icon(Icons.edit, color: Colors.orange),
                                                tooltip: "Editar/Traduzir",
                                                onPressed: () {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Módulo de edição em desenvolvimento.")));
                                                },
                                              )
                                            ),
                                          ]
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // CONTROLES DE PAGINAÇÃO
                              Container(
                                padding: EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.arrow_back_ios, size: 18),
                                      onPressed: _paginaAtual > 1 ? () => _buscarAlimentos(pagina: _paginaAtual - 1) : null,
                                    ),
                                    Text("Página $_paginaAtual de $_totalPaginas", style: TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: Icon(Icons.arrow_forward_ios, size: 18),
                                      onPressed: _paginaAtual < _totalPaginas ? () => _buscarAlimentos(pagina: _paginaAtual + 1) : null,
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
              ),
            )
          ],
        ),
      ),
    );
  }
}