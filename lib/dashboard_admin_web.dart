//
// DASHBOARD_ADMIN_WEB.DART
//
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tema_padrao_web.dart';
import 'login_web.dart';
import 'gestao_alimentos_web.dart';

class DashboardAdminWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;

  DashboardAdminWeb({required this.usuario});

  @override
  _DashboardAdminWebState createState() => _DashboardAdminWebState();
}

class _DashboardAdminWebState extends State<DashboardAdminWeb> {
  List<dynamic> _pacientes = [];
  bool _loading = true;
  String _unidade = 'mg';

  @override
  void initState() {
    super.initState();
    _carregarPacientes();
    _carregarUnidade();
  }

  Future<void> _carregarUnidade() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _unidade = prefs.getString('unidade_polifenois') ?? 'mg');
  }

  Future<void> _selecionarUnidade(String unidade, StateSetter? setModalState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unidade_polifenois', unidade);
    setState(() => _unidade = unidade);
    if (setModalState != null) setModalState(() {});
  }

  String _formatarPolifenois(dynamic valorMg) {
    double valor = 0;
    if (valorMg is num) {
      valor = valorMg.toDouble();
    } else {
      valor = double.tryParse(valorMg?.toString() ?? '0') ?? 0;
    }
    if (_unidade == 'g') {
      return "${(valor / 1000).toStringAsFixed(3)} g";
    }
    return "${valor.toStringAsFixed(1)} mg";
  }

  // Mantido como constante local de UI (espelha LIMITE_ADEQUADO_MG do backend).
  // Se o valor de referência mudar no backend, atualizar aqui também.
  static const double LIMITE_ADEQUADO_MG_UI = 1000;

  Widget _graficoLinhaConsumo(List<dynamic> diasAgrupadosDesc) {
    // O backend devolve do mais recente pro mais antigo; pro gráfico de linha
    // (esquerda = mais antigo, direita = hoje) precisamos inverter a ordem.
    // Limitamos aos últimos 30 dias com registro pra não poluir o desenho.
    final dias = diasAgrupadosDesc.reversed.toList();
    final serie = dias.length > 30 ? dias.sublist(dias.length - 30) : dias;

    final valores = serie.map((d) => (double.tryParse(d['total_polifenois'].toString()) ?? 0)).toList();
    final maiorValor = valores.isEmpty ? 0.0 : valores.reduce((a, b) => a > b ? a : b);
    double escalaMax = (maiorValor > LIMITE_ADEQUADO_MG_UI ? maiorValor * 1.15 : LIMITE_ADEQUADO_MG_UI * 1.25);
    if (escalaMax <= 0) escalaMax = LIMITE_ADEQUADO_MG_UI * 1.25;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Evolução do Consumo Diário", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.blueGrey.shade800)),
              Spacer(),
              Container(width: 16, height: 2, color: Colors.red.shade300),
              SizedBox(width: 4),
              Text("Limite de referência (${_formatarPolifenois(LIMITE_ADEQUADO_MG_UI)})", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rótulos do eixo Y como Text normal (evita usar TextPainter/dart:ui dentro do painter)
              SizedBox(
                width: 42,
                height: 200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(escalaMax.toStringAsFixed(0), style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                    Text((escalaMax / 2).toStringAsFixed(0), style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                    Text("0", style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LinhaConsumoPainterAdmin(dias: serie, limite: LIMITE_ADEQUADO_MG_UI, escalaMax: escalaMax),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          if (serie.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_rotuloDataCurta(serie.first['data'].toString()), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                  if (serie.length > 2)
                    Text(_rotuloDataCurta(serie[serie.length ~/ 2]['data'].toString()), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                  Text(_rotuloDataCurta(serie.last['data'].toString()), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _rotuloDataCurta(String dataIso) {
    try {
      final d = DateTime.parse(dataIso);
      return DateFormat('dd/MM').format(d);
    } catch (e) {
      return dataIso;
    }
  }

  // Busca o status diário de polifenóis de uma gestante específica (usado no prontuário).
  Future<Map<String, dynamic>?> _buscarStatusDiario(int usuarioId) async {
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/status-polifenois/$usuarioId"));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      // silencioso — o indicador simplesmente não aparece se a consulta falhar
    }
    return null;
  }

  Color _corDoStatus(String? classificacao) {
    switch (classificacao) {
      case 'verde': return Colors.green.shade600;
      case 'amarelo': return Colors.orange.shade700;
      case 'vermelho': return Colors.red.shade600;
      default: return Colors.grey;
    }
  }

  String _textoDoStatus(String? classificacao) {
    switch (classificacao) {
      case 'verde': return 'Consumo adequado hoje';
      case 'amarelo': return 'Atenção: perto do limite diário';
      case 'vermelho': return 'Exposição elevada hoje';
      default: return '';
    }
  }

  // Nome do dia da semana em português, sem depender de inicialização de locale do intl
  String _nomeDiaSemana(DateTime data) {
    const nomes = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
    return nomes[data.weekday - 1];
  }

  // =========================================================================
  // REFEIÇÕES DE UM DIA ESPECÍFICO (aberto ao clicar em um dia do histórico)
  // =========================================================================
  void _abrirDetalhesDoDia(int usuarioId, String data, Color corDoDia) {
    List<dynamic> refeicoesDoDia = [];
    bool carregando = true;
    DateTime? dataFormatada;
    try { dataFormatada = DateTime.parse(data); } catch (e) {}

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (carregando && refeicoesDoDia.isEmpty) {
            http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes-gestante/$usuarioId/dia/$data")).then((res) {
              if (res.statusCode == 200) {
                setModalState(() {
                  refeicoesDoDia = jsonDecode(res.body)['refeicoes'] ?? [];
                  carregando = false;
                });
              } else {
                setModalState(() => carregando = false);
              }
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.circle, size: 14, color: corDoDia),
                SizedBox(width: 10),
                Text(
                  dataFormatada != null
                      ? "${DateFormat('dd/MM/yyyy').format(dataFormatada)} (${_nomeDiaSemana(dataFormatada)})"
                      : data,
                  style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Container(
              width: 560,
              child: carregando
                  ? Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
                  : refeicoesDoDia.isEmpty
                      ? Padding(padding: EdgeInsets.all(20), child: Text("Nenhuma refeição registrada neste dia.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                      : SingleChildScrollView(
                          child: Column(
                            children: refeicoesDoDia.map((r) {
                              DateTime? hora;
                              try { hora = DateTime.parse(r['data_hora_registro'].toString()).toLocal(); } catch (e) {}
                              final temFoto = r['foto_prato_url'] != null && r['foto_prato_url'].toString().length > 500;
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: temFoto
                                        ? Image.memory(base64Decode(r['foto_prato_url']), width: 44, height: 44, fit: BoxFit.cover)
                                        : Container(width: 44, height: 44, color: Colors.grey.shade200, child: Icon(Icons.fastfood, size: 20, color: Colors.grey)),
                                  ),
                                  title: Text(r['tipo_refeicao']?.toString() ?? '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  subtitle: Text(hora != null ? DateFormat('HH:mm').format(hora) : '-', style: TextStyle(fontSize: 12)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_formatarPolifenois(r['total_polifenois_refeicao']), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green)),
                                      Text("${r['peso_total_refeicao'] ?? '-'}g", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  onTap: () => _abrirDetalhesRefeicaoAdmin(r),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                child: Text("FECHAR", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // DETALHAMENTO COMPLETO DE UMA REFEIÇÃO (o que a IA detectou, peso, polifenóis)
  // =========================================================================
  void _abrirDetalhesRefeicaoAdmin(Map<String, dynamic> refeicao) {
    List<dynamic> itens = [];
    bool carregandoItens = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (carregandoItens && itens.isEmpty) {
            http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes/${refeicao['id']}/itens")).then((res) {
              if (res.statusCode == 200) {
                setModalState(() {
                  itens = jsonDecode(res.body);
                  carregandoItens = false;
                });
              } else {
                setModalState(() => carregandoItens = false);
              }
            });
          }

          DateTime? dataHora;
          try { dataHora = DateTime.parse(refeicao['data_hora_registro'].toString()).toLocal(); } catch (e) {}
          final temFoto = refeicao['foto_prato_url'] != null && refeicao['foto_prato_url'].toString().length > 500;

          return AlertDialog(
            title: Text("Detalhes da Refeição", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
            content: Container(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: temFoto
                          ? Image.memory(base64Decode(refeicao['foto_prato_url']), width: double.infinity, height: 220, fit: BoxFit.cover)
                          : Container(width: double.infinity, height: 180, color: Colors.grey.shade200, child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          (refeicao['tipo_refeicao']?.toString() ?? 'Refeição').toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: PolifenoisTema.azulPrimario),
                        ),
                        Text(
                          dataHora != null ? DateFormat('dd/MM/yyyy \'às\' HH:mm').format(dataHora) : '-',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Total de Polifenóis: ${_formatarPolifenois(refeicao['total_polifenois_refeicao'])}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                    Text("Peso total do prato: ${refeicao['peso_total_refeicao'] ?? '-'}g", style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                    Divider(height: 30),
                    Text("Alimentos identificados pela IA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    SizedBox(height: 8),
                    if (carregandoItens)
                      Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (itens.isEmpty)
                      Text("Nenhum item registrado nessa refeição.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    else
                      ...itens.map((it) => Card(
                        margin: EdgeInsets.only(bottom: 6),
                        elevation: 1,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.restaurant, color: PolifenoisTema.azulPrimario, size: 20),
                          title: Text(it['nome_alimento'] ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("${it['peso_estimado_gramas']}g", style: TextStyle(fontSize: 12)),
                              Text(_formatarPolifenois(it['polifenois_consumidos_item']), style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      )),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                child: Text("FECHAR", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _carregarPacientes() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/pacientes?profissional_id=${widget.usuario['id']}"),
      );

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
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================================================================
  // CRM GIGANTE: PRONTUÁRIO COMPLETO COM TODAS AS COLUNAS + FOTOS
  // =========================================================================
  void _abrirModalPaciente({Map<String, dynamic>? paciente}) {
    bool isEdicao = paciente != null;
    
    // Controladores - Dados Pessoais
    TextEditingController nomeCtrl = TextEditingController(text: isEdicao ? (paciente['nome'] ?? '') : '');
    TextEditingController cpfCtrl = TextEditingController(text: isEdicao ? (paciente['cpf'] ?? '') : '');
    TextEditingController rgCtrl = TextEditingController(text: isEdicao ? (paciente['rg'] ?? '') : '');
    TextEditingController nascCtrl = TextEditingController(text: isEdicao && paciente['data_nascimento'] != null ? paciente['data_nascimento'].toString().split('T')[0] : '');
    TextEditingController idadeCtrl = TextEditingController(text: isEdicao ? (paciente['idade']?.toString() ?? '') : '');
    TextEditingController emailCtrl = TextEditingController(text: isEdicao ? (paciente['email'] ?? '') : '');
    TextEditingController celCtrl = TextEditingController(text: isEdicao ? (paciente['telefone'] ?? '') : '');
    TextEditingController fixoCtrl = TextEditingController(text: isEdicao ? (paciente['telefone_fixo'] ?? '') : '');
    TextEditingController nacioCtrl = TextEditingController(text: isEdicao ? (paciente['nacionalidade'] ?? '') : '');
    TextEditingController naturCtrl = TextEditingController(text: isEdicao ? (paciente['naturalidade'] ?? '') : '');
    TextEditingController maeCtrl = TextEditingController(text: isEdicao ? (paciente['nome_mae'] ?? '') : '');

    // Controladores - Endereço
    TextEditingController cepCtrl = TextEditingController(text: isEdicao ? (paciente['cep'] ?? '') : '');
    TextEditingController logradouroCtrl = TextEditingController(text: isEdicao ? (paciente['logradouro'] ?? '') : '');
    TextEditingController numCtrl = TextEditingController(text: isEdicao ? (paciente['numero'] ?? '') : '');
    TextEditingController compCtrl = TextEditingController(text: isEdicao ? (paciente['complemento'] ?? '') : '');
    TextEditingController estadoCtrl = TextEditingController(text: isEdicao ? (paciente['estado'] ?? '') : '');

    // Controladores - Clínico e Acesso
    TextEditingController semanaCtrl = TextEditingController(text: isEdicao ? (paciente['semana_gestacao']?.toString() ?? '') : '');
    TextEditingController medCtrl = TextEditingController(text: isEdicao ? (paciente['nome_medico'] ?? '') : '');
    TextEditingController crmCtrl = TextEditingController(text: isEdicao ? (paciente['crm_medico'] ?? '') : '');
    TextEditingController nutriCtrl = TextEditingController(text: isEdicao ? (paciente['nome_nutricionista'] ?? '') : '');
    TextEditingController crnCtrl = TextEditingController(text: isEdicao ? (paciente['crn_nutricionista'] ?? '') : '');
    TextEditingController senhaCtrl = TextEditingController();

    // Variaveis da Galeria de Fotos
    // Histórico agrupado por dia (cada dia com seu semáforo de consumo)
    List<dynamic> diasAgrupados = [];
    bool carregandoDias = isEdicao;

    // Status diário de polifenóis (indicador colorido para a equipe clínica)
    Map<String, dynamic>? statusDiario;
    bool carregandoStatusDiario = isEdicao;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          
          if (isEdicao && carregandoDias && diasAgrupados.isEmpty) {
            http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes-por-dia/${paciente['id']}")).then((res) {
              if (res.statusCode == 200) {
                setModalState(() {
                  diasAgrupados = jsonDecode(res.body)['dias'] ?? [];
                  carregandoDias = false;
                });
              }
            });
          }

          if (isEdicao && carregandoStatusDiario && statusDiario == null) {
            _buscarStatusDiario(paciente['id']).then((resultado) {
              setModalState(() {
                statusDiario = resultado;
                carregandoStatusDiario = false;
              });
            });
          }

          return AlertDialog(
            title: Text(isEdicao ? "Prontuário Completo da Paciente" : "Novo Cadastro de Paciente", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.94 > 1150 ? 1150 : MediaQuery.of(context).size.width * 0.94, 
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // INDICADOR DE LIMITE DIÁRIO DE POLIFENÓIS
                    if (isEdicao)
                      carregandoStatusDiario
                          ? Padding(
                              padding: EdgeInsets.only(bottom: 15),
                              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : (statusDiario == null || statusDiario!['monitorar'] != true)
                              ? SizedBox.shrink()
                              : Container(
                                  margin: EdgeInsets.only(bottom: 15),
                                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _corDoStatus(statusDiario!['classificacao']).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _corDoStatus(statusDiario!['classificacao'])),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.circle, size: 12, color: _corDoStatus(statusDiario!['classificacao'])),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "${_textoDoStatus(statusDiario!['classificacao'])} — Consumo hoje: ${_formatarPolifenois(statusDiario!['total_hoje'])} de ${_formatarPolifenois(statusDiario!['limite_adequado'])} recomendados",
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _corDoStatus(statusDiario!['classificacao'])),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("1. DADOS PESSOAIS", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(width: 260, child: TextField(controller: nomeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome Completo", Icons.person))),
                        SizedBox(width: 150, child: TextField(controller: cpfCtrl, decoration: PolifenoisTema.inputDecoracao("CPF", Icons.badge))),
                        SizedBox(width: 130, child: TextField(controller: rgCtrl, decoration: PolifenoisTema.inputDecoracao("RG", Icons.fingerprint))),
                        SizedBox(width: 170, child: TextField(controller: nascCtrl, decoration: PolifenoisTema.inputDecoracao("Nascimento (AAAA-MM-DD)", Icons.calendar_today))),
                        SizedBox(width: 90, child: TextField(controller: idadeCtrl, decoration: PolifenoisTema.inputDecoracao("Idade", Icons.cake))),
                        SizedBox(width: 230, child: TextField(controller: emailCtrl, decoration: PolifenoisTema.inputDecoracao("E-mail", Icons.email))),
                        SizedBox(width: 150, child: TextField(controller: celCtrl, decoration: PolifenoisTema.inputDecoracao("Celular", Icons.phone_android))),
                        SizedBox(width: 150, child: TextField(controller: fixoCtrl, decoration: PolifenoisTema.inputDecoracao("Fixo", Icons.phone))),
                        SizedBox(width: 230, child: TextField(controller: maeCtrl, decoration: PolifenoisTema.inputDecoracao("Nome da Mãe", Icons.woman))),
                        SizedBox(width: 150, child: TextField(controller: nacioCtrl, decoration: PolifenoisTema.inputDecoracao("Nacionalidade", Icons.flag))),
                        SizedBox(width: 180, child: TextField(controller: naturCtrl, decoration: PolifenoisTema.inputDecoracao("Naturalidade", Icons.location_city))),
                      ],
                    ),

                    SizedBox(height: 20),

                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("2. ENDEREÇO", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(width: 120, child: TextField(controller: cepCtrl, decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map))),
                        SizedBox(width: 280, child: TextField(controller: logradouroCtrl, decoration: PolifenoisTema.inputDecoracao("Logradouro", Icons.home))),
                        SizedBox(width: 90, child: TextField(controller: numCtrl, decoration: PolifenoisTema.inputDecoracao("Número", Icons.numbers))),
                        SizedBox(width: 200, child: TextField(controller: compCtrl, decoration: PolifenoisTema.inputDecoracao("Complemento", Icons.info))),
                        SizedBox(width: 90, child: TextField(controller: estadoCtrl, decoration: PolifenoisTema.inputDecoracao("Estado (UF)", Icons.location_on))),
                      ],
                    ),

                    SizedBox(height: 20),

                    Container(
                      padding: EdgeInsets.all(10), color: Colors.blue.shade50, width: double.infinity,
                      child: Text("3. DADOS CLÍNICOS E ACESSO", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ),
                    SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(width: 170, child: TextField(controller: semanaCtrl, decoration: PolifenoisTema.inputDecoracao("Semanas de Gestação", Icons.calendar_month))),
                        if (!isEdicao)
                          SizedBox(width: 200, child: TextField(controller: senhaCtrl, decoration: PolifenoisTema.inputDecoracao("Senha Provisória", Icons.lock), obscureText: true)),
                        SizedBox(width: 240, child: TextField(controller: medCtrl, decoration: PolifenoisTema.inputDecoracao("Médico Obstetra", Icons.medical_services))),
                        SizedBox(width: 130, child: TextField(controller: crmCtrl, decoration: PolifenoisTema.inputDecoracao("CRM", Icons.badge))),
                        SizedBox(width: 240, child: TextField(controller: nutriCtrl, decoration: PolifenoisTema.inputDecoracao("Nutricionista", Icons.local_dining))),
                        SizedBox(width: 130, child: TextField(controller: crnCtrl, decoration: PolifenoisTema.inputDecoracao("CRN", Icons.badge))),
                      ],
                    ),

                    if (isEdicao) ...[
                      SizedBox(height: 35),
                      Container(
                        padding: EdgeInsets.all(10), color: Colors.green.shade50, width: double.infinity,
                        child: Text("4. HISTÓRICO DIÁRIO DE CONSUMO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 14.5)),
                      ),
                      SizedBox(height: 14),
                      if (!carregandoDias && diasAgrupados.length >= 2)
                        _graficoLinhaConsumo(diasAgrupados),
                      SizedBox(height: 14),
                      Text("Detalhe dia a dia:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
                      SizedBox(height: 6),
                      if (carregandoDias)
                        Center(child: CircularProgressIndicator())
                      else if (diasAgrupados.isEmpty)
                        Text("A paciente ainda não registrou nenhuma refeição no aplicativo.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 14))
                      else
                        Column(
                          children: diasAgrupados.map((d) {
                            DateTime? dataDia;
                            try { dataDia = DateTime.parse(d['data'].toString()); } catch (e) {}
                            final cor = _corDoStatus(d['classificacao']);
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              child: ListTile(
                                leading: Icon(Icons.circle, size: 16, color: cor),
                                title: Text(
                                  dataDia != null ? "${DateFormat('dd/MM/yyyy').format(dataDia)} (${_nomeDiaSemana(dataDia)})" : d['data'].toString(),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text("${d['quantidade_refeicoes']} refeição(ões) registrada(s)", style: TextStyle(fontSize: 13.5)),
                                trailing: Text(_formatarPolifenois(d['total_polifenois']), style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 14)),
                                onTap: () => _abrirDetalhesDoDia(paciente['id'], d['data'].toString(), cor),
                              ),
                            );
                          }).toList(),
                        )
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("FECHAR / CANCELAR")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _salvarPaciente(
                    isEdicao ? paciente['id'] : null, 
                    nomeCtrl.text, cpfCtrl.text, emailCtrl.text, semanaCtrl.text, senhaCtrl.text, !isEdicao,
                    rg: rgCtrl.text, nasc: nascCtrl.text, idade: idadeCtrl.text, cel: celCtrl.text, fixo: fixoCtrl.text,
                    cep: cepCtrl.text, log: logradouroCtrl.text, num: numCtrl.text, comp: compCtrl.text, est: estadoCtrl.text,
                    nac: nacioCtrl.text, nat: naturCtrl.text, mae: maeCtrl.text, 
                    med: medCtrl.text, crm: crmCtrl.text, nut: nutriCtrl.text, crn: crnCtrl.text
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                child: Text("SALVAR PRONTUÁRIO", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _salvarPaciente(int? id, String nome, String cpf, String email, String semana, String senha, bool isNovo, 
    {String? rg, String? nasc, String? idade, String? cel, String? fixo, String? cep, String? log, String? num, String? comp, 
     String? est, String? nac, String? nat, String? mae, String? med, String? crm, String? nut, String? crn}) async {
    
    setState(() => _loading = true);
    try {
      Uri url = isNovo 
          ? Uri.parse("https://polifenois-backend.onrender.com/paciente-admin")
          : Uri.parse("https://polifenois-backend.onrender.com/pacientes/$id");

      var bodyData = {
        "nome": nome, "cpf": cpf, "email": email, "semana_gestacao": semana,
        "rg": rg, "data_nascimento": nasc, "idade": idade, "telefone": cel, "telefone_fixo": fixo,
        "cep": cep, "logradouro": log, "numero": num, "complemento": comp, "estado": est,
        "nacionalidade": nac, "naturalidade": nat, "nome_mae": mae,
        "nome_medico": med, "crm_medico": crm, "nome_nutricionista": nut, "crn_nutricionista": crn
      };
      if (isNovo) {
        bodyData["senha"] = senha;
        bodyData["profissional_id"] = widget.usuario['id']; // vincula automaticamente a quem está cadastrando
      }

      var response = isNovo 
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarPacientes();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prontuário salvo com sucesso!"), backgroundColor: Colors.green));
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmarExclusaoPaciente(int id, String nome) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmar Exclusão"),
        content: Text("Deseja apagar permanentemente a paciente '$nome' e todo o seu histórico de fotos e refeições?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _pacientes.removeWhere((p) => p['id'] == id));
              await http.delete(Uri.parse("https://polifenois-backend.onrender.com/pacientes/$id"));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Paciente excluída."), backgroundColor: Colors.redAccent));
            },
            child: Text("EXCLUIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Acesso da paciente liberado com sucesso!"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: Senha de administrador incorreta."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Erro ao validar: $e");
    }
  }

  bool _senhaForte(String senha) {
    if (senha.length < 6) return false;
    final temMaiuscula = RegExp(r'[A-Z]').hasMatch(senha);
    final temNumero = RegExp(r'[0-9]').hasMatch(senha);
    final temEspecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]]').hasMatch(senha);
    return temMaiuscula && temNumero && temEspecial;
  }

  static const String _regraSenha =
      "A senha precisa ter no mínimo 6 caracteres, incluindo:\n"
      "• 1 letra maiúscula\n"
      "• 1 número\n"
      "• 1 caractere especial (@ # \$ % & etc.)";

  void _abrirAlterarSenha() {
    final senhaAtualCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmarSenhaCtrl = TextEditingController();
    bool salvando = false;
    bool senhaAtualVisivel = false, novaSenhaVisivel = false, confirmarVisivel = false;
    String? avisoMsg;
    bool avisoSucesso = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) => AlertDialog(
          title: Text("Alterar Senha", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
          content: Container(
            width: 380,
            child: avisoMsg != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(avisoSucesso ? Icons.check_circle : Icons.error, color: avisoSucesso ? Colors.green : Colors.red, size: 46),
                      SizedBox(height: 12),
                      Text(avisoSucesso ? "Sucesso" : "Atenção", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 10),
                      Text(avisoMsg!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (avisoSucesso) {
                              Navigator.pop(dialogContext);
                            } else {
                              setModalState(() => avisoMsg = null);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, padding: EdgeInsets.symmetric(vertical: 12)),
                          child: Text("OK", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: senhaAtualCtrl,
                        obscureText: !senhaAtualVisivel,
                        decoration: PolifenoisTema.inputDecoracao("Senha atual", Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(senhaAtualVisivel ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setModalState(() => senhaAtualVisivel = !senhaAtualVisivel),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: novaSenhaCtrl,
                        obscureText: !novaSenhaVisivel,
                        decoration: PolifenoisTema.inputDecoracao("Nova senha", Icons.lock).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(novaSenhaVisivel ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setModalState(() => novaSenhaVisivel = !novaSenhaVisivel),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 6, left: 4),
                        child: Text("Mín. 6 caracteres, 1 maiúscula, 1 número, 1 especial", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: confirmarSenhaCtrl,
                        obscureText: !confirmarVisivel,
                        decoration: PolifenoisTema.inputDecoracao("Confirmar nova senha", Icons.lock).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(confirmarVisivel ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setModalState(() => confirmarVisivel = !confirmarVisivel),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: avisoMsg != null ? [] : [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("CANCELAR")),
            ElevatedButton(
              onPressed: salvando ? null : () async {
                if (senhaAtualCtrl.text.isEmpty || novaSenhaCtrl.text.isEmpty || confirmarSenhaCtrl.text.isEmpty) {
                  setModalState(() { avisoMsg = "Preencha todos os campos."; avisoSucesso = false; });
                  return;
                }
                if (!_senhaForte(novaSenhaCtrl.text)) {
                  setModalState(() { avisoMsg = _regraSenha; avisoSucesso = false; });
                  return;
                }
                if (novaSenhaCtrl.text != confirmarSenhaCtrl.text) {
                  setModalState(() { avisoMsg = "A nova senha e a confirmação não coincidem. Corrija os dois campos e tente novamente."; avisoSucesso = false; });
                  return;
                }
                setModalState(() => salvando = true);
                try {
                  final res = await http.post(
                    Uri.parse("https://polifenois-backend.onrender.com/alterar-senha"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "usuario_id": widget.usuario['id'],
                      "senha_atual": senhaAtualCtrl.text,
                      "nova_senha": novaSenhaCtrl.text,
                    }),
                  );
                  final data = jsonDecode(res.body);
                  if (res.statusCode == 200) {
                    setModalState(() { salvando = false; avisoMsg = "Senha alterada com sucesso!"; avisoSucesso = true; });
                  } else {
                    setModalState(() { salvando = false; avisoMsg = data['erro'] ?? "Senha atual incorreta."; avisoSucesso = false; });
                  }
                } catch (e) {
                  setModalState(() { salvando = false; avisoMsg = "Erro de conexão. Verifique sua internet e tente novamente."; avisoSucesso = false; });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
              child: salvando
                  ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text("SALVAR", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirConfiguracoes() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("Configurações", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
          content: Container(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mostrar polifenóis em:", style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700)),
                SizedBox(height: 10),
                ToggleButtons(
                  isSelected: [_unidade == 'mg', _unidade == 'g'],
                  onPressed: (index) => _selecionarUnidade(index == 0 ? 'mg' : 'g', setModalState),
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: PolifenoisTema.azulPrimario,
                  color: PolifenoisTema.azulPrimario,
                  constraints: BoxConstraints(minHeight: 38, minWidth: 90),
                  children: [Text("Miligramas (mg)"), Text("Gramas (g)")],
                ),
                SizedBox(height: 8),
                Text(
                  "Vale só pra este computador — não afeta o que os outros usuários veem.",
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
                Divider(height: 30),
                Text("Segurança", style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _abrirAlterarSenha();
                    },
                    icon: Icon(Icons.lock_outline, size: 18, color: PolifenoisTema.azulPrimario),
                    label: Text("Alterar Senha", style: TextStyle(color: PolifenoisTema.azulPrimario)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: PolifenoisTema.azulPrimario), padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
              child: Text("FECHAR", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String nomeUsuario = widget.usuario['nome'] ?? 'Administrador';

    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(
        title: Text("Vetix Dashboard Clínico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: PolifenoisTema.azulPrimario,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text("Olá, $nomeUsuario", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb()));
            },
          )
        ],
      ),
      body: Row(
        children: [
          // MENU LATERAL
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings, size: 50, color: PolifenoisTema.azulPrimario),
                        SizedBox(height: 10),
                        Text("Painel Clínico", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.people, color: PolifenoisTema.azulPrimario),
                  title: Text("Gestantes", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                  selected: true,
                  selectedTileColor: PolifenoisTema.azulClaroFundo,
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.pie_chart, color: PolifenoisTema.cinzaTexto),
                  title: Text("Estatísticas Nutricionais", style: TextStyle(color: PolifenoisTema.cinzaTexto)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Módulo em desenvolvimento.")));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.kitchen, color: PolifenoisTema.cinzaTexto),
                  title: Text("Base Global de Alimentos", style: TextStyle(color: PolifenoisTema.cinzaTexto)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => GestaoAlimentosWeb(usuario: widget.usuario)));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: PolifenoisTema.cinzaTexto),
                  title: Text("Configurações", style: TextStyle(color: PolifenoisTema.cinzaTexto)),
                  onTap: () => _abrirConfiguracoes(),
                ),
              ],
            ),
          ),

          // TABELA DE PACIENTES
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Visão Geral de Pacientes", style: PolifenoisTema.tituloEstilo),
                      Spacer(),
                      IconButton(icon: Icon(Icons.refresh, color: PolifenoisTema.azulPrimario), onPressed: _carregarPacientes),
                      SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _abrirModalPaciente(), 
                        icon: Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                        label: Text("INCLUIR PACIENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: _loading
                          ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                          : _pacientes.isEmpty
                              ? Center(child: Text("Nenhuma paciente encontrada no banco de dados.", style: PolifenoisTema.corpoEstilo))
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
                                              Row(
                                                children: [
                                                  OutlinedButton(
                                                    onPressed: () => _abrirModalPaciente(paciente: p),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: PolifenoisTema.azulPrimario,
                                                      side: BorderSide(color: PolifenoisTema.azulPrimario),
                                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    ),
                                                    child: Text("DETALHES", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                  SizedBox(width: 6),
                                                  IconButton(
                                                    icon: Icon(Icons.delete_forever, color: Colors.red),
                                                    tooltip: "Excluir Paciente",
                                                    onPressed: () => _confirmarExclusaoPaciente(p['id'], p['nome']),
                                                  ),
                                                  if (!validado)
                                                    ElevatedButton.icon(
                                                      icon: Icon(Icons.key, size: 16),
                                                      label: Text("Liberar Acesso"),
                                                      onPressed: () => _confirmarLiberacao(p['id']),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: PolifenoisTema.azulPrimario,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    )
                                                ],
                                              )
                                            ),
                                          ]
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// =========================================================================
// PINTOR DO GRÁFICO DE LINHA — evolução do consumo diário de polifenóis,
// com uma linha de referência tracejada no limite (1.000mg por padrão).
// Cada ponto é colorido conforme a classificação do dia (verde/amarelo/vermelho).
// =========================================================================
class _LinhaConsumoPainterAdmin extends CustomPainter {
  final List<dynamic> dias; // cada item: {data, total_polifenois, classificacao}
  final double limite;
  final double escalaMax;

  _LinhaConsumoPainterAdmin({required this.dias, required this.limite, required this.escalaMax});

  Color _corClassificacao(String? c) {
    switch (c) {
      case 'verde': return Colors.green.shade600;
      case 'amarelo': return Colors.orange.shade700;
      case 'vermelho': return Colors.red.shade600;
      default: return Colors.grey;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (dias.isEmpty) return;

    const paddingTopo = 10.0;
    const paddingBaixo = 6.0;
    final larguraUtil = size.width;
    final alturaUtil = size.height - paddingTopo - paddingBaixo;

    final valores = dias.map((d) => (double.tryParse(d['total_polifenois'].toString()) ?? 0)).toList();

    double yPara(double valor) => paddingTopo + alturaUtil - (valor / escalaMax) * alturaUtil;
    double xPara(int index) => dias.length == 1
        ? larguraUtil / 2
        : (index / (dias.length - 1)) * larguraUtil;

    // Linhas de grade horizontais leves (0%, 50%, 100% da escala) — os números
    // do eixo Y ficam como widgets Text normais, fora do painter.
    final gridPaint = Paint()..color = Colors.grey.shade200..strokeWidth = 1;
    for (var frac in [0.0, 0.5, 1.0]) {
      final y = paddingTopo + alturaUtil - (frac * alturaUtil);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Linha de referência (limite), tracejada em vermelho claro
    final yLimite = yPara(limite);
    final dashPaint = Paint()..color = Colors.red.shade300..strokeWidth = 1.6;
    double dashX = 0;
    while (dashX < size.width) {
      canvas.drawLine(Offset(dashX, yLimite), Offset(dashX + 6, yLimite), dashPaint);
      dashX += 10;
    }

    // Linha conectando os pontos de consumo
    final linePaint = Paint()
      ..color = PolifenoisTema.azulPrimario
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (int i = 0; i < dias.length; i++) {
      final x = xPara(i);
      final y = yPara(valores[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Pontos coloridos por classificação do dia
    for (int i = 0; i < dias.length; i++) {
      final x = xPara(i);
      final y = yPara(valores[i]);
      final cor = _corClassificacao(dias[i]['classificacao']?.toString());
      canvas.drawCircle(Offset(x, y), 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = cor);
    }
  }

  @override
  bool shouldRepaint(covariant _LinhaConsumoPainterAdmin oldDelegate) {
    return oldDelegate.dias != dias || oldDelegate.limite != limite || oldDelegate.escalaMax != escalaMax;
  }
}