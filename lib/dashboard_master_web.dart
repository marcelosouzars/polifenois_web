import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
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
  Uint8List? _fotoPerfilBytes;

  @override
  void initState() {
    super.initState();
    _buscarEstatisticas();
  }

  // =========================================================================
  // LÓGICA DE ALTERAÇÃO DE FOTO COM CONFIRMAÇÃO E GRAVAÇÃO
  // =========================================================================
  Future<void> _selecionarFoto() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        
        // Pergunta se realmente deseja alterar a foto
        bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Alterar Foto de Perfil?"),
            content: Text("Deseja salvar esta nova imagem como sua foto oficial no sistema?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("CANCELAR"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("SALVAR AGORA"),
              ),
            ],
          ),
        );

        if (confirmar == true) {
          setState(() => _carregando = true);
          String base64Foto = base64Encode(bytes);

          final response = await http.put(
            Uri.parse("https://polifenois-backend.onrender.com/atualizar-foto-perfil"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "usuario_id": widget.usuario['id'],
              "foto_base64": base64Foto,
            }),
          );

          if (response.statusCode == 200) {
            setState(() {
              _fotoPerfilBytes = bytes;
              _carregando = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Foto de perfil atualizada com sucesso!"), backgroundColor: Colors.green),
            );
          } else {
            throw Exception("Erro no servidor");
          }
        }
      }
    } catch (e) {
      setState(() => _carregando = false);
      _mostrarErro("Erro ao salvar imagem: $e");
    }
  }

  Future<void> _buscarEstatisticas() async {
    setState(() => _carregando = true);
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/dashboard-master-stats"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _carregando = false;
        });
      } else {
        print("Erro no servidor: ${response.statusCode}");
        setState(() => _carregando = false);
        _mostrarErro("O servidor retornou um erro ao buscar as estatísticas.");
      }
    } catch (e) {
      print("Erro ao conectar: $e");
      setState(() => _carregando = false);
      _mostrarErro("Falha na conexão. Verifique sua internet ou o servidor.");
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  String _v(dynamic valor) {
    if (valor == null) return "0";
    return valor.toString();
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
            color: Color(0xFF1A237E),
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white24,
                            backgroundImage: _fotoPerfilBytes != null 
                              ? MemoryImage(_fotoPerfilBytes!) 
                              : (widget.usuario['foto_perfil_url'] != null && widget.usuario['foto_perfil_url'].toString().length > 100
                                  ? MemoryImage(base64Decode(widget.usuario['foto_perfil_url']))
                                  : null),
                            child: (_fotoPerfilBytes == null && (widget.usuario['foto_perfil_url'] == null || widget.usuario['foto_perfil_url'].toString().length < 100))
                                ? Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _selecionarFoto,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.amber,
                                child: Icon(Icons.camera_alt, size: 15, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text("PAINEL MASTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(widget.usuario['nome'] ?? 'Master', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.analytics, color: Colors.white),
                  title: Text("Estatísticas Gerais", style: TextStyle(color: Colors.white)),
                  onTap: () => _buscarEstatisticas(),
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
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1A237E)),
                  SizedBox(height: 20),
                  Text("Processando...", style: TextStyle(color: Colors.grey[600]))
                ],
              )) 
            : SingleChildScrollView(
                padding: EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Monitoramento Estratégico", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        IconButton(
                          icon: Icon(Icons.refresh, color: Color(0xFF1A237E)), 
                          onPressed: _buscarEstatisticas
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    
                    // LINHA 1: GERAL E SAÚDE
                    Wrap(
                      spacing: 20, runSpacing: 20,
                      children: [
                        _cardKPI("TOTAL GESTANTES", _v(_stats?['total_gestantes']), Icons.pregnant_woman, Colors.blue),
                        _cardKPI("IDADE MÉDIA", "${_v(_stats?['gestacional']?['idade_media'])} anos", Icons.cake, Colors.orange),
                        _cardKPI("SEM REGISTRO", _v(_stats?['engajamento']?['sem_refeicoes']), Icons.no_meals, Colors.red),
                      ],
                    ),
                    
                    SizedBox(height: 40),
                    Text("Acompanhamento Clínico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                    SizedBox(height: 20),
                    
                    // LINHA 2: MÉDICOS E NUTRIS
                    Wrap(
                      spacing: 20, runSpacing: 20,
                      children: [
                        _cardKPI("COM MÉDICO", _v(_stats?['saude']?['com_medico']), Icons.medical_services, Colors.green),
                        _cardKPI("SEM MÉDICO", _v(_stats?['saude']?['sem_medico']), Icons.warning_amber_rounded, Colors.redAccent),
                        _cardKPI("COM NUTRICIONISTA", _v(_stats?['saude']?['com_nutri']), Icons.local_dining, Colors.green),
                        _cardKPI("SEM NUTRICIONISTA", _v(_stats?['saude']?['sem_nutri']), Icons.warning_amber_rounded, Colors.redAccent),
                      ],
                    ),

                    SizedBox(height: 40),
                    Text("Distribuição por Tempo de Gestação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                    SizedBox(height: 20),

                    // LINHA 3: TRIMESTRES
                    Wrap(
                      spacing: 20, runSpacing: 20,
                      children: [
                        _cardTrimestre("1º Trimestre", "Até 13 sem", _v(_stats?['gestacional']?['trimestre1']), Colors.teal),
                        _cardTrimestre("2º Trimestre", "14 a 26 sem", _v(_stats?['gestacional']?['trimestre2']), Colors.indigo),
                        _cardTrimestre("3º Trimestre", "27 sem +", _v(_stats?['gestacional']?['trimestre3']), Colors.purple),
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor, size: 30),
          SizedBox(height: 15),
          Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _cardTrimestre(String titulo, String subtitulo, String valor, Color cor) {
    return Container(
      width: 340,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cor, cor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: cor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
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