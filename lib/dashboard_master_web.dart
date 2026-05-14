import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tema_padrao_web.dart';
import 'login_web.dart';

class DashboardMasterWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  DashboardMasterWeb({required this.usuario});

  @override
  _DashboardMasterWebState createState() => _DashboardMasterWebState();
}

class _DashboardMasterWebState extends State<DashboardMasterWeb> {
  Map<String, dynamic>? _stats;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarEstatisticas();
  }

  Future<void> _buscarEstatisticas() async {
    setState(() => _carregando = true);
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/dashboard-master-stats"));
      if (res.statusCode == 200) {
        setState(() => _stats = jsonDecode(res.body));
      }
    } catch (e) {
      print("Erro ao buscar KPIs: $e");
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F7F6),
      body: Row(
        children: [
          // SIDEBAR DO MASTER
          Container(
            width: 280,
            color: Color(0xFF1A237E), // Azul mais escuro para o Master
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings, size: 60, color: Colors.white),
                      SizedBox(height: 10),
                      Text("PAINEL MASTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(widget.usuario['nome'], style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.analytics, color: Colors.white),
                  title: Text("Estatísticas Gerais", style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white70),
                  title: Text("Lista de Gestantes", style: TextStyle(color: Colors.white70)),
                  onTap: () {},
                ),
                Spacer(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.redAccent),
                  title: Text("Sair", style: TextStyle(color: Colors.redAccent)),
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb())),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          
          // CONTEÚDO PRINCIPAL
          Expanded(
            child: _carregando 
            ? Center(child: CircularProgressIndicator()) 
            : SingleChildScrollView(
                padding: EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Monitoramento Estratégico", style: PolifenoisTema.tituloEstilo),
                        IconButton(icon: Icon(Icons.refresh), onPressed: _buscarEstatisticas),
                      ],
                    ),
                    SizedBox(height: 30),
                    
                    // LINHA 1: GERAL E SAÚDE
                    Wrap(
                      spacing: 20, runSpacing: 20,
                      children: [
                        _cardKPI("TOTAL GESTANTES", _stats?['total_gestantes']?.toString() ?? '0', Icons.pregnant_woman, Colors.blue),
                        _cardKPI("IDADE MÉDIA", "${_stats?['gestacional']?['idade_media']} anos", Icons.cake, Colors.orange),
                        _cardKPI("SEM REGISTRO", _stats?['engajamento']?['sem_refeicoes']?.toString() ?? '0', Icons.no_meals, Colors.red),
                      ],
                    ),
                    
                    SizedBox(height: 40),
                    Text("Acompanhamento Clínico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    
                    // LINHA 2: MÉDICOS E NUTRIS
                    Wrap(
                      spacing: 20, runSpacing: 20,
                      children: [
                        _cardKPI("COM MÉDICO", _stats?['saude']?['com_medico']?.toString() ?? '0', Icons.medical_services, Colors.green),
                        _cardKPI("SEM MÉDICO", _stats?['saude']?['sem_medico']?.toString() ?? '0', Icons.warning, Colors.redAccent),
                        _cardKPI("COM NUTRICIONISTA", _stats?['saude']?['com_nutri']?.toString() ?? '0', Icons.local_dining, Colors.green),
                        _cardKPI("SEM NUTRICIONISTA", _stats?['saude']?['sem_nutri']?.toString() ?? '0', Icons.warning, Colors.redAccent),
                      ],
                    ),

                    SizedBox(height: 40),
                    Text("Distribuição por Tempo de Gestação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),

                    // LINHA 3: TRIMESTRES
                    Wrap(
                      spacing: 20, runSpacing: 20,
                      children: [
                        _cardTrimestre("1º Trimestre", "Até 13 sem", _stats?['gestacional']?['trimestre1']?.toString() ?? '0', Colors.teal),
                        _cardTrimestre("2º Trimestre", "14 a 26 sem", _stats?['gestacional']?['trimestre2']?.toString() ?? '0', Colors.indigo),
                        _cardTrimestre("3º Trimestre", "27 sem +", _stats?['gestacional']?['trimestre3']?.toString() ?? '0', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }

  Widget _cardKPI(String label, String valor, IconData icon, Color cor) {
    return Container(
      width: 250,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor, size: 30),
          SizedBox(height: 15),
          Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _cardTrimestre(String titulo, String subtitulo, String valor, Color cor) {
    return Container(
      width: 340,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cor, cor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(subtitulo, style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Text(valor, style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}