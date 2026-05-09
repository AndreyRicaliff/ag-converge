#!/usr/bin/env node
/**
 * AG Converge — Extrator de Leads
 * Lê leads.json (exportado pelo admin ou futuro sync Supabase)
 * e gera uma planilha Excel com uma aba por evento.
 *
 * Uso:
 *   node extrair-leads.js                    → processa todos os arquivos leads-*.json
 *   node extrair-leads.js leads-rh.json      → processa arquivo específico
 *   node extrair-leads.js --pasta ./exports  → busca JSONs em outra pasta
 */

const XLSX  = require('xlsx');
const fs    = require('fs');
const path  = require('path');

// ── Config ─────────────────────────────────────────
const EVENTS = {
  'ag_leads_rh-em-xeque': 'RH em Xeque',
  'ag_leads_a-cupula':    'A Cúpula',
};

const COLS = [
  { key: 'nome',              label: 'Nome',              width: 28 },
  { key: 'email',             label: 'E-mail',            width: 32 },
  { key: 'tel',               label: 'WhatsApp',          width: 18 },
  { key: 'empresa',           label: 'Empresa',           width: 26 },
  { key: 'cargo',             label: 'Cargo',             width: 22 },
  { key: 'origem',            label: 'Origem',            width: 16 },
  { key: 'doacao',            label: 'Doação (R$)',       width: 14 },
  { key: 'doacao_confirmada', label: 'Doação confirmada', width: 18 },
  { key: 'inscricao_at',      label: 'Data inscrição',    width: 20 },
];

// ── Args ───────────────────────────────────────────
const args = process.argv.slice(2);
let sourceDir = '.';
let specificFile = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--pasta' && args[i+1]) { sourceDir = args[++i]; }
  else if (args[i].endsWith('.json'))      { specificFile = args[i]; }
}

// ── Lê leads ───────────────────────────────────────
function readLeads(filePath) {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    console.error(`⚠  Erro ao ler ${filePath}:`, e.message);
    return [];
  }
}

function fmtDate(iso) {
  if (!iso) return '';
  try { return new Date(iso).toLocaleString('pt-BR'); }
  catch { return iso; }
}

function fmtBool(v) {
  return v ? 'Sim' : 'Não';
}

// ── Monta workbook ─────────────────────────────────
function buildWorkbook(allLeads) {
  const wb = XLSX.utils.book_new();

  // Uma aba por evento
  for (const [key, label] of Object.entries(EVENTS)) {
    const leads = allLeads.filter(l => l._evento === key || allLeads.length > 0);
    if (!leads.length) continue;
    buildSheet(wb, leads, label);
  }

  // Se não houve match por evento, coloca tudo numa aba "Leads"
  if (wb.SheetNames.length === 0) {
    buildSheet(wb, allLeads, 'Leads');
  }

  return wb;
}

function buildSheet(wb, leads, sheetName) {
  // Cabeçalho
  const header = COLS.map(c => c.label);

  // Linhas
  const rows = leads.map(l => COLS.map(c => {
    const v = l[c.key];
    if (c.key === 'inscricao_at') return fmtDate(v);
    if (c.key === 'doacao_confirmada') return fmtBool(v);
    if (c.key === 'doacao') return Number(v) || 0;
    return v ?? '';
  }));

  // Sheet
  const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);

  // Largura das colunas
  ws['!cols'] = COLS.map(c => ({ wch: c.width }));

  // Estilo do cabeçalho (negrito via cell format — suporte básico xlsx)
  const range = XLSX.utils.decode_range(ws['!ref']);
  for (let C = range.s.c; C <= range.e.c; C++) {
    const addr = XLSX.utils.encode_cell({ r: 0, c: C });
    if (!ws[addr]) continue;
    ws[addr].s = { font: { bold: true }, fill: { fgColor: { rgb: '3B1A7A' } }, font: { color: { rgb: 'FFFFFF' }, bold: true } };
  }

  // Resumo no final
  const totalRow = leads.length + 2;
  const comDoa = leads.filter(l => l.doacao > 0);
  const totalDoa = comDoa.reduce((s, l) => s + (+l.doacao || 0), 0);

  const summary = [
    [], // linha em branco
    ['Total inscritos:', leads.length],
    ['Com doação:', comDoa.length],
    [`Total arrecadado (R$):`, totalDoa.toFixed(2).replace('.', ',')],
    [`Doação média (R$):`, comDoa.length ? (totalDoa / comDoa.length).toFixed(2).replace('.', ',') : '—'],
    ['Gerado em:', new Date().toLocaleString('pt-BR')],
  ];
  XLSX.utils.sheet_add_aoa(ws, summary, { origin: { r: leads.length + 1, c: 0 } });

  XLSX.utils.book_append_sheet(wb, ws, sheetName.substring(0, 31));
}

// ── Main ───────────────────────────────────────────
function main() {
  console.log('\n  🔷 AG Converge — Extrator de Leads\n');

  let allLeads = [];

  if (specificFile) {
    console.log(`  📂 Lendo: ${specificFile}`);
    const leads = readLeads(specificFile);
    allLeads = leads.map(l => ({ ...l, _evento: Object.keys(EVENTS)[0] }));
  } else {
    // Busca todos leads-*.json na pasta
    const files = fs.readdirSync(sourceDir).filter(f => f.match(/leads.*\.json$/i));
    if (!files.length) {
      console.log('  ⚠  Nenhum arquivo leads-*.json encontrado.');
      console.log('     Exporte o JSON pelo painel admin e salve aqui.\n');
      process.exit(0);
    }
    for (const file of files) {
      console.log(`  📂 Lendo: ${file}`);
      const leads = readLeads(path.join(sourceDir, file));
      // Tenta detectar evento pelo nome do arquivo
      const matched = Object.keys(EVENTS).find(k => file.toLowerCase().includes(k.replace('ag_leads_','')));
      allLeads.push(...leads.map(l => ({ ...l, _evento: matched || Object.keys(EVENTS)[0] })));
    }
  }

  if (!allLeads.length) {
    console.log('  ⚠  Nenhum lead encontrado nos arquivos.\n');
    process.exit(0);
  }

  console.log(`  ✓  ${allLeads.length} lead(s) carregado(s)`);

  const wb = buildWorkbook(allLeads);
  const outName = `AG-Leads-${new Date().toISOString().slice(0,10)}.xlsx`;
  const outPath = path.join(sourceDir, outName);

  XLSX.writeFile(wb, outPath);

  console.log(`  ✅ Planilha gerada: ${outPath}`);
  console.log(`\n  Colunas: ${COLS.map(c=>c.label).join(' · ')}`);
  console.log(`  Leads exportados: ${allLeads.length}\n`);
}

main();
