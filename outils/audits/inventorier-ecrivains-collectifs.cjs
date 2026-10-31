#!/usr/bin/env node
'use strict';
// #295 — inventaire déterministe des écritures client à fermer.
// Lecture du code uniquement, sans réseau ni mutation de données.
const fs = require('node:fs');
const path = require('node:path');
const rootArg = process.argv.indexOf('--root');
const root = rootArg >= 0 ? path.resolve(process.argv[rootArg + 1] || '') : path.resolve(__dirname, '../..');
if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) throw new Error('Répertoire source invalide');
const targets = [
  { table: 'organisations', facade: 'sbSaveOrganisation' },
  { table: 'budgets_clubs', facade: 'sbSaveBudgetClub' }
];
const js = fs.readdirSync(root).filter(x => x.endsWith('.js')).sort();
const extraPatterns = [
  {table:'organisations', symbol:'rest/v1/organisations'},
  {table:'budgets_clubs', symbol:'rest/v1/budgets_clubs'},
  {table:'organisations', symbol:"from('organisations')"},
  {table:'organisations', symbol:'from("organisations")'},
  {table:'budgets_clubs', symbol:"from('budgets_clubs')"},
  {table:'budgets_clubs', symbol:'from("budgets_clubs")'}
];
const lines = [];
for (const file of js) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  for (const t of targets) {
    const patterns = [
      t.facade,
      ...extraPatterns.filter(p => p.table === t.table).map(p => p.symbol),
      ...['sbUpsert', 'sbPatch', 'sbPost', 'sbDelete'].flatMap(fn => [
        fn + "('" + t.table + "'",
        fn + '("' + t.table + '"',
        fn + '(' + String.fromCharCode(96) + t.table + String.fromCharCode(96)
      ])
    ];
    for (const symbol of new Set(patterns)) {
      let offset = 0;
      while ((offset = text.indexOf(symbol, offset)) !== -1) {
        const line = text.slice(0, offset).split('\n').length;
        const excerpt = text.slice(offset, offset + 130).split('\n')[0];
        lines.push({table:t.table, file, line, symbol, excerpt});
        offset += symbol.length;
      }
    }
  }
}
const result = {chantier:295,lecture_seule:true,source:root,occurrences:lines,
  limitation:'Repérage lexical des chemins connus ; compléter par analyse des appels indirects et des RPC.'};
console.log(JSON.stringify(result, null, 2));
if (process.argv.includes('--enforce')) {
  const direct = lines.filter(x => x.symbol.startsWith('sbUpsert(') || x.symbol.startsWith('sbPatch(') || x.symbol.startsWith('sbPost(') || x.symbol.startsWith('sbDelete('));
  if (direct.length) {
    console.error(`#295: ${direct.length} écrivains directs détectés — fermeture non autorisée.`);
    process.exitCode = 1;
  }
}
