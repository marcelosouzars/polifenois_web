//
// DASHBOARD_MOBILE_APP.DART
//
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tema_padrao_web.dart';
import 'login_web.dart';
import 'gestao_alimentos_web.dart';
import 'logs_acesso_web.dart';

class DashboardMasterWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  DashboardMasterWeb({required this.usuario});

  @override
  _DashboardMasterWebState createState() => _DashboardMasterWebState();
}

class _DashboardMasterWebState extends State<DashboardMasterWeb> {
  int _indiceMenu = 0;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _semaforoPorEstado;
  bool _carregandoSemaforo = true;
  List<dynamic> _pacientes = [];
  List<dynamic> _pacientesFiltradas = [];
  bool _carregandoStats = true;
  bool _carregandoPacientes = true;
  Uint8List? _fotoPerfilBytes;
  String _unidade = 'mg';
  String _providerIA = 'gemini';
  List<int> _trimestresMonitorados = [1, 2, 3];

  // --- FILTROS DA LISTA DE GESTANTES ---
  final TextEditingController _filtroNome = TextEditingController();
  final TextEditingController _filtroCadIni = TextEditingController();
  final TextEditingController _filtroCadFim = TextEditingController();
  final TextEditingController _filtroNascIni = TextEditingController();
  final TextEditingController _filtroNascFim = TextEditingController();
  final TextEditingController _filtroIdadeMin = TextEditingController();
  final TextEditingController _filtroIdadeMax = TextEditingController();
  String? _filtroCidade;
  String _filtroEstado = 'TODOS';
  bool _filtroSemRefeicoes = false;
  List<String> _cidadesDoEstado = [];
  bool _carregandoCidadesFiltro = false;

  static const List<String> _ufs = [
    'TODOS','AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
    'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
  ];

  // --- RELÓGIO DO TOPO: foi movido para um widget isolado (_RelogioTopo)
  // para não recarregar a tela inteira (e "piscar" as fotos) a cada segundo.

  @override
  void initState() {
    super.initState();
    _buscarEstatisticas();
    _carregarUnidade();
    _carregarProviderIA();
    _carregarTrimestresMonitorados();
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

  // Busca no backend qual IA está ativa no momento (Gemini ou Claude),
  // para que a tela de Configurações já abra mostrando a seleção correta.
  Future<void> _carregarProviderIA() async {
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/configuracao-ia"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _providerIA = data['provider'] ?? 'gemini');
      }
    } catch (e) {
      // Mantém 'gemini' como padrão se não conseguir consultar agora.
    }
  }

  Future<void> _carregarTrimestresMonitorados() async {
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/configuracao-trimestres"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lista = (data['trimestres'] as List<dynamic>? ?? [1, 2, 3]).map((e) => e as int).toList();
        if (mounted) setState(() => _trimestresMonitorados = lista);
      }
    } catch (e) {
      // Mantém [1,2,3] como padrão se não conseguir consultar agora.
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

  @override
  void dispose() {
    super.dispose();
  }

  void _mudarAba(int indice) {
    setState(() => _indiceMenu = indice);
    if (indice == 0) {
      _buscarEstatisticas();
    } else if (indice == 1) {
      _carregarPacientes();
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
                // AVISO substitui o formulário por completo enquanto está visível
                // (evita qualquer sobreposição/Z-order que pudesse "roubar" o toque do botão).
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
    // Cópia local da IA ativa: só é gravada de verdade no backend quando
    // o usuário clicar em "SALVAR IA" (não é instantâneo como o mg/g).
    String providerSelecionado = _providerIA;
    bool salvandoIA = false;
    List<int> trimestresSelecionados = List<int>.from(_trimestresMonitorados);
    bool salvandoTrimestres = false;

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
                Text("Inteligência Artificial (Análise de Refeições)", style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                ToggleButtons(
                  isSelected: [providerSelecionado == 'gemini', providerSelecionado == 'claude'],
                  onPressed: salvandoIA ? null : (index) => setModalState(() => providerSelecionado = index == 0 ? 'gemini' : 'claude'),
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: PolifenoisTema.azulPrimario,
                  color: PolifenoisTema.azulPrimario,
                  constraints: BoxConstraints(minHeight: 38, minWidth: 90),
                  children: [Text("Gemini"), Text("Claude")],
                ),
                SizedBox(height: 8),
                Text(
                  "Define qual IA identifica os alimentos nas fotos das refeições enviadas pelo app.",
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: salvandoIA ? null : () async {
                      setModalState(() => salvandoIA = true);
                      try {
                        final res = await http.put(
                          Uri.parse("https://polifenois-backend.onrender.com/configuracao-ia"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({"provider": providerSelecionado}),
                        );
                        if (res.statusCode == 200) {
                          setState(() => _providerIA = providerSelecionado);
                          setModalState(() => salvandoIA = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("IA de análise definida para: ${providerSelecionado == 'claude' ? 'Claude' : 'Gemini'}"),
                            backgroundColor: Colors.green,
                          ));
                        } else {
                          setModalState(() => salvandoIA = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar. Tente novamente."), backgroundColor: Colors.red));
                        }
                      } catch (e) {
                        setModalState(() => salvandoIA = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro de conexão."), backgroundColor: Colors.red));
                      }
                    },
                    icon: salvandoIA
                        ? SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.save, size: 16, color: Colors.white),
                    label: Text(salvandoIA ? "Salvando..." : "SALVAR IA", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),

                Divider(height: 30),
                Text("Monitoramento de Limite Diário de Polifenóis", style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text(
                  "O sistema calcula o consumo de polifenóis por dia (00:00 às 23:59) e sinaliza a gestante e a equipe clínica ao se aproximar do limite. Selecione em quais trimestres de gestação esse controle deve estar ativo:",
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                SizedBox(height: 10),
                ...[1, 2, 3].map((trimestre) => CheckboxListTile(
                  value: trimestresSelecionados.contains(trimestre),
                  onChanged: salvandoTrimestres ? null : (marcado) {
                    setModalState(() {
                      if (marcado == true) {
                        trimestresSelecionados.add(trimestre);
                      } else {
                        trimestresSelecionados.remove(trimestre);
                      }
                    });
                  },
                  title: Text("${trimestre}º Trimestre", style: TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )).toList(),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: salvandoTrimestres ? null : () async {
                      setModalState(() => salvandoTrimestres = true);
                      try {
                        final res = await http.put(
                          Uri.parse("https://polifenois-backend.onrender.com/configuracao-trimestres"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({"trimestres": trimestresSelecionados}),
                        );
                        if (res.statusCode == 200) {
                          setState(() => _trimestresMonitorados = List<int>.from(trimestresSelecionados));
                          setModalState(() => salvandoTrimestres = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Monitoramento de limite diário atualizado!"),
                            backgroundColor: Colors.green,
                          ));
                        } else {
                          setModalState(() => salvandoTrimestres = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar. Tente novamente."), backgroundColor: Colors.red));
                        }
                      } catch (e) {
                        setModalState(() => salvandoTrimestres = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro de conexão."), backgroundColor: Colors.red));
                      }
                    },
                    icon: salvandoTrimestres
                        ? SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.save, size: 16, color: Colors.white),
                    label: Text(salvandoTrimestres ? "Salvando..." : "SALVAR MONITORAMENTO", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
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
    _buscarSemaforoPorEstado();
  }

  Future<void> _buscarSemaforoPorEstado() async {
    setState(() => _carregandoSemaforo = true);
    try {
      final response = await http.get(
        Uri.parse("https://polifenois-backend.onrender.com/estatisticas-semaforo-por-estado"),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        setState(() {
          _semaforoPorEstado = jsonDecode(response.body);
          _carregandoSemaforo = false;
        });
      } else {
        setState(() => _carregandoSemaforo = false);
      }
    } catch (e) {
      setState(() => _carregandoSemaforo = false);
    }
  }

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
          _aplicarFiltros();
        }
      }
    } catch (e) {
      print("Erro ao carregar pacientes: $e");
    } finally {
      if (mounted) setState(() => _carregandoPacientes = false);
    }
  }

  DateTime? _parseData(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString().split('T')[0]);
    } catch (e) { return null; }
  }

  // Busca as cidades do estado selecionado via API pública do IBGE.
  // Chamada sempre que o filtro de Estado muda (exceto quando volta para "TODOS").
  Future<void> _buscarCidadesPorEstado(String uf) async {
    setState(() {
      _carregandoCidadesFiltro = true;
      _cidadesDoEstado = [];
      _filtroCidade = null;
    });
    try {
      final response = await http.get(
        Uri.parse("https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios"),
      );
      if (response.statusCode == 200) {
        final List<dynamic> dados = jsonDecode(response.body);
        final nomes = dados.map((m) => m['nome'].toString()).toList();
        nomes.sort();
        if (mounted) setState(() => _cidadesDoEstado = nomes);
      }
    } catch (e) {
      print("Erro ao buscar cidades do IBGE: $e");
    } finally {
      if (mounted) setState(() => _carregandoCidadesFiltro = false);
    }
  }

  Future<void> _selecionarData(TextEditingController ctrl) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() => ctrl.text = DateFormat('yyyy-MM-dd').format(escolhida));
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _pacientesFiltradas = _pacientes.where((p) {
        // Nome
        if (_filtroNome.text.isNotEmpty &&
            !(p['nome'] ?? '').toString().toLowerCase().contains(_filtroNome.text.toLowerCase())) {
          return false;
        }

        // Data de cadastro (inicial/final) — tryParse: se o texto digitado ainda
        // estiver incompleto/inválido, o filtro é simplesmente ignorado (não trava a tela).
        if (_filtroCadIni.text.isNotEmpty || _filtroCadFim.text.isNotEmpty) {
          DateTime? dCad = _parseData(p['data_cadastro']);
          if (dCad == null) return false;
          final DateTime? cadIni = DateTime.tryParse(_filtroCadIni.text);
          final DateTime? cadFim = DateTime.tryParse(_filtroCadFim.text);
          if (cadIni != null && dCad.isBefore(cadIni)) return false;
          if (cadFim != null && dCad.isAfter(cadFim.add(Duration(days: 1)))) return false;
        }

        // Nascimento (inicial/final)
        if (_filtroNascIni.text.isNotEmpty || _filtroNascFim.text.isNotEmpty) {
          DateTime? dNasc = _parseData(p['data_nascimento']);
          if (dNasc == null) return false;
          final DateTime? nascIni = DateTime.tryParse(_filtroNascIni.text);
          final DateTime? nascFim = DateTime.tryParse(_filtroNascFim.text);
          if (nascIni != null && dNasc.isBefore(nascIni)) return false;
          if (nascFim != null && dNasc.isAfter(nascFim)) return false;
        }

        // Idade (min/max)
        int? idade = int.tryParse(p['idade']?.toString() ?? '');
        if (_filtroIdadeMin.text.isNotEmpty) {
          int min = int.tryParse(_filtroIdadeMin.text) ?? 0;
          if (idade == null || idade < min) return false;
        }
        if (_filtroIdadeMax.text.isNotEmpty) {
          int max = int.tryParse(_filtroIdadeMax.text) ?? 999;
          if (idade == null || idade > max) return false;
        }

        // Estado
        if (_filtroEstado != 'TODOS' && (p['estado'] ?? '').toString() != _filtroEstado) return false;

        // Cidade (agora é seleção exata vinda do dropdown, não mais texto livre)
        if (_filtroCidade != null && _filtroCidade!.isNotEmpty &&
            (p['cidade'] ?? '').toString() != _filtroCidade) {
          return false;
        }

        // Sem histórico de refeições
        if (_filtroSemRefeicoes) {
          int total = int.tryParse(p['total_refeicoes']?.toString() ?? '0') ?? 0;
          if (total > 0) return false;
        }

        return true;
      }).toList();
    });
  }

  void _limparFiltros() {
    _filtroNome.clear();
    _filtroCadIni.clear();
    _filtroCadFim.clear();
    _filtroNascIni.clear();
    _filtroNascFim.clear();
    _filtroIdadeMin.clear();
    _filtroIdadeMax.clear();
    setState(() {
      _filtroEstado = 'TODOS';
      _filtroCidade = null;
      _cidadesDoEstado = [];
      _filtroSemRefeicoes = false;
    });
    _aplicarFiltros();
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
    TextEditingController cidadeCtrl = TextEditingController(text: isEdicao ? (paciente['cidade'] ?? '') : '');

    // Controladores - Clínico e Acesso
    TextEditingController semanaCtrl = TextEditingController(text: isEdicao ? (paciente['semana_gestacao']?.toString() ?? '') : '');
    TextEditingController medCtrl = TextEditingController(text: isEdicao ? (paciente['nome_medico'] ?? '') : '');
    TextEditingController crmCtrl = TextEditingController(text: isEdicao ? (paciente['crm_medico'] ?? '') : '');
    TextEditingController nutriCtrl = TextEditingController(text: isEdicao ? (paciente['nome_nutricionista'] ?? '') : '');
    TextEditingController crnCtrl = TextEditingController(text: isEdicao ? (paciente['crn_nutricionista'] ?? '') : '');
    TextEditingController senhaCtrl = TextEditingController();

    // --- FOTO DA PACIENTE (NOVO) ---
    Uint8List? fotoPacienteBytes;

    Future<void> selecionarFotoPaciente(StateSetter setModalState) async {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? imagem = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 85);
        if (imagem != null) {
          final bytes = await imagem.readAsBytes();
          setModalState(() { fotoPacienteBytes = bytes; });
          final base64Foto = base64Encode(bytes);
          await http.put(
            Uri.parse("https://polifenois-backend.onrender.com/atualizar-foto-perfil"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"usuario_id": paciente!['id'], "foto_base64": base64Foto}),
          );
        }
      } catch (e) { print("Erro ao selecionar foto da paciente: $e"); }
    }

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

          // Se for edição e ainda não carregou o histórico, busca no backend agrupado por dia
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
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            title: Text(isEdicao ? "Prontuário Completo da Paciente" : "Novo Cadastro de Paciente", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
            content: Theme(
              data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.94 > 1150 ? 1150 : MediaQuery.of(context).size.width * 0.94,
                height: MediaQuery.of(context).size.height * 0.88,
                // Modal inteiro rola (antes só a seção 4 rolava e o resto ficava
                // "fixo" — em telas menores isso escondia o histórico lá embaixo).
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // INDICADOR DE LIMITE DIÁRIO DE POLIFENÓIS (visível para a equipe clínica)
                      if (isEdicao)
                        carregandoStatusDiario
                            ? Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : (statusDiario == null || statusDiario!['monitorar'] != true)
                                ? SizedBox.shrink()
                                : Container(
                                    margin: EdgeInsets.only(bottom: 12),
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
                      // SESSÃO 1: DADOS PESSOAIS
                      Container(
                        padding: EdgeInsets.all(8), color: Colors.blue.shade50, width: double.infinity,
                        child: Text("1. DADOS PESSOAIS", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario, fontSize: 13)),
                      ),
                      SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
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
                          ),
                          SizedBox(width: 20),
                          Column(
                            children: [
                              GestureDetector(
                                onTap: isEdicao ? () => selecionarFotoPaciente(setModalState) : null,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 92, height: 92,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.shade200,
                                        image: fotoPacienteBytes != null
                                          ? DecorationImage(image: MemoryImage(fotoPacienteBytes!), fit: BoxFit.cover)
                                          : (isEdicao && paciente!['foto_perfil_url'] != null && paciente['foto_perfil_url'].toString().length > 100
                                              ? DecorationImage(image: MemoryImage(base64Decode(paciente['foto_perfil_url'])), fit: BoxFit.cover)
                                              : null),
                                      ),
                                      child: (fotoPacienteBytes == null && (!isEdicao || paciente!['foto_perfil_url'] == null || paciente['foto_perfil_url'].toString().length < 100))
                                        ? Icon(Icons.person, size: 46, color: Colors.grey.shade400)
                                        : null,
                                    ),
                                    if (isEdicao)
                                      Positioned(
                                        bottom: 0, right: 0,
                                        child: CircleAvatar(radius: 14, backgroundColor: PolifenoisTema.azulPrimario,
                                          child: Icon(Icons.camera_alt, size: 14, color: Colors.white)),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(isEdicao ? "Toque para alterar" : "Salve para\nadicionar foto",
                                style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(8), color: Colors.blue.shade50, width: double.infinity,
                        child: Text("2. ENDEREÇO", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario, fontSize: 13)),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: 120, child: TextField(controller: cepCtrl, decoration: PolifenoisTema.inputDecoracao("CEP", Icons.map))),
                          SizedBox(width: 280, child: TextField(controller: logradouroCtrl, decoration: PolifenoisTema.inputDecoracao("Logradouro", Icons.home))),
                          SizedBox(width: 90, child: TextField(controller: numCtrl, decoration: PolifenoisTema.inputDecoracao("Número", Icons.numbers))),
                          SizedBox(width: 200, child: TextField(controller: compCtrl, decoration: PolifenoisTema.inputDecoracao("Complemento", Icons.info))),
                          SizedBox(width: 180, child: TextField(controller: cidadeCtrl, decoration: PolifenoisTema.inputDecoracao("Cidade", Icons.location_city))),
                          SizedBox(width: 90, child: TextField(controller: estadoCtrl, decoration: PolifenoisTema.inputDecoracao("Estado (UF)", Icons.location_on))),
                        ],
                      ),

                      SizedBox(height: 16),

                      // SESSÃO 3: DADOS CLÍNICOS
                      Container(
                        padding: EdgeInsets.all(8), color: Colors.blue.shade50, width: double.infinity,
                        child: Text("3. DADOS CLÍNICOS E ACESSO", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario, fontSize: 13)),
                      ),
                      SizedBox(height: 10),
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

                      // SESSÃO 4: HISTÓRICO POR DIA — agora flui dentro do mesmo scroll
                      // do restante do prontuário (não precisa mais de altura própria).
                      if (isEdicao) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), color: Colors.green.shade50, width: double.infinity,
                          child: Text("4. HISTÓRICO DIÁRIO DE CONSUMO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 14.5)),
                        ),
                        SizedBox(height: 14),
                        if (!carregandoDias && diasAgrupados.length >= 2)
                          _graficoLinhaConsumo(diasAgrupados),
                        SizedBox(height: 14),
                        Text("Detalhe dia a dia:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
                        SizedBox(height: 6),
                        if (!carregandoDias && diasAgrupados.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            color: Colors.green.shade50,
                            child: Row(
                              children: [
                                SizedBox(width: 30, child: Text("")),
                                Expanded(flex: 3, child: Text("DIA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800))),
                                Expanded(flex: 2, child: Text("REFEIÇÕES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800))),
                                Expanded(flex: 3, child: Text("TOTAL POLIFENÓIS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800))),
                                SizedBox(width: 90, child: Text("")),
                              ],
                            ),
                          ),
                        Divider(height: 1, color: Colors.green.shade200),
                        carregandoDias
                            ? Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                            : diasAgrupados.isEmpty
                                ? Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      "Sem histórico de refeição",
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 14),
                                    ),
                                  )
                                : Column(
                                    children: diasAgrupados.map((d) {
                                      DateTime? dataDia;
                                      try { dataDia = DateTime.parse(d['data'].toString()); } catch (e) {}
                                      final cor = _corDoStatus(d['classificacao']);
                                      return InkWell(
                                        onTap: () => _abrirDetalhesDoDia(paciente['id'], d['data'].toString(), cor),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                          child: Row(
                                            children: [
                                              SizedBox(width: 30, child: Icon(Icons.circle, size: 14, color: cor)),
                                              Expanded(flex: 3, child: Text(dataDia != null ? "${DateFormat('dd/MM/yyyy').format(dataDia)} (${_nomeDiaSemana(dataDia)})" : d['data'].toString(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                              Expanded(flex: 2, child: Text("${d['quantidade_refeicoes']}", style: TextStyle(fontSize: 13.5))),
                                              Expanded(flex: 3, child: Text(_formatarPolifenois(d['total_polifenois']), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: cor))),
                                              SizedBox(
                                                width: 90,
                                                child: TextButton(
                                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 0)),
                                                  onPressed: () => _abrirDetalhesDoDia(paciente['id'], d['data'].toString(), cor),
                                                  child: Text("VER DIA", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ],
                    ],
                  ),
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
                    cidade: cidadeCtrl.text,
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
                                  onTap: () => _abrirDetalhesRefeicaoMaster(r),
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
  void _abrirDetalhesRefeicaoMaster(Map<String, dynamic> refeicao) {
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

  Future<void> _salvarPaciente(int? id, String nome, String cpf, String email, String semana, String senha, bool isNovo,
    {String? rg, String? nasc, String? idade, String? cel, String? fixo, String? cep, String? log, String? num, String? comp,
     String? est, String? cidade, String? nac, String? nat, String? mae, String? med, String? crm, String? nut, String? crn}) async {

    setState(() => _carregandoPacientes = true);
    try {
      Uri url = isNovo
          ? Uri.parse("https://polifenois-backend.onrender.com/paciente-admin")
          : Uri.parse("https://polifenois-backend.onrender.com/pacientes/$id");

      var bodyData = {
        "nome": nome, "cpf": cpf, "email": email, "semana_gestacao": semana,
        "rg": rg, "data_nascimento": nasc, "idade": idade, "telefone": cel, "telefone_fixo": fixo,
        "cep": cep, "logradouro": log, "numero": num, "complemento": comp, "estado": est, "cidade": cidade,
        "nacionalidade": nac, "naturalidade": nat, "nome_mae": mae,
        "nome_medico": med, "crm_medico": crm, "nome_nutricionista": nut, "crn_nutricionista": crn
      };
      if (isNovo) bodyData["senha"] = senha;

      var response = isNovo
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarPacientes();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prontuário salvo com sucesso!"), backgroundColor: Colors.green));
      } else {
        setState(() => _carregandoPacientes = false);
      }
    } catch (e) {
      setState(() => _carregandoPacientes = false);
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
              setState(() {
                _pacientes.removeWhere((p) => p['id'] == id);
                _pacientesFiltradas.removeWhere((p) => p['id'] == id);
              });
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
        body: jsonEncode({"id_paciente": idPaciente, "id_admin": widget.usuario['id'], "senha_admin": senha}),
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
      body: Column(
        children: [
          Container(
            height: 34,
            color: Colors.white,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24),
            child: _RelogioTopo(),
          ),
          Divider(height: 1, thickness: 1.2, color: Colors.black87),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 280,
                  color: Color(0xFF1A237E),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset("assets/logo.png", height: 50),
                            SizedBox(height: 12),
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
                        title: Text("Cadastro de Gestantes", style: TextStyle(color: _indiceMenu == 1 ? Colors.white : Colors.white54, fontWeight: _indiceMenu == 1 ? FontWeight.bold : FontWeight.normal)),
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
                        leading: Icon(Icons.security, color: Colors.white54),
                        title: Text("Logins do Sistema", style: TextStyle(color: Colors.white54)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => LogsAcessoWeb()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.settings, color: Colors.white54),
                        title: Text("Configurações", style: TextStyle(color: Colors.white54)),
                        onTap: () => _abrirConfiguracoes(),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Monitoramento Estratégico", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _buscarEstatisticas,
                      icon: Icon(Icons.refresh, size: 18, color: Colors.white),
                      label: Text("ATUALIZAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A237E), padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              _cardCadastrosRecentes(),
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
          SizedBox(height: 40),
          Text("Distribuição Geográfica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          SizedBox(height: 20),
          _cardDistribuicaoGeografica(),
          SizedBox(height: 40),
          Text("Semáforo de Consumo Diário por Estado", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          SizedBox(height: 6),
          Text(
            "Quantidade de gestantes em cada situação HOJE, agrupadas por estado (só considera trimestres com monitoramento ativo).",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          SizedBox(height: 20),
          _cardSemaforoPorEstado(),
          SizedBox(height: 40),
          Text("Evolução de Cadastros (Últimos 3 Meses)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          SizedBox(height: 20),
          Center(child: _graficoEvolucaoMensal()),
        ],
      ),
    );
  }

  Widget _cardCadastrosRecentes() {
    final trinta = _v(_stats?['cadastros']?['ultimos_30_dias']);
    final semana = _v(_stats?['cadastros']?['ultima_semana']);
    return Container(
      width: 320,
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_up, color: Color(0xFF1A237E), size: 20),
            SizedBox(width: 8),
            Text("Novos cadastros", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 14)),
          ]),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trinta, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Últimos 30 dias", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(semana, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Última semana", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Mapeamento de UF para Região (usado no gráfico de distribuição por região)
  static const Map<String, String> _regiaoPorUF = {
    'AC': 'Norte', 'AP': 'Norte', 'AM': 'Norte', 'PA': 'Norte', 'RO': 'Norte', 'RR': 'Norte', 'TO': 'Norte',
    'AL': 'Nordeste', 'BA': 'Nordeste', 'CE': 'Nordeste', 'MA': 'Nordeste', 'PB': 'Nordeste', 'PE': 'Nordeste',
    'PI': 'Nordeste', 'RN': 'Nordeste', 'SE': 'Nordeste',
    'DF': 'Centro-Oeste', 'GO': 'Centro-Oeste', 'MT': 'Centro-Oeste', 'MS': 'Centro-Oeste',
    'ES': 'Sudeste', 'MG': 'Sudeste', 'RJ': 'Sudeste', 'SP': 'Sudeste',
    'PR': 'Sul', 'RS': 'Sul', 'SC': 'Sul',
  };

  static const List<Color> _paletaPizza = [
    Color(0xFF1A237E), Color(0xFF00897B), Color(0xFFE65100), Color(0xFF6A1B9A),
    Color(0xFFAD1457), Color(0xFF283593), Color(0xFF00695C), Color(0xFFBF360C),
    Color(0xFF4527A0), Color(0xFF880E4F), Color(0xFF37474F), Color(0xFF558B2F),
  ];

  Widget _cardDistribuicaoGeografica() {
    final List<dynamic> estadosRaw = _stats?['estados'] ?? [];

    // Estado -> total (ignora "NI"/vazio, que representa gestantes sem estado preenchido)
    List<MapEntry<String, int>> porEstado = estadosRaw
        .where((e) => (e['estado'] ?? 'NI').toString() != 'NI')
        .map((e) => MapEntry(e['estado'].toString(), int.tryParse(e['total'].toString()) ?? 0))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Agrupa por região a partir do mesmo dado de estado
    Map<String, int> porRegiaoMap = {};
    for (var e in estadosRaw) {
      final uf = (e['estado'] ?? 'NI').toString();
      final regiao = _regiaoPorUF[uf] ?? 'Não informado';
      final total = int.tryParse(e['total'].toString()) ?? 0;
      porRegiaoMap[regiao] = (porRegiaoMap[regiao] ?? 0) + total;
    }
    List<MapEntry<String, int>> porRegiao = porRegiaoMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 30,
        runSpacing: 30,
        children: [
          _blocoPizza("Gestantes por Estado", porEstado),
          _blocoPizza("Gestantes por Região", porRegiao),
        ],
      ),
    );
  }

  Widget _cardSemaforoPorEstado() {
    if (_carregandoSemaforo) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
      );
    }

    List<MapEntry<String, int>> _extrair(String chave) {
      final lista = _semaforoPorEstado?[chave] as List<dynamic>? ?? [];
      return lista.map((e) => MapEntry(e['estado'].toString(), int.tryParse(e['total'].toString()) ?? 0)).toList();
    }

    final vermelho = _extrair('vermelho');
    final amarelo = _extrair('amarelo');
    final verde = _extrair('verde');

    final semDadosDeTodo = vermelho.isEmpty && amarelo.isEmpty && verde.isEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: semDadosDeTodo
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  "Nenhuma gestante em trimestre monitorado com refeições registradas hoje.",
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 30,
              runSpacing: 30,
              children: [
                _blocoPizza("🔴 Exposição Elevada por Estado", vermelho),
                _blocoPizza("🟡 Atenção por Estado", amarelo),
                _blocoPizza("🟢 Consumo Adequado por Estado", verde),
              ],
            ),
    );
  }

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
                    painter: _LinhaConsumoPainter(dias: serie, limite: LIMITE_ADEQUADO_MG_UI, escalaMax: escalaMax),
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

  // Mantido como constante local de UI (espelha LIMITE_ADEQUADO_MG do backend).
  // Se o valor de referência mudar no backend, atualizar aqui também.
  static const double LIMITE_ADEQUADO_MG_UI = 1000;

  Widget _blocoPizza(String titulo, List<MapEntry<String, int>> dados) {
    final total = dados.fold<int>(0, (soma, e) => soma + e.value);
    return SizedBox(
      width: 320,
      child: Column(
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E))),
          SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text("Sem dados suficientes ainda", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            )
          else ...[
            SizedBox(
              width: 170, height: 170,
              child: CustomPaint(painter: _PizzaPainter(dados: dados, cores: _paletaPizza)),
            ),
            SizedBox(height: 14),
            // Legenda: cor + rótulo + percentual, limitado às maiores fatias pra não poluir
            ...dados.take(8).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final pct = total > 0 ? (e.value / total * 100) : 0;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: _paletaPizza[i % _paletaPizza.length], shape: BoxShape.circle)),
                    SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: TextStyle(fontSize: 12))),
                    Text("${e.value} (${pct.toStringAsFixed(0)}%)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _graficoEvolucaoMensal() {
    final List<dynamic> dados = _stats?['evolucao_mensal'] ?? [];
    const nomesMeses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

    Map<String, int> porMes = {};
    for (var d in dados) {
      porMes[d['mes'].toString()] = int.tryParse(d['total'].toString()) ?? 0;
    }

    DateTime hoje = DateTime.now();
    List<MapEntry<String, int>> serie = [];
    // Últimos 3 meses, sempre rolando a partir de hoje (funciona mesmo virando o ano,
    // ex: se hoje é fevereiro, mostra Dez/Jan/Fev).
    for (int i = 2; i >= 0; i--) {
      DateTime mesRef = DateTime(hoje.year, hoje.month - i, 1);
      String chave = "${mesRef.year}-${mesRef.month.toString().padLeft(2, '0')}";
      String rotulo = nomesMeses[mesRef.month - 1] + (mesRef.year != hoje.year ? "/${mesRef.year.toString().substring(2)}" : "");
      serie.add(MapEntry(rotulo, porMes[chave] ?? 0));
    }

    int maior = serie.isEmpty ? 1 : serie.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (maior == 0) maior = 1;

    return Container(
      width: 700,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: serie.map((e) {
          double alturaMax = 180;
          double altura = e.value == 0 ? 4 : (e.value / maior) * alturaMax;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(e.value.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              SizedBox(height: 4),
              Container(
                width: 30, height: altura,
                decoration: BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              SizedBox(height: 8),
              Text(e.key, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _avatarPaciente(Map paciente) {
    final foto = paciente['foto_perfil_url'];
    final temFoto = foto != null && foto.toString().length > 100;
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: temFoto ? MemoryImage(base64Decode(foto)) : null,
      child: !temFoto ? Icon(Icons.person, size: 20, color: Colors.grey.shade500) : null,
    );
  }

  Widget _campoFiltroData(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        // Agora aceita digitação livre (formato AAAA-MM-DD). O ícone de
        // calendário continua disponível como atalho para quem preferir escolher a data.
        keyboardType: TextInputType.datetime,
        decoration: PolifenoisTema.inputDecoracao(label, Icons.calendar_today).copyWith(
          isDense: true,
          hintText: 'AAAA-MM-DD',
          suffixIcon: IconButton(
            icon: Icon(Icons.calendar_today, size: 16),
            onPressed: () => _selecionarData(ctrl),
            tooltip: "Escolher no calendário",
          ),
        ),
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _grupoFiltro(String titulo, List<Widget> campos) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5)),
          SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: campos),
        ],
      ),
    );
  }

  Widget _buildPainelFiltros() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, color: PolifenoisTema.azulPrimario, size: 20),
                SizedBox(width: 8),
                Text("Filtros", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                _grupoFiltro("NOME", [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _filtroNome,
                      decoration: PolifenoisTema.inputDecoracao("Buscar por nome", Icons.search).copyWith(isDense: true),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
                _grupoFiltro("DATA DE CADASTRO (INICIAL / FINAL)", [
                  _campoFiltroData("Inicial", _filtroCadIni),
                  SizedBox(width: 8),
                  _campoFiltroData("Final", _filtroCadFim),
                ]),
                _grupoFiltro("NASCIMENTO / ANIVERSÁRIO (INICIAL / FINAL)", [
                  _campoFiltroData("Inicial", _filtroNascIni),
                  SizedBox(width: 8),
                  _campoFiltroData("Final", _filtroNascFim),
                ]),
                _grupoFiltro("IDADE (MÍN. / MÁX.)", [
                  SizedBox(
                    width: 70,
                    child: TextField(controller: _filtroIdadeMin, keyboardType: TextInputType.number,
                      decoration: PolifenoisTema.inputDecoracao("Mín.", Icons.cake).copyWith(isDense: true), style: TextStyle(fontSize: 12)),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(controller: _filtroIdadeMax, keyboardType: TextInputType.number,
                      decoration: PolifenoisTema.inputDecoracao("Máx.", Icons.cake).copyWith(isDense: true), style: TextStyle(fontSize: 12)),
                  ),
                ]),
                _grupoFiltro("LOCALIZAÇÃO (ESTADO / CIDADE)", [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: _filtroEstado,
                      decoration: PolifenoisTema.inputDecoracao("Estado", Icons.location_on).copyWith(isDense: true),
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                      items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                      onChanged: (v) {
                        setState(() => _filtroEstado = v ?? 'TODOS');
                        if (v != null && v != 'TODOS') {
                          _buscarCidadesPorEstado(v);
                        } else {
                          setState(() { _cidadesDoEstado = []; _filtroCidade = null; });
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      value: _filtroCidade,
                      isExpanded: true,
                      decoration: PolifenoisTema.inputDecoracao(
                        _carregandoCidadesFiltro ? "Carregando..." : "Cidade",
                        Icons.location_city,
                      ).copyWith(isDense: true),
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                      hint: Text(
                        _filtroEstado == 'TODOS' ? "Selecione um estado" : "Todas",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      items: _cidadesDoEstado.map((cidade) => DropdownMenuItem(value: cidade, child: Text(cidade, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (_filtroEstado == 'TODOS' || _carregandoCidadesFiltro)
                          ? null
                          : (v) => setState(() => _filtroCidade = v),
                    ),
                  ),
                ]),
                _grupoFiltro("ENGAJAMENTO", [
                  SizedBox(
                    width: 210,
                    child: CheckboxListTile(
                      value: _filtroSemRefeicoes,
                      onChanged: (v) => setState(() => _filtroSemRefeicoes = v ?? false),
                      title: Text("Sem histórico de refeições", style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ]),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _aplicarFiltros,
                  icon: Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text("APLICAR FILTROS", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                ),
                SizedBox(width: 10),
                TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: Icon(Icons.clear, size: 16),
                  label: Text("Limpar filtros (mostrar todos)"),
                ),
                Spacer(),
                Text("${_pacientesFiltradas.length} de ${_pacientes.length} gestantes", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ],
        ),
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
            children: [
              Text("Cadastro de Gestantes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              Spacer(),
              IconButton(icon: Icon(Icons.refresh, color: Color(0xFF1A237E)), onPressed: _carregarPacientes),
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
          _buildPainelFiltros(),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: _carregandoPacientes
                  ? Center(child: CircularProgressIndicator(color: PolifenoisTema.azulPrimario))
                  : _pacientesFiltradas.isEmpty
                      ? Center(child: Text(_pacientes.isEmpty ? "Nenhuma paciente encontrada." : "Nenhuma paciente corresponde aos filtros.", style: PolifenoisTema.corpoEstilo))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.resolveWith((states) => PolifenoisTema.azulClaroFundo),
                              columns: [
                                DataColumn(label: Text("Foto", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Nome", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Cidade", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Idade", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Nutricionista", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Sem. Gestação", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                                DataColumn(label: Text("Ações", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario))),
                              ],
                              rows: _pacientesFiltradas.map((p) {
                                bool validado = p['email_validado'] == true;
                                return DataRow(
                                  cells: [
                                    DataCell(_avatarPaciente(p)),
                                    DataCell(Text(p['nome'] ?? 'Sem nome')),
                                    DataCell(Text(p['cidade'] ?? '-')),
                                    DataCell(Text(p['idade']?.toString() ?? '-')),
                                    DataCell(Text(p['nome_nutricionista'] ?? '-')),
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

// =========================================================================
// RELÓGIO ISOLADO — atualiza só a si mesmo a cada segundo, sem recarregar
// o resto da tela (evita o "piscar" das fotos e de outros widgets).
// =========================================================================
class _RelogioTopo extends StatefulWidget {
  @override
  _RelogioTopoState createState() => _RelogioTopoState();
}

class _RelogioTopoState extends State<_RelogioTopo> {
  Timer? _timer;
  DateTime _agora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('dd/MM/yyyy HH:mm:ss').format(_agora),
      style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
    );
  }
}

// =========================================================================
// PINTOR DE GRÁFICO DE PIZZA — genérico, reaproveitado em qualquer card que
// precise de uma pizza (Estado, Região, e futuramente o semáforo por Estado).
// Não depende de nenhuma lib externa de gráficos.
// =========================================================================
class _PizzaPainter extends CustomPainter {
  final List<MapEntry<String, int>> dados;
  final List<Color> cores;

  _PizzaPainter({required this.dados, required this.cores});

  @override
  void paint(Canvas canvas, Size size) {
    final total = dados.fold<int>(0, (soma, e) => soma + e.value);
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double anguloInicial = -90 * (3.1415926535 / 180); // começa no topo (12h)

    for (int i = 0; i < dados.length; i++) {
      final valor = dados[i].value;
      if (valor == 0) continue;
      final fatia = (valor / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = cores[i % cores.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, anguloInicial, fatia, true, paint);
      anguloInicial += fatia;
    }

    // Círculo branco no meio para dar efeito "donut" (mais fácil de ler que pizza cheia)
    final centro = Offset(size.width / 2, size.height / 2);
    final raioMiolo = size.width * 0.32;
    canvas.drawCircle(centro, raioMiolo, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PizzaPainter oldDelegate) {
    return oldDelegate.dados != dados;
  }
}

// =========================================================================
// PINTOR DO GRÁFICO DE LINHA — evolução do consumo diário de polifenóis,
// com uma linha de referência tracejada no limite (1.000mg por padrão).
// Cada ponto é colorido conforme a classificação do dia (verde/amarelo/vermelho).
// =========================================================================
class _LinhaConsumoPainter extends CustomPainter {
  final List<dynamic> dias; // cada item: {data, total_polifenois, classificacao}
  final double limite;
  final double escalaMax;

  _LinhaConsumoPainter({required this.dias, required this.limite, required this.escalaMax});

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
      ..color = Color(0xFF1A237E)
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
  bool shouldRepaint(covariant _LinhaConsumoPainter oldDelegate) {
    return oldDelegate.dias != dias || oldDelegate.limite != limite || oldDelegate.escalaMax != escalaMax;
  }
}