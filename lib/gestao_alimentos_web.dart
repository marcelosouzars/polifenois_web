// ... (mantenha os imports e o início da classe iguais)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolifenoisTema.azulClaroFundo,
      appBar: AppBar(title: Text("Base de Alimentos - Super Base"), backgroundColor: PolifenoisTema.azulPrimario),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: _buscaController, decoration: PolifenoisTema.inputDecoracao("Buscar...", Icons.search))),
                SizedBox(width: 15),
                DropdownButton<String>(
                  value: _filtroOrigem,
                  items: ["TODOS", "EUR", "USA", "BRA"].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) { setState(() => _filtroOrigem = v!); _buscarAlimentos(); },
                ),
                SizedBox(width: 15),
                ElevatedButton(onPressed: () => _buscarAlimentos(pagina: 1), child: Text("BUSCAR")),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: Card(
                child: _carregando ? Center(child: CircularProgressIndicator()) : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text("Origem")),
                      DataColumn(label: Text("Código")),
                      DataColumn(label: Text("Nome")),
                      DataColumn(label: Text("Polifenóis (mg)")),
                      DataColumn(label: Text("Ações")),
                    ],
                    rows: _alimentos.map((a) => DataRow(cells: [
                      DataCell(Chip(label: Text(a['origem_dados'] ?? 'N/A'))),
                      DataCell(Text(a['codigo_origem']?.toString() ?? '')),
                      DataCell(Text(a['nome_alimento'] ?? '')),
                      DataCell(Text(a['polifenois_mg_100g']?.toString() ?? '0')),
                      DataCell(IconButton(icon: Icon(Icons.edit), onPressed: () => _abrirModalAlimento(alimento: a)))
                    ])).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }