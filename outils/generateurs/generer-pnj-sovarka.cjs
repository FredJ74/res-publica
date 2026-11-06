#!/usr/bin/env node
// Table serveur des PNJ renommes en Sovarka (06/11/2026). Source unique : PNJ_SOVARKA dans data.js.
// Usage : node outils/generateurs/generer-pnj-sovarka.cjs > api/_pnj-sovarka-genere.js
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const ctx = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8')
  + ';this.__T = PNJ_SOVARKA; this.__S = slugPnjSovarka;', ctx);
const VILLES = { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov', caserne: 'Novomirsk', qhs: 'Sovarka' };
const sansPnj = (n) => String(n).replace(' (PNJ)', '').trim();
const lignes = [];
for (const [ville, table] of Object.entries(ctx.__T)) {
  for (const [ancien, v] of Object.entries(table)) {
    if (!v) continue;
    const [nouveau, role, profil] = Array.isArray(v) ? v : [v];
    if (nouveau === ancien && !profil) continue;
    lignes.push({ ville: VILLES[ville] || ville, ancien: sansPnj(ancien), nouveau: sansPnj(nouveau),
      role: role || null, id: profil || ('sovarka_' + ctx.__S(nouveau)), source: ctx.__S(ancien) });
  }
}
process.stdout.write('// Généré par outils/generateurs/generer-pnj-sovarka.cjs depuis PNJ_SOVARKA (data.js) ; ne pas éditer.\n'
  + 'export const PNJ_SOVARKA_RENOMMES = ' + JSON.stringify(lignes, null, 1) + ';\n');
