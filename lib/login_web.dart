import 'package:flutter/material.dart';
import 'tema_padrao_web.dart'; // Importando nosso padrão visual

class LoginWeb extends StatefulWidget {
  @override
  _LoginWebState createState() => _LoginWebState();
}

class _LoginWebState extends State<LoginWeb> {
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo, // Fundo azul claro
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            padding: EdgeInsets.all(20),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              color: PolifenoisTema.brancoCard,
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo ou Ícone Profissional
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: PolifenoisTema.azulClaroFundo,
                        shape: BoxType.circle,
                      ),
                      child: Icon(Icons.shield_moon_outlined, size: 50, color: PolifenoisTema.azulPrimario),
                    ),
                    SizedBox(height: 20),
                    Text("VETIX POLIFENÓIS", style: PolifenoisTema.tituloEstilo),
                    Text("Gestão de Saúde e Nutrição", style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 40),
                    
                    // Campos com o Novo Padrão
                    TextField(
                      controller: _cpfController,
                      decoration: PolifenoisTema.inputDecoracao("Digite seu CPF", Icons.person_outline),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: PolifenoisTema.inputDecoracao("Sua Senha", Icons.lock_outline),
                    ),
                    
                    SizedBox(height: 30),
                    
                    _carregando 
                    ? CircularProgressIndicator() 
                    : ElevatedButton(
                        onPressed: () {
                          // Lógica de login aqui
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PolifenoisTema.azulPrimario,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("ENTRAR NO SISTEMA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    
                    SizedBox(height: 15),
                    TextButton(
                      onPressed: () {},
                      child: Text("Esqueceu a senha?", style: TextStyle(color: PolifenoisTema.azulDestaque)),
                    ),
                    
                    Divider(height: 40),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Primeira vez aqui? "),
                        GestureDetector(
                          onTap: () {
                            // Navegar para CADASTRO_USUARIO_WEB.DART
                          },
                          child: Text("Cadastre-se", style: TextStyle(color: PolifenoisTema.azulDestaque, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}