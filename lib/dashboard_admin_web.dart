const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
// NOVO SDK UNIFICADO DO GOOGLE APLICADO
const { GoogleGenAI } = require("@google/genai");
const { Resend } = require('resend'); 
const dns = require('dns'); 
require('dotenv').config();

// SOLUÇÃO PARA O RENDER: Força IPv4 para evitar erros de conexão
dns.setDefaultResultOrder('ipv4first');

const app = express();
const resend = new Resend(process.env.RESEND_API_KEY);

app.use(cors({ 
  origin: '*', 
  methods: ['GET', 'POST', 'PUT', 'DELETE'], 
  allowedHeaders: ['Content-Type', 'Authorization'] 
}));

app.use(express.json({ limit: '50mb' })); 

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

pool.on('connect', () => {
  console.log('✅ DATABASE: Neon conectado com sucesso!');
});

// INICIALIZAÇÃO DO NOVO MOTOR DEFINITIVO
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

// =========================================================================
// FUNÇÕES DE UTILIDADE E BLINDAGEM
// =========================================================================

function formatarDataParaBanco(dataRaw) {
    if (!dataRaw || dataRaw.trim() === '') return null;
    let texto = dataRaw.toString();
    if (/^\d{4}-\d{2}-\d{2}$/.test(texto)) return texto;
    let apenasNumeros = texto.replace(/\D/g, "");
    if (apenasNumeros.length === 8) {
        let dia = apenasNumeros.substring(0, 2);
        let mes = apenasNumeros.substring(2, 4);
        let ano = apenasNumeros.substring(4, 8);
        return `${ano}-${mes}-${dia}`;
    }
    return null;
}

function calcularIdade(dataNascimento) {
    if (!dataNascimento) return null;
    try {
        const hoje = new Date();
        const nascimento = new Date(dataNascimento);
        let idade = hoje.getFullYear() - nascimento.getFullYear();
        const m = hoje.getMonth() - nascimento.getMonth();
        if (m < 0 || (m === 0 && hoje.getDate() < nascimento.getDate())) {
            idade--;
        }
        return isNaN(idade) ? null : idade;
    } catch (e) { return null; }
}

const extrairJSON = (texto) => {
  try {
    const inicio = texto.indexOf('{');
    const fim = texto.lastIndexOf('}') + 1;
    return (inicio !== -1 && fim !== -1) ? texto.substring(inicio, fim) : texto;
  } catch (e) { return texto; }
};

// =========================================================================
// ROTAS DE GESTÃO DA SUPER BASE NUTRICIONAL (CRUD UNIFICADO)
// =========================================================================

app.get('/base-nutricional', async (req, res) => {
  const { busca, pagina = 1, limite = 50, origem = "TODOS" } = req.query;
  const offset = (pagina - 1) * limite;

  try {
    let query = `SELECT * FROM base_nutricional_internacional WHERE 1=1`;
    const queryParams = [];

    if (busca) {
      query += ` AND (nome_alimento ILIKE $1 OR compound ILIKE $1 OR categoria ILIKE $1) `;
      queryParams.push(`%${busca}%`);
    }

    if (origem !== "TODOS") {
      query += ` AND origem_dados = $${queryParams.length + 1} `;
      queryParams.push(origem);
    }

    query += ` ORDER BY nome_alimento ASC LIMIT $${queryParams.length + 1} OFFSET $${queryParams.length + 2}`;
    queryParams.push(limite, offset);

    const result = await pool.query(query, queryParams);
    
    let countQuery = `SELECT COUNT(*) FROM base_nutricional_internacional WHERE 1=1`;
    const countParams = [];
    if (busca) {
      countQuery += ` AND (nome_alimento ILIKE $1 OR compound ILIKE $1 OR categoria ILIKE $1)`;
      countParams.push(`%${busca}%`);
    }
    if (origem !== "TODOS") {
        countQuery += ` AND origem_dados = $${countParams.length + 1}`;
        countParams.push(origem);
    }
    const countResult = await pool.query(countQuery, countParams);

    res.json({
      sucesso: true,
      alimentos: result.rows,
      total: parseInt(countResult.rows[0].count),
      pagina: parseInt(pagina),
      totalPaginas: Math.ceil(parseInt(countResult.rows[0].count) / limite)
    });
  } catch (error) {
    console.error("ERRO NA CONSULTA:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

app.post('/base-nutricional', async (req, res) => {
  const { nome, total_polifenois, origem_dados = "BRA", compound = null, units = "mg/100g", categoria = "Geral" } = req.body;
  try {
    const codigo_origem = 'BR' + Date.now().toString().slice(-6);
    
    await pool.query(
      'INSERT INTO base_nutricional_internacional (codigo_origem, nome_alimento, polifenois_mg_100g, origem_dados, compound, units, categoria) VALUES ($1, $2, $3, $4, $5, $6, $7)', 
      [codigo_origem, nome, parseFloat(total_polifenois) || 0, origem_dados, compound, units, categoria]
    );
    
    res.json({ sucesso: true, codigo_origem });
  } catch (error) {
    console.error("ERRO AO INCLUIR NA BASE:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

app.put('/base-nutricional/:codigo_origem', async (req, res) => {
  const { codigo_origem } = req.params;
  const { nome, total_polifenois, compound, categoria } = req.body;
  try {
    await pool.query(
      'UPDATE base_nutricional_internacional SET nome_alimento = $1, polifenois_mg_100g = $2, compound = $3, categoria = $4 WHERE codigo_origem = $5', 
      [nome, parseFloat(total_polifenois) || 0, compound, categoria, codigo_origem]
    );
    res.json({ sucesso: true });
  } catch (error) {
    console.error("ERRO AO ALTERAR NA BASE:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

app.delete('/base-nutricional/:codigo_origem', async (req, res) => {
  const { codigo_origem } = req.params;
  try {
    await pool.query('DELETE FROM base_nutricional_internacional WHERE codigo_origem = $1', [codigo_origem]);
    res.json({ sucesso: true });
  } catch (error) {
    console.error("ERRO AO EXCLUIR NA BASE:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// =========================================================================
// ROTA: ATUALIZAR FOTO DE PERFIL 
// =========================================================================
app.put('/atualizar-foto-perfil', async (req, res) => {
  const { usuario_id, foto_base64 } = req.body;
  try {
    await pool.query("UPDATE users SET foto_perfil_url = $1 WHERE id = $2", [foto_base64, usuario_id]);
    res.json({ sucesso: true, mensagem: "Foto atualizada no Neon!" });
  } catch (error) {
    console.error("ERRO AO SALVAR FOTO:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// ATUALIZAÇÃO DE PERFIL PELA PRÓPRIA GESTANTE (App e Web) - rota que faltava
app.post('/atualizar-perfil', async (req, res) => {
  const {
    id, email, telefone, logradouro, cidade, numero, complemento, cep, estado,
    nacionalidade, naturalidade, nome_mae, nome_medico, crm_medico,
    nome_nutricionista, crn_nutricionista, telefone_fixo, rg, data_nascimento, semana_gestacao
  } = req.body;
  try {
    const nascBanco = data_nascimento ? formatarDataParaBanco(data_nascimento) : null;
    await pool.query(
      `UPDATE users SET
        email = COALESCE($1, email),
        telefone = COALESCE($2, telefone),
        logradouro = COALESCE($3, logradouro),
        cidade = COALESCE($4, cidade),
        numero = COALESCE($5, numero),
        complemento = COALESCE($6, complemento),
        cep = COALESCE($7, cep),
        nacionalidade = COALESCE($8, nacionalidade),
        naturalidade = COALESCE($9, naturalidade),
        nome_mae = COALESCE($10, nome_mae),
        nome_medico = COALESCE($11, nome_medico),
        crm_medico = COALESCE($12, crm_medico),
        nome_nutricionista = COALESCE($13, nome_nutricionista),
        crn_nutricionista = COALESCE($14, crn_nutricionista),
        telefone_fixo = COALESCE($15, telefone_fixo),
        rg = COALESCE($16, rg),
        data_nascimento = COALESCE($17, data_nascimento),
        semana_gestacao = COALESCE($18, semana_gestacao),
        estado = COALESCE($19, estado)
      WHERE id = $20`,
      [email, telefone, logradouro, cidade, numero, complemento, cep,
       nacionalidade, naturalidade, nome_mae, nome_medico, crm_medico,
       nome_nutricionista, crn_nutricionista, telefone_fixo, rg, nascBanco,
       semana_gestacao ? parseInt(semana_gestacao) : null, estado, id]
    );
    res.status(200).json({ sucesso: true, mensagem: "Perfil atualizado com sucesso!" });
  } catch (error) {
    console.error("ERRO AO ATUALIZAR PERFIL:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// =========================================================================
// ROTA: DASHBOARD MASTER (ESTATÍSTICAS E CRUD DE PACIENTES COMPLETO)
// =========================================================================
app.get('/dashboard-master-stats', async (req, res) => {
  try {
    const stats = await pool.query(`
      SELECT 
        (SELECT COUNT(*)::int FROM users WHERE tipo_usuario = 'gestante') as total_gestantes,
        (SELECT COALESCE(AVG(NULLIF(idade, 0)), 0) FROM users WHERE tipo_usuario = 'gestante') as idade_media,
        (SELECT COUNT(*)::int FROM users WHERE nome_medico IS NOT NULL AND nome_medico != '' AND tipo_usuario = 'gestante') as com_medico,
        (SELECT COUNT(*)::int FROM users WHERE (nome_medico IS NULL OR nome_medico = '') AND tipo_usuario = 'gestante') as sem_medico,
        (SELECT COUNT(*)::int FROM users WHERE nome_nutricionista IS NOT NULL AND nome_nutricionista != '' AND tipo_usuario = 'gestante') as com_nutri,
        (SELECT COUNT(*)::int FROM users WHERE (nome_nutricionista IS NULL OR nome_nutricionista = '') AND tipo_usuario = 'gestante') as sem_nutri,
        (SELECT COUNT(*)::int FROM users u WHERE u.tipo_usuario = 'gestante' AND NOT EXISTS (SELECT 1 FROM refeicoes r WHERE r.usuario_id = u.id)) as sem_refeicoes,
        (SELECT COUNT(*)::int FROM users WHERE COALESCE(semana_gestacao, 0) <= 13 AND tipo_usuario = 'gestante') as t1,
        (SELECT COUNT(*)::int FROM users WHERE COALESCE(semana_gestacao, 0) BETWEEN 14 AND 26 AND tipo_usuario = 'gestante') as t2,
        (SELECT COUNT(*)::int FROM users WHERE COALESCE(semana_gestacao, 0) >= 27 AND tipo_usuario = 'gestante') as t3,
        (SELECT COUNT(*)::int FROM users WHERE tipo_usuario = 'gestante' AND data_cadastro >= NOW() - INTERVAL '30 days') as cad_30d,
        (SELECT COUNT(*)::int FROM users WHERE tipo_usuario = 'gestante' AND data_cadastro >= NOW() - INTERVAL '7 days') as cad_7d
    `);

    const porEstado = await pool.query(`
      SELECT COALESCE(estado, 'NI') as estado, COUNT(*)::int as total 
      FROM users 
      WHERE tipo_usuario = 'gestante' 
      GROUP BY estado
    `);

    const evolucaoMensal = await pool.query(`
      SELECT TO_CHAR(data_cadastro, 'YYYY-MM') as mes, COUNT(*)::int as total
      FROM users
      WHERE tipo_usuario = 'gestante' AND data_cadastro >= DATE_TRUNC('year', NOW())
      GROUP BY mes
      ORDER BY mes ASC
    `);

    const s = stats.rows[0];

    res.json({
      total_gestantes: s.total_gestantes || 0,
      estados: porEstado.rows || [],
      cadastros: {
        ultimos_30_dias: s.cad_30d || 0,
        ultima_semana: s.cad_7d || 0
      },
      evolucao_mensal: evolucaoMensal.rows || [],
      saude: {
        com_medico: s.com_medico || 0,
        sem_medico: s.sem_medico || 0,
        com_nutri: s.com_nutri || 0,
        sem_nutri: s.sem_nutri || 0
      },
      engajamento: {
        sem_refeicoes: s.sem_refeicoes || 0
      },
      gestacional: {
        idade_media: parseFloat(s.idade_media || 0).toFixed(1),
        trimestre1: s.t1 || 0,
        trimestre2: s.t2 || 0,
        trimestre3: s.t3 || 0
      }
    });
  } catch (error) {
    console.error("ERRO DASHBOARD STATS:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// GET - LISTAR PACIENTES (TODOS OS CAMPOS PARA O CRM + TOTAL DE REFEIÇÕES PARA FILTRO)
app.get('/pacientes', async (req, res) => {
  const { profissional_id } = req.query;
  try {
    let query = `
      SELECT u.*, 
        COALESCE((SELECT COUNT(*) FROM refeicoes r WHERE r.usuario_id = u.id), 0)::int as total_refeicoes
      FROM users u
      WHERE u.tipo_usuario = 'gestante'
    `;
    const params = [];
    if (profissional_id) {
      params.push(profissional_id);
      query += ` AND u.profissional_id = $${params.length}`;
    }
    query += ` ORDER BY u.nome ASC`;

    const result = await pool.query(query, params);
    res.status(200).json({ sucesso: true, pacientes: result.rows });
  } catch (error) { 
    console.error("ERRO GET PACIENTES:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message }); 
  }
});

// BUSCA UM PROFISSIONAL PELO CRM OU CRN (para a gestante confirmar antes de vincular)
app.get('/buscar-profissional', async (req, res) => {
  const { codigo } = req.query;
  if (!codigo) return res.status(400).json({ sucesso: false, erro: "Informe o CRM ou CRN." });
  try {
    const result = await pool.query(
      `SELECT id, nome, crm_medico, crn_nutricionista FROM users 
       WHERE (crm_medico = $1 OR crn_nutricionista = $1) AND (tipo_usuario = 'admin' OR tipo_usuario = 'medico')`,
      [codigo]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ sucesso: false, erro: "Nenhum profissional encontrado com esse CRM/CRN." });
    }
    res.json({ sucesso: true, profissional: result.rows[0] });
  } catch (error) {
    console.error("ERRO BUSCAR PROFISSIONAL:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// CONFIRMA O VÍNCULO ENTRE A GESTANTE E O PROFISSIONAL
app.post('/vincular-profissional', async (req, res) => {
  const { gestante_id, profissional_id } = req.body;
  try {
    await pool.query("UPDATE users SET profissional_id = $1 WHERE id = $2", [profissional_id, gestante_id]);
    res.json({ sucesso: true, mensagem: "Vínculo atualizado com sucesso." });
  } catch (error) {
    console.error("ERRO VINCULAR PROFISSIONAL:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// DEVOLVE O PROFISSIONAL VINCULADO A UMA GESTANTE (para exibir na tela dela)
app.get('/meu-profissional/:id', async (req, res) => {
  try {
    const g = await pool.query("SELECT profissional_id FROM users WHERE id = $1", [req.params.id]);
    if (g.rows.length === 0 || !g.rows[0].profissional_id) {
      return res.json({ sucesso: true, profissional: null });
    }
    const p = await pool.query(
      "SELECT id, nome, crm_medico, crn_nutricionista FROM users WHERE id = $1",
      [g.rows[0].profissional_id]
    );
    res.json({ sucesso: true, profissional: p.rows[0] || null });
  } catch (error) {
    console.error("ERRO MEU PROFISSIONAL:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// POST - INCLUIR NOVO PACIENTE VIA ADMIN (TODOS OS CAMPOS)
app.post('/paciente-admin', async (req, res) => {
  const { 
    nome, cpf, email, senha, rg, data_nascimento, idade, telefone, telefone_fixo, 
    cep, logradouro, numero, complemento, estado, cidade, nacionalidade, naturalidade, 
    nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, semana_gestacao,
    profissional_id
  } = req.body;
  
  try {
    const cpfLimpo = cpf ? cpf.replace(/\D/g, '') : '';
    const nascBanco = formatarDataParaBanco(data_nascimento);
    const idadeFinal = idade ? parseInt(idade) : calcularIdade(nascBanco);

    await pool.query(
      `INSERT INTO users (
        nome, cpf, email, senha, tipo_usuario, email_validado, rg, data_nascimento, idade, 
        telefone, telefone_fixo, cep, logradouro, numero, complemento, estado, cidade, nacionalidade, 
        naturalidade, nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, semana_gestacao,
        profissional_id
      ) VALUES ($1, $2, $3, $4, 'gestante', true, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24)`,
      [
        nome, cpfLimpo, email, senha, rg, nascBanco, idadeFinal, telefone, telefone_fixo, 
        cep, logradouro, numero, complemento, estado, cidade, nacionalidade, naturalidade, 
        nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, parseInt(semana_gestacao) || 0,
        profissional_id || null
      ]
    );
    res.status(201).json({ sucesso: true });
  } catch (error) { 
    console.error("ERRO POST PACIENTE ADMIN:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message }); 
  }
});

// PUT - ATUALIZAR PACIENTE (TODOS OS CAMPOS)
app.put('/pacientes/:id', async (req, res) => {
  const { id } = req.params;
  const { 
    nome, cpf, email, rg, data_nascimento, idade, telefone, telefone_fixo, 
    cep, logradouro, numero, complemento, estado, cidade, nacionalidade, naturalidade, 
    nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, semana_gestacao 
  } = req.body;
  
  try {
    const cpfLimpo = cpf ? cpf.replace(/\D/g, '') : '';
    const nascBanco = formatarDataParaBanco(data_nascimento);
    const idadeFinal = idade ? parseInt(idade) : calcularIdade(nascBanco);

    await pool.query(
      `UPDATE users SET 
        nome = $1, cpf = $2, email = $3, rg = $4, data_nascimento = $5, idade = $6, 
        telefone = $7, telefone_fixo = $8, cep = $9, logradouro = $10, numero = $11, 
        complemento = $12, estado = $13, cidade = $14, nacionalidade = $15, naturalidade = $16, 
        nome_mae = $17, nome_medico = $18, crm_medico = $19, nome_nutricionista = $20, 
        crn_nutricionista = $21, semana_gestacao = $22 
      WHERE id = $23`,
      [
        nome, cpfLimpo, email, rg, nascBanco, idadeFinal, telefone, telefone_fixo, 
        cep, logradouro, numero, complemento, estado, cidade, nacionalidade, naturalidade, 
        nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, parseInt(semana_gestacao) || 0, id
      ]
    );
    res.status(200).json({ sucesso: true });
  } catch (error) { 
    console.error("ERRO PUT PACIENTES:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message }); 
  }
});

// DELETE - EXCLUIR PACIENTE (Com limpeza em cascata)
app.delete('/pacientes/:id', async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM refeicoes_itens WHERE refeicao_id IN (SELECT id FROM refeicoes WHERE usuario_id = $1)', [id]);
    await client.query('DELETE FROM refeicoes WHERE usuario_id = $1', [id]);
    await client.query('DELETE FROM logs_acesso WHERE usuario_id = $1', [id]);
    await client.query('DELETE FROM users WHERE id = $1', [id]);
    await client.query('COMMIT');
    res.status(200).json({ sucesso: true });
  } catch (error) { 
    await client.query('ROLLBACK');
    console.error("ERRO DELETE PACIENTES:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message }); 
  } finally {
    client.release();
  }
});

// VALIDAÇÃO COM SENHA (LIBERAÇÃO)
app.post('/validar-manual', async (req, res) => {
  const { id_paciente, id_admin, senha_admin } = req.body;
  try {
    const checkAdmin = await pool.query(
      "SELECT id FROM users WHERE id = $1 AND senha = $2 AND (tipo_usuario = 'master' OR tipo_usuario = 'admin' OR tipo_usuario = 'medico')", 
      [id_admin, senha_admin]
    );
    
    if (checkAdmin.rows.length > 0) {
      await pool.query("UPDATE users SET email_validado = true WHERE id = $1", [id_paciente]);
      res.status(200).json({ sucesso: true });
    } else {
      res.status(401).json({ sucesso: false, erro: 'Senha inválida ou sem permissão.' });
    }
  } catch (error) { 
    console.error("ERRO VALIDAR MANUAL:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message }); 
  }
});

// =========================================================================
// ROTAS DE GESTÃO DE ITENS E FOTOS
// =========================================================================

app.delete('/refeicoes/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM refeicoes_itens WHERE refeicao_id = $1', [id]);
    await pool.query('DELETE FROM refeicoes WHERE id = $1', [id]);
    res.json({ sucesso: true });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

app.post('/refeicao-item-manual', async (req, res) => {
  const { refeicao_id, nome_alimento, peso_gramas, polifenois_100g } = req.body;
  try {
    const consumido = (peso_gramas * polifenois_100g) / 100;
    await pool.query(
      `INSERT INTO refeicoes_itens (refeicao_id, nome_alimento, peso_estimado_gramas, fator_polifenol_aplicado, polifenois_consumidos_item) VALUES ($1, $2, $3, $4, $5)`,
      [refeicao_id, nome_alimento, peso_gramas, polifenois_100g, consumido]
    );
    await pool.query(`UPDATE refeicoes SET total_polifenois_refeicao = (SELECT SUM(polifenois_consumidos_item) FROM refeicoes_itens WHERE refeicao_id = $1) WHERE id = $1`, [refeicao_id]);
    res.json({ sucesso: true });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

app.delete('/refeicao-item/:id/:refeicao_id', async (req, res) => {
  const { id, refeicao_id } = req.params;
  try {
    await pool.query('DELETE FROM refeicoes_itens WHERE id = $1', [id]);
    await pool.query(`UPDATE refeicoes SET total_polifenois_refeicao = COALESCE((SELECT SUM(polifenois_consumidos_item) FROM refeicoes_itens WHERE refeicao_id = $1), 0) WHERE id = $1`, [refeicao_id]);
    res.json({ sucesso: true });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

app.put('/refeicao-foto/:id', async (req, res) => {
  const { id } = req.params;
  const { foto_base64 } = req.body;
  try {
    await pool.query('UPDATE refeicoes SET foto_prato_url = $1 WHERE id = $2', [foto_base64, id]);
    res.json({ sucesso: true });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

app.put('/refeicao-item/:id', async (req, res) => {
  const { id } = req.params;
  const { nome_alimento, peso_estimado_gramas, polifenois_consumidos_item } = req.body;
  try {
    const itemRes = await pool.query(
      'UPDATE refeicoes_itens SET nome_alimento = $1, peso_estimado_gramas = $2, polifenois_consumidos_item = $3 WHERE id = $4 RETURNING refeicao_id',
      [nome_alimento, peso_estimado_gramas, polifenois_consumidos_item, id]
    );
    if (itemRes.rows.length > 0) {
      const refeicaoId = itemRes.rows[0].refeicao_id;
      await pool.query(
        `UPDATE refeicoes SET total_polifenois_refeicao = COALESCE((SELECT SUM(polifenois_consumidos_item) FROM refeicoes_itens WHERE refeicao_id = $1), 0) WHERE id = $1`,
        [refeicaoId]
      );
    }
    res.json({ sucesso: true });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

app.get('/refeicoes/:id/itens', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM refeicoes_itens WHERE refeicao_id = $1', [req.params.id]);
    res.json(result.rows);
  } catch (error) { res.status(500).json({ error: error.message }); }
});

// =========================================================================
// LOGIN (com registro de log de acesso: usuário, tipo, IP e hora)
// =========================================================================
app.post('/login', async (req, res) => {
  const { cpf, senha, plataforma } = req.body; 
  const cpfLimpo = cpf ? cpf.replace(/\D/g, '') : '';
  const plataformaFinal = (plataforma === 'app' || plataforma === 'mobile') ? 'APP MOBILE' : 'WEB';
  try {
    const query = "SELECT * FROM users WHERE REPLACE(REPLACE(cpf, '.', ''), '-', '') = $1 AND senha = $2";
    const result = await pool.query(query, [cpfLimpo, senha]);
    if (result.rows.length > 0) {
      const usuario = result.rows[0];
      const ipOrigem = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').toString().split(',')[0].trim();

      await pool.query("UPDATE users SET ultima_atividade = CURRENT_TIMESTAMP WHERE id = $1", [usuario.id]);
      await pool.query(
        "INSERT INTO logs_acesso (usuario_id, acao, ip_origem, plataforma) VALUES ($1, $2, $3, $4)",
        [usuario.id, `LOGIN_${(usuario.tipo_usuario || 'gestante').toUpperCase()}`, ipOrigem, plataformaFinal]
      );

      delete usuario.senha;
      res.status(200).json({ sucesso: true, usuario });
    } else { res.status(401).json({ success: false, erro: 'CPF ou Senha inválidos.' }); }
  } catch (error) { res.status(500).json({ error: error.message }); }
});

// LISTAGEM DE LOGINS (WEB E APP) - PARA O PAINEL MASTER
app.get('/logs-acesso', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT l.id, u.nome as nome_usuario, u.tipo_usuario, l.acao, l.ip_origem, 
             COALESCE(l.plataforma, 'WEB') as plataforma, l.data_hora
      FROM logs_acesso l
      LEFT JOIN users u ON u.id = l.usuario_id
      ORDER BY l.data_hora DESC
      LIMIT 300
    `);
    res.status(200).json({ sucesso: true, logins: result.rows });
  } catch (error) {
    console.error("ERRO GET LOGS ACESSO:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

app.post('/signup', async (req, res) => {
  const { nome, email, senha, rg, cpf, data_nascimento, endereco, semana_gestacao, telefone, cep, logradouro, numero, complemento, cidade, uf, nacionalidade, naturalidade, nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, telefone_fixo, foto_perfil_url } = req.body;
  try {
    const dataCorrigida = formatarDataParaBanco(data_nascimento);
    const idadeCalculada = calcularIdade(dataCorrigida);
    const codigoVerificacao = Math.floor(100000 + Math.random() * 900000).toString();
    const cpfLimpo = cpf ? cpf.replace(/\D/g, '') : '';
    const query = `
      INSERT INTO users (nome, email, senha, rg, cpf, data_nascimento, endereco, idade, semana_gestacao, telefone, cep, logradouro, numero, complemento, cidade, estado, nacionalidade, naturalidade, nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, telefone_fixo, foto_perfil_url, tipo_usuario, email_validado, codigo_verificacao)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, 'gestante', false, $26)
      ON CONFLICT (cpf) DO UPDATE SET codigo_verificacao = EXCLUDED.codigo_verificacao, email_validado = false RETURNING id, nome;`;
    const result = await pool.query(query, [nome, email, senha, rg, cpfLimpo, dataCorrigida, endereco, idadeCalculada, parseInt(semana_gestacao) || 0, telefone, cep, logradouro, numero, complemento, cidade, uf, nacionalidade, naturalidade, nome_mae, nome_medico, crm_medico, nome_nutricionista, crn_nutricionista, telefone_fixo, foto_perfil_url, codigoVerificacao]);
    
    try {
      await resend.emails.send({
        from: 'Polifenóis <onboarding@resend.dev>',
        to: email,
        subject: 'Seu Código de Ativação - Polifenóis',
        html: `<b>Olá ${nome}, seu código de ativação é: ${codigoVerificacao}</b>`
      });
    } catch (mailError) { console.log("❌ Erro Resend:", mailError.message); }
    
    res.status(201).json({ sucesso: true, usuario: result.rows[0] });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

// =========================================================================
// RECUPERAÇÃO DE SENHA (reaproveita a coluna codigo_verificacao)
// =========================================================================
// CONFIRMAÇÃO DO CÓDIGO ENVIADO NO CADASTRO (estava faltando)
app.post('/confirmar-email', async (req, res) => {
  const { usuario_id, codigo } = req.body;
  try {
    const result = await pool.query(
      "SELECT id FROM users WHERE id = $1 AND codigo_verificacao = $2",
      [usuario_id, codigo]
    );
    if (result.rows.length === 0) {
      return res.status(400).json({ sucesso: false, erro: "Código inválido." });
    }
    await pool.query("UPDATE users SET email_validado = true, codigo_verificacao = NULL WHERE id = $1", [usuario_id]);
    res.status(200).json({ sucesso: true, mensagem: "E-mail validado com sucesso." });
  } catch (error) {
    console.error("ERRO CONFIRMAR EMAIL:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

// REENVIO DE CÓDIGO (cadastro pendente)
app.post('/reenviar-codigo', async (req, res) => {
  const { usuario_id } = req.body;
  try {
    const userRes = await pool.query("SELECT nome, email FROM users WHERE id = $1", [usuario_id]);
    if (userRes.rows.length === 0) return res.status(404).json({ sucesso: false, erro: "Usuário não encontrado." });
    const usuario = userRes.rows[0];
    const codigo = Math.floor(100000 + Math.random() * 900000).toString();
    await pool.query("UPDATE users SET codigo_verificacao = $1 WHERE id = $2", [codigo, usuario_id]);
    await resend.emails.send({
      from: 'Polifenóis <onboarding@resend.dev>',
      to: usuario.email,
      subject: 'Novo Código de Ativação - Polifenóis',
      html: `<b>Olá ${usuario.nome}, seu novo código de ativação é: ${codigo}</b>`
    });
    res.json({ sucesso: true, mensagem: "Novo código enviado para o seu e-mail." });
  } catch (error) {
    console.error("ERRO REENVIAR CODIGO:", error.message);
    res.status(500).json({ sucesso: false, erro: error.message });
  }
});

app.post('/esqueci-senha', async (req, res) => {
  const { cpf } = req.body;
  try {
    const cpfLimpo = cpf ? cpf.replace(/\D/g, '') : '';
    const userRes = await pool.query(
      "SELECT id, nome, email FROM users WHERE REPLACE(REPLACE(cpf, '.', ''), '-', '') = $1",
      [cpfLimpo]
    );
    if (userRes.rows.length === 0) {
      return res.status(404).json({ sucesso: false, erro: "CPF não encontrado." });
    }

    const usuario = userRes.rows[0];
    const codigo = Math.floor(100000 + Math.random() * 900000).toString();
    await pool.query("UPDATE users SET codigo_verificacao = $1 WHERE id = $2", [codigo, usuario.id]);

    await resend.emails.send({
      from: 'Polifenóis <onboarding@resend.dev>',
      to: usuario.email,
      subject: 'Recuperação de Senha - Polifenóis',
      html: `<p>Olá, ${usuario.nome}.</p><p>Seu código de recuperação de senha é: <strong>${codigo}</strong></p>`
    });

    res.json({ sucesso: true, mensagem: "Código enviado para o e-mail cadastrado." });
  } catch (error) {
    console.log("Erro em /esqueci-senha:", error.message);
    res.status(500).json({ sucesso: false, erro: "Erro no servidor." });
  }
});

app.post('/redefinir-senha', async (req, res) => {
  const { cpf, codigo, nova_senha } = req.body;
  try {
    const cpfLimpo = cpf ? cpf.replace(/\D/g, '') : '';
    const userRes = await pool.query(
      "SELECT id FROM users WHERE REPLACE(REPLACE(cpf, '.', ''), '-', '') = $1 AND codigo_verificacao = $2",
      [cpfLimpo, codigo]
    );
    if (userRes.rows.length === 0) {
      return res.status(400).json({ sucesso: false, erro: "Código inválido." });
    }

    await pool.query("UPDATE users SET senha = $1, codigo_verificacao = NULL WHERE id = $2", [nova_senha, userRes.rows[0].id]);
    res.json({ sucesso: true, mensagem: "Senha redefinida com sucesso." });
  } catch (error) {
    console.log("Erro em /redefinir-senha:", error.message);
    res.status(500).json({ sucesso: false, erro: "Erro no servidor." });
  }
});

app.post('/analisar-refeicao', async (req, res) => {
  const { usuario_id, foto_base64, peso_total_refeicao, tipo_refeicao, latitude, longitude } = req.body;
  if (!foto_base64) return res.status(400).json({ sucesso: false, erro: 'Foto ausente.' });
  
  try {
    const response = await ai.models.generateContent({
      model: 'gemini-3.5-flash',
      contents: [
        `Analise e retorne JSON estrito: {"total_polifenois_refeicao": X, "itens": [{"alimento": "nome", "peso_estimado_gramas": Y, "polifenois_100g": Z}]}. Assuma prato de 25cm. Peso total informado: ${peso_total_refeicao || 0}g.`, 
        { inlineData: { data: foto_base64, mimeType: "image/jpeg" } }
      ]
    });
    let resultText = response.text;
    let iaData = JSON.parse(extrairJSON(resultText));
    
    const insertRef = `INSERT INTO refeicoes (usuario_id, foto_prato_url, total_polifenois_refeicao, tipo_refeicao, peso_total_refeicao, latitude, longitude) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id;`;
    const refRes = await pool.query(insertRef, [usuario_id, foto_base64, iaData.total_polifenois_refeicao, tipo_refeicao, peso_total_refeicao, latitude, longitude]);
    const refeicaoId = refRes.rows[0].id;

    let itensSalvos = [];
    for (const item of iaData.itens) {
      const consumido = (item.peso_estimado_gramas * item.polifenois_100g) / 100;
      const itemRes = await pool.query(
        `INSERT INTO refeicoes_itens (refeicao_id, nome_alimento, peso_estimado_gramas, fator_polifenol_aplicado, polifenois_consumidos_item) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [refeicaoId, item.alimento, item.peso_estimado_gramas, item.polifenois_100g, consumido]
      );
      itensSalvos.push({
        id: itemRes.rows[0].id,
        alimento: item.alimento,
        peso_estimado_gramas: item.peso_estimado_gramas,
        polifenois_100g: item.polifenois_100g,
        polifenois_consumidos_item: consumido
      });
    }

    res.status(200).json({
      sucesso: true,
      analise: {
        refeicao_id: refeicaoId,
        total_polifenois_refeicao: iaData.total_polifenois_refeicao,
        itens: itensSalvos
      }
    });
  } catch (error) { 
    console.error("ERRO IA:", error.message);
    res.status(500).json({ error: 'Erro ao processar imagem.' }); 
  }
});

app.get('/refeicoes-gestante/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('SELECT * FROM refeicoes WHERE usuario_id = $1 ORDER BY data_hora_registro DESC', [id]);
    res.status(200).json({ sucesso: true, refeicoes: result.rows });
  } catch (error) { res.status(500).json({ error: 'Erro ao buscar histórico.' }); }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => { console.log(`🚀 Servidor Polifenóis rodando na porta ${PORT}`); });