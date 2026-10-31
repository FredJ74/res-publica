#!/usr/bin/env node
'use strict';
// #295 — inventaire déterministe des écritures client à fermer.
// Lecture du code uniquement, sans réseau ni mutation de données.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const targets = [
  { table: 'organisations', facade: 'sbSaveOrganisation' },
  { table: 'budgets_clubs', facade: 'sbSaveBudgetClub' }
];
const js = fs.readdirSync(root).filter(x => x.endsWith('.js')).sort();
const lines = [];
for (const file of js) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  for (const t of targets) {
    for (const symbol of [t.facade, `sbUpsert('${t.table}'`, `sbPatch('${t.table}'`, `sbPost('${t.table}'`]) {
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
  const direct = lines.filter(x => x.symbol.startsWith('sbUpsert(') || x.symbol.startsWith('sbPatch(') || x.symbol.startsWith('sbPost('));
  if (direct.length) {
    console.error(`#295: ${direct.length} écrivains directs détectés — fermeture non autorisée.`);
    process.exitCode = 1;
  }
}
