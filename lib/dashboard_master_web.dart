import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'tema_padrao_web.dart';
import 'login_web.dart';
import 'gestao_alimentos_web.dart';

class DashboardMasterWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  DashboardMasterWeb({required this.usuario});

  @override
  _DashboardMasterWebState createState() => _DashboardMasterWebState();
}

class _DashboardMasterWebState extends State<DashboardMasterWeb> {
  int _indiceMenu = 0; 
  Map<String, dynamic>? _stats;
  List<dynamic> _pacientes = [];
  bool _carregandoStats = true;
  bool _carregandoPacientes = true;
  Uint8List? _fotoPerfilBytes;

  @override
  void initState() {
    super.initState();
    _buscarEstatisticas();
  }

  void _mudarAba(int indice) {
    setState(() => _indiceMenu = indice);
    if (indice == 0) {
      _buscarEstatisticas();
    } else if (indice == 1) {
      _carregarPacientes();
    }
  }

  void _mostrarAvisoDesenvolvimento() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Módulo em Desenvolvimento", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
        content: Text("O módulo de configurações estará disponível nas próximas atualizações do sistema."),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            child: Text("OK", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _buscarEstatisticas() async {
    setState(() => _carregandoStats = true);
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/dashboard-master-stats"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _carregandoStats = false;
        });
      } else {
        setState(() => _carregandoStats = false);
      }
    } catch (e) {
      setState(() => _carregandoStats = false);
    }
  }

  // A GRANDE CORREÇÃO: Bloco finally adicionado para forçar a parada do loading
  Future<void> _carregarPacientes() async {
    setState(() => _carregandoPacientes = true);
    try {
      final response = await http.get(Uri.parse("https://polifenois-backend.onrender.com/pacientes"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sucesso']) {
          setState(() {
            _pacientes = data['pacientes'] ?? [];
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar pacientes: $e");
    } finally {
      if (mounted) setState(() => _carregandoPacientes = false);
    }
  }

  void _confirmarLiberacao(int idPaciente) {
    final TextEditingController _senhaAdminController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmar Liberação", style: TextStyle(color: PolifenoisTema.azulPrimario)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Para liberar o acesso desta paciente, digite sua senha de administrador:"),
            SizedBox(height: 15),
            TextField(
              controller: _senhaAdminController,
              obscureText: true,
              decoration: PolifenoisTema.inputDecoracao("Sua Senha", Icons.lock),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
            onPressed: () => _executarLiberacao(idPaciente, _senhaAdminController.text),
            child: Text("CONFIRMAR E LIBERAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executarLiberacao(int idPaciente, String senha) async {
    try {
      final response = await http.post(
        Uri.parse("https://polifenois-backend.onrender.com/validar-manual"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id_paciente": idPaciente,
          "id_admin": widget.usuario['id'],
          "senha_admin": senha
        }),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context);
        _carregarPacientes(); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Acesso liberado com sucesso!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: Senha incorreta."), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Erro ao validar: $e");
    }
  }

  Future<void> _selecionarFoto() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 85);
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Alterar Foto?"),
            content: Text("Deseja salvar esta imagem como sua foto oficial?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCELAR")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("SALVAR AGORA")),
            ],
          ),
        );

        if (confirmar == true) {
          String base64Foto = base64Encode(bytes);
          final response = await http.put(
            Uri.parse("https://polifenois-backend.onrender.com/atualizar-foto-perfil"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"usuario_id": widget.usuario['id'], "foto_base64": base64Foto}),
          );

          if (response.statusCode == 200) {
            setState(() { _fotoPerfilBytes = bytes; });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Foto atualizada!"), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) { print(e); }
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
                            bottom: 0, right: 0,
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
                  leading: Icon(Icons.analytics, color: _indiceMenu == 0 ? Colors.white : Colors.white54),
                  title: Text("Estatísticas Gerais", style: TextStyle(color: _indiceMenu == 0 ? Colors.white : Colors.white54, fontWeight: _indiceMenu == 0 ? FontWeight.bold : FontWeight.normal)),
                  onTap: () => _mudarAba(0),
                  tileColor: _indiceMenu == 0 ? Colors.white.withOpacity(0.1) : Colors.transparent,
                ),
                ListTile(
                  leading: Icon(Icons.people, color: _indiceMenu == 1 ? Colors.white : Colors.white54),
                  title: Text("Lista de Gestantes", style: TextStyle(color: _indiceMenu == 1 ? Colors.white : Colors.white54, fontWeight: _indiceMenu == 1 ? FontWeight.bold : FontWeight.normal)),
                  onTap: () => _mudarAba(1),
                  tileColor: _indiceMenu == 1 ? Colors.white.withOpacity(0.1) : Colors.transparent,
                ),
                ListTile(
                  leading: Icon(Icons.kitchen, color: Colors.white54),
                  title: Text("Base Global de Alimentos", style: TextStyle(color: Colors.white54)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => GestaoAlimentosWeb(usuario: widget.usuario)));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white54),
                  title: Text("Configurações", style: TextStyle(color: Colors.white54)),
                  onTap: () => _mostrarAvisoDesenvolvimento(),
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
          
          Expanded(
            child: _indiceMenu == 0 ? _buildEstatisticas() : _buildListaGestantes(),
          ),
        ],
      ),
    );
  }

  Widget _buildEstatisticas() {
    if (_carregandoStats) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)));
    }
    return SingleChildScrollView(
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
    );
  }

  Widget _buildListaGestantes() {
    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Gestão de Pacientes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              IconButton(icon: Icon(Icons.refresh, color: Color(0xFF1A237E)), onPressed: _carregarPacientes),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: _carregandoPacientes
                  ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                  : _pacientes.isEmpty
                      ? Center(child: Text("Nenhuma paciente encontrada.", style: PolifenoisTema.corpoEstilo))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                              columns: [
                                DataColumn(label: Text("Nome", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("CPF", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("E-mail", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Sem. Gestação", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                              ],
                              rows: _pacientes.map((p) {
                                bool validado = p['email_validado'] == true;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(p['nome'] ?? 'Sem nome')),
                                    DataCell(Text(p['cpf'] ?? '-')),
                                    DataCell(Text(p['email'] ?? '-')),
                                    DataCell(Text(p['semana_gestacao']?.toString() ?? '0')),
                                    DataCell(
                                      Chip(
                                        label: Text(validado ? "Verificado" : "Pendente", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        backgroundColor: validado ? Colors.green.shade600 : Colors.orange.shade600,
                                      )
                                    ),
                                    DataCell(
                                      validado
                                        ? Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 5), Text("Liberado")])
                                        : ElevatedButton.icon(
                                            icon: Icon(Icons.key, size: 16),
                                            label: Text("Liberar Acesso"),
                                            onPressed: () => _confirmarLiberacao(p['id']),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: PolifenoisTema.azulPrimario,
                                              foregroundColor: Colors.white,
                                            ),
                                          )
                                    ),
                                  ]
                                );
                              }).toList(),
                            ),
                          ),
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
        gradient: LinearGradient(colors: [cor, cor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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