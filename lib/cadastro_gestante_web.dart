//
// cadastro_gestante_web.dart
//
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tema_padrao_web.dart';
import 'login_web.dart';

class CadastroGestanteWeb extends StatefulWidget {
  final Map<String, dynamic> usuario;
  CadastroGestanteWeb({required this.usuario});

  @override
  _CadastroGestanteWebState createState() => _CadastroGestanteWebState();
}

class _CadastroGestanteWebState extends State<CadastroGestanteWeb> {
  int _indiceMenu = 1; 
  final _formKey = GlobalKey<FormState>();
  
  // ===========================================================================
  // CONTROLADORES SOBERANOS DO MARCELO
  // ===========================================================================
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _rg = TextEditingController();
  final TextEditingController _idade = TextEditingController();
  final TextEditingController _endereco = TextEditingController();
  final TextEditingController _dataNasc = TextEditingController();
  final TextEditingController _semanas = TextEditingController();
  final TextEditingController _telFixo = TextEditingController();
  final TextEditingController _celular = TextEditingController();
  final TextEditingController _cep = TextEditingController();
  final TextEditingController _rua = TextEditingController();
  final TextEditingController _num = TextEditingController();
  final TextEditingController _comp = TextEditingController();
  final TextEditingController _nacionalidade = TextEditingController();
  final TextEditingController _natural = TextEditingController();
  final TextEditingController _mae = TextEditingController();
  final TextEditingController _medico = TextEditingController();
  final TextEditingController _crm = TextEditingController();
  final TextEditingController _nutri = TextEditingController();
  final TextEditingController _crn = TextEditingController();

  List<dynamic> _refeicoes = [];
  bool _carregandoRefeicoes = true;
  bool _salvando = false;
  String _unidade = 'mg';
  Map<String, dynamic>? _profissionalVinculado;
  bool _carregandoProfissional = true;
  bool _buscandoProfissional = false;
  final TextEditingController _codigoProfissionalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarRefeicoes();
    _preencherCampos();
    _carregarUnidade();
    _carregarProfissionalVinculado();
  }

  Future<void> _carregarProfissionalVinculado() async {
    setState(() => _carregandoProfissional = true);
    try {
      final res = await http.get(
        Uri.parse('https://polifenois-backend.onrender.com/meu-profissional/${widget.usuario['id']}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _profissionalVinculado = data['profissional']);
      }
    } catch (e) {
      // silencioso
    } finally {
      if (mounted) setState(() => _carregandoProfissional = false);
    }
  }

  Future<void> _buscarEVincularProfissional() async {
    final codigo = _codigoProfissionalCtrl.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Digite o CRM ou CRN do profissional.")));
      return;
    }

    setState(() => _buscandoProfissional = true);
    try {
      final res = await http.get(
        Uri.parse('https://polifenois-backend.onrender.com/buscar-profissional?codigo=$codigo'),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['erro'] ?? "Profissional não encontrado."), backgroundColor: Colors.red),
        );
        return;
      }

      final profissional = data['profissional'];
      final ehMedico = (profissional['crm_medico'] ?? '').toString().isNotEmpty;

      bool? confirmou = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Confirmar Vínculo"),
          content: Text(
            "Você será vinculada a:\n\n"
            "${profissional['nome']}\n"
            "${ehMedico ? 'CRM: ${profissional['crm_medico']}' : 'CRN: ${profissional['crn_nutricionista']}'}\n\n"
            "Esse profissional passará a acompanhar suas refeições registradas. Confirma?",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCELAR")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("CONFIRMAR")),
          ],
        ),
      );

      if (confirmou != true) return;

      final vincula = await http.post(
        Uri.parse('https://polifenois-backend.onrender.com/vincular-profissional'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"gestante_id": widget.usuario['id'], "profissional_id": profissional['id']}),
      );

      if (vincula.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vínculo atualizado!"), backgroundColor: Colors.green));
        _codigoProfissionalCtrl.clear();
        _carregarProfissionalVinculado();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro de conexão."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _buscandoProfissional = false);
    }
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
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("Configurações", style: TextStyle(color: PolifenoisTema.azulPrimario, fontWeight: FontWeight.bold)),
          content: Container(
            width: 340,
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

  void _preencherCampos() {
    _nome.text = widget.usuario['nome'] ?? '';
    _rg.text = widget.usuario['rg'] ?? '';
    _idade.text = widget.usuario['idade']?.toString() ?? '';
    _endereco.text = widget.usuario['endereco'] ?? '';
    _dataNasc.text = widget.usuario['data_nascimento'] != null ? widget.usuario['data_nascimento'].toString().split('T')[0] : '';
    _semanas.text = widget.usuario['semana_gestacao']?.toString() ?? '';
    _celular.text = widget.usuario['telefone'] ?? '';
    _telFixo.text = widget.usuario['telefone_fixo'] ?? '';
    _nacionalidade.text = widget.usuario['nacionalidade'] ?? '';
    _natural.text = widget.usuario['naturalidade'] ?? '';
    _mae.text = widget.usuario['nome_mae'] ?? '';
    _medico.text = widget.usuario['nome_medico'] ?? '';
    _crm.text = widget.usuario['crm_medico'] ?? '';
    _nutri.text = widget.usuario['nome_nutricionista'] ?? '';
    _crn.text = widget.usuario['crn_nutricionista'] ?? '';
    _cep.text = widget.usuario['cep'] ?? '';
    _rua.text = widget.usuario['logradouro'] ?? '';
    _num.text = widget.usuario['numero'] ?? '';
    _comp.text = widget.usuario['complemento'] ?? '';
  }

  Future<void> _carregarRefeicoes() async {
    setState(() => _carregandoRefeicoes = true);
    try {
      final res = await http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes-gestante/${widget.usuario['id']}"));
      if (res.statusCode == 200) {
        setState(() => _refeicoes = jsonDecode(res.body)['refeicoes']);
      }
    } finally {
      setState(() => _carregandoRefeicoes = false);
    }
  }

  // ===========================================================================
  // LÓGICA DE GESTÃO DE FOTOS E REFEIÇÕES
  // ===========================================================================

  void _abrirDetalhesRefeicao(Map<String, dynamic> refeicao) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Gestão da Refeição"),
              IconButton(
                icon: Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () => _excluirRefeicaoInteira(refeicao['id']),
              )
            ],
          ),
          content: Container(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _modalOpcoesFoto(refeicao['id'], setModalState),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: refeicao['foto_prato_url'] != null && refeicao['foto_prato_url'].length > 500
                            ? Image.memory(base64Decode(refeicao['foto_prato_url']), height: 300, width: double.infinity, fit: BoxFit.cover)
                            : Image.network(refeicao['foto_prato_url'] ?? '', height: 300, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        bottom: 10, right: 10,
                        child: FloatingActionButton.small(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: () => _modalOpcoesFoto(refeicao['id'], setModalState),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text("Polifenóis Totais: ${_formatarPolifenois(refeicao['total_polifenois_refeicao'])}", 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                  Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Itens do Prato", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ElevatedButton.icon(
                        onPressed: () => _modalNovoItem(refeicao['id'], setModalState), 
                        icon: Icon(Icons.add), label: Text("Adicionar Item")
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  FutureBuilder<http.Response>(
                    future: http.get(Uri.parse("https://polifenois-backend.onrender.com/refeicoes/${refeicao['id']}/itens")),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                      List itens = jsonDecode(snapshot.data!.body);
                      return Column(
                        children: itens.map((it) => Card(
                          child: ListTile(
                            leading: Icon(Icons.restaurant_menu, color: PolifenoisTema.azulPrimario),
                            title: Text(it['nome_alimento'], style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${it['peso_estimado_gramas']}g | ${_formatarPolifenois(it['polifenois_consumidos_item'])}"),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _excluirApenasItem(it['id'], refeicao['id'], setModalState),
                            ),
                          ),
                        )).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("FECHAR")),
          ],
        ),
      ),
    );
  }

  // --- NOVA FUNÇÃO: MODAL DE OPÇÕES DA FOTO ---
  void _modalOpcoesFoto(String refeicaoId, StateSetter modalRefresh) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Foto da Refeição"),
        content: Text("O que você deseja fazer com a imagem desta refeição?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final confirm = await _confirmar("Excluir Foto?", "Realmente deseja remover a foto desta refeição?");
              if (confirm) {
                await _atualizarFotoNoBanco(refeicaoId, "", modalRefresh);
              }
            }, 
            child: Text("EXCLUIR FOTO", style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _selecionarEConfirmarFoto(refeicaoId, modalRefresh);
            }, 
            child: Text("ALTERAR FOTO")
          ),
        ],
      ),
    );
  }

  // --- NOVA FUNÇÃO: EXPLORER + SELEÇÃO + 3 BOTÕES ---
  void _selecionarEConfirmarFoto(String refeicaoId, StateSetter modalRefresh) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      String base64Foto = base64Encode(result.files.first.bytes!);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Confirmar Substituição"),
          content: Text("A foto foi selecionada. Como deseja salvar?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () async {
                Navigator.pop(context);
                await _atualizarFotoNoBanco(refeicaoId, base64Foto, modalRefresh);
              }, 
              child: Text("SALVAR (SEM IA)")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(context);
                await _atualizarFotoNoBanco(refeicaoId, base64Foto, modalRefresh);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Análise de IA estará disponível em BREVE! Foto salva.")));
              }, 
              child: Text("SALVAR COM IA")
            ),
          ],
        ),
      );
    }
  }

  Future<void> _atualizarFotoNoBanco(String id, String base64, StateSetter modalRefresh) async {
    try {
      final res = await http.put(
        Uri.parse("https://polifenois-backend.onrender.com/refeicao-foto/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"foto_base64": base64}),
      );
      if (res.statusCode == 200) {
        modalRefresh(() {}); // Atualiza o modal
        _carregarRefeicoes(); // Atualiza o dashboard
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Foto atualizada com sucesso!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      print("Erro ao atualizar foto: $e");
    }
  }

  // --- RESTANTE DAS FUNÇÕES (ADICIONAR/EXCLUIR ITENS) ---
  void _modalNovoItem(String refeicaoId, StateSetter modalRefresh) {
    TextEditingController _itNome = TextEditingController();
    TextEditingController _itPeso = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Novo Alimento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _itNome, decoration: InputDecoration(labelText: "Nome do Alimento")),
            TextField(controller: _itPeso, decoration: InputDecoration(labelText: "Peso em Gramas"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              await http.post(
                Uri.parse("https://polifenois-backend.onrender.com/refeicao-item-manual"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "refeicao_id": refeicaoId,
                  "nome_alimento": _itNome.text,
                  "peso_gramas": int.parse(_itPeso.text),
                  "polifenois_100g": 5.0
                }),
              );
              Navigator.pop(context);
              modalRefresh(() {});
              _carregarRefeicoes();
            }, 
            child: Text("ADICIONAR")
          ),
        ],
      ),
    );
  }

  Future<void> _excluirRefeicaoInteira(String id) async {
    final confirm = await _confirmar("Excluir Refeição?", "Deseja apagar esta refeição permanentemente?");
    if (confirm) {
      await http.delete(Uri.parse("https://polifenois-backend.onrender.com/refeicoes/$id"));
      Navigator.pop(context);
      _carregarRefeicoes();
    }
  }

  Future<void> _excluirApenasItem(String id, String refeicaoId, StateSetter modalRefresh) async {
    await http.delete(Uri.parse("https://polifenois-backend.onrender.com/refeicao-item/$id/$refeicaoId"));
    modalRefresh(() {}); 
    _carregarRefeicoes();
  }

  Future<bool> _confirmar(String titulo, String msg) async {
    return await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo), content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text("NÃO")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text("SIM")),
        ],
      )
    ) ?? false;
  }

  // ===========================================================================
  // INTERFACE PRINCIPAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      body: Row(
        children: [
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_pin, size: 60, color: PolifenoisTema.azulPrimario),
                      SizedBox(height: 10),
                      Text(_nome.text, style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: _indiceMenu == 1 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Minhas Refeições"),
                  onTap: () => setState(() => _indiceMenu = 1),
                ),
                ListTile(
                  leading: Icon(Icons.badge, color: _indiceMenu == 0 ? PolifenoisTema.azulPrimario : Colors.grey),
                  title: Text("Dados Cadastrais"),
                  onTap: () => setState(() => _indiceMenu = 0),
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.grey),
                  title: Text("Configurações"),
                  onTap: () => _abrirConfiguracoes(),
                ),
                Spacer(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text("Sair", style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => LoginWeb())),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(child: _indiceMenu == 1 ? _buildDashboardRefeicoes() : _buildFormulario()),
        ],
      ),
    );
  }

  Widget _buildDashboardRefeicoes() {
    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Minhas Refeições", style: PolifenoisTema.tituloEstilo),
          SizedBox(height: 30),
          Expanded(
            child: _carregandoRefeicoes 
              ? Center(child: CircularProgressIndicator()) 
              : _refeicoes.isEmpty 
                ? Center(child: Text("Nenhuma refeição encontrada."))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85,
                    ),
                    itemCount: _refeicoes.length,
                    itemBuilder: (context, i) {
                      final r = _refeicoes[i];
                      return GestureDetector(
                        onTap: () => _abrirDetalhesRefeicao(r),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    r['foto_prato_url'] != null && r['foto_prato_url'].toString().length > 500
                                      ? Image.memory(base64Decode(r['foto_prato_url']), fit: BoxFit.cover, width: double.infinity)
                                      : Image.network(r['foto_prato_url'] ?? '', fit: BoxFit.cover, width: double.infinity),
                                    Positioned(
                                      top: 5, right: 5,
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                        child: Icon(Icons.edit, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['tipo_refeicao']?.toString().toUpperCase() ?? 'REFEIÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    Text(_formatarPolifenois(r['total_polifenois_refeicao']), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  // --- SEU FORMULÁRIO DE PERFIL COMPLETO (MANTIDO) ---
  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(40),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Meus Dados Cadastrais", style: PolifenoisTema.tituloEstilo),
                Divider(height: 40),
                Text("Dados Principais e Saúde", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(flex: 2, child: TextFormField(controller: _nome, decoration: PolifenoisTema.inputDecoracao("Nome Completo", Icons.person))),
                  SizedBox(width: 15),
                  Expanded(child: _campoInativo("CPF", widget.usuario['cpf'])),
                  SizedBox(width: 15),
                  Expanded(child: _campoInativo("E-mail", widget.usuario['email'])),
                ]),
                SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _rg, decoration: PolifenoisTema.inputDecoracao("RG", Icons.badge))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _idade, keyboardType: TextInputType.number, decoration: PolifenoisTema.inputDecoracao("Idade", Icons.cake))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _dataNasc, decoration: PolifenoisTema.inputDecoracao("Nascimento", Icons.calendar_today))),
                  SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _semanas, keyboardType: TextInputType.number, decoration: PolifenoisTema.inputDecoracao("Semana", Icons.pregnant_woman))),
                ]),
                SizedBox(height: 30),
                Text("Meu Profissional", style: TextStyle(fontWeight: FontWeight.bold, color: PolifenoisTema.azulPrimario)),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_carregandoProfissional)
                        Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                      else if (_profissionalVinculado != null) ...[
                        Row(
                          children: [
                            Icon(Icons.verified_user, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_profissionalVinculado!['nome'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  (_profissionalVinculado!['crm_medico'] ?? '').toString().isNotEmpty
                                      ? "CRM: ${_profissionalVinculado!['crm_medico']}"
                                      : "CRN: ${_profissionalVinculado!['crn_nutricionista']}",
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text("Quer trocar de profissional? Digite o novo CRM/CRN abaixo.", style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                      ] else
                        Text("Você ainda não tem um médico ou nutricionista vinculado.", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codigoProfissionalCtrl,
                              decoration: PolifenoisTema.inputDecoracao("CRM ou CRN do profissional", Icons.badge),
                            ),
                          ),
                          SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _buscandoProfissional ? null : _buscarEVincularProfissional,
                              style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario),
                              child: _buscandoProfissional
                                  ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text("Vincular", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                _salvando ? Center(child: CircularProgressIndicator()) : ElevatedButton(
                  onPressed: () {}, 
                  style: ElevatedButton.styleFrom(backgroundColor: PolifenoisTema.azulPrimario, minimumSize: Size(double.infinity, 60)),
                  child: Text("GUARDAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoInativo(String label, String? valor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text(valor ?? '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}