#!/usr/bin/env node
// Miroir serveur des PNJ présents dans chaque pièce, avec leur métier (#379, 03/11/2026).
// Lit le VRAI data.js et la vraie résolution du casting par ville (personnesNormalesDeLaPiece,
// plateau-multijoueur.js) : surcharges de ville, première pièce, pièces volontairement vides.
// Sortie : instructions INSERT pour public.pnj_lieux_metiers, sur la sortie standard.
// Usage : node outils/generateurs/generer-pnj-lieux-metiers.cjs > /tmp/pnj.sql
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const ctx = vm.createContext({ console, state: { country: 'republic', currentCity: 'capitale' } });
vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
const extraire = (fichier, debut) => {
  const s = fs.readFileSync(path.join(root, fichier), 'utf8');
  const i = s.indexOf('function ' + debut + '(');
  if (i < 0) throw new Error(debut + ' introuvable dans ' + fichier);
  let j = s.indexOf('{', i), prof = 0;
  for (; j < s.length; j++) { if (s[j] === '{') prof++; else if (s[j] === '}' && --prof === 0) break; }
  return s.slice(i, j + 1);
};
vm.runInContext(extraire('plateau-navigation.js', 'getBuildingContext'), ctx);
vm.runInContext(extraire('plateau-multijoueur.js', 'personnesNormalesDeLaPiece'), ctx);
const lignes = vm.runInContext(`(() => { const out = [];
  // Républia seulement : les autres empires ne sont pas ouverts, leur casting n'est pas arrêté.
  for (const pays of ['republic']) for (const ville of Object.keys(WORLD[pays] || {})) {
    const cite = WORLD[pays][ville]; if (!cite || !Array.isArray(cite.buildings)) continue;
    state.country = pays; state.currentCity = ville;
    for (const id of cite.buildings) {
      const b = BUILDINGS[id]; if (!b) continue;
      const pieces = new Set([...Object.keys(b.rooms || {}), ...Object.keys(getBuildingContext(id)?.roomsExtra || {})]);
      for (const piece of pieces) for (const p of (personnesNormalesDeLaPiece(id, piece) || [])) {
        if (!p || p.isPJ || typeof p.name !== 'string') continue;
        out.push([pays, ville, id, piece, p.name.replace(' (PNJ)', '').trim(), (p.job || 'default'), (p.rel || 'neutral')]);
      }
    } }
  return JSON.parse(JSON.stringify(out)); })()`, ctx);
const q = (s) => "'" + String(s).replace(/'/g, "''") + "'";
const vus = new Set(), valeurs = [];
for (const l of lignes) {
  const cle = l.slice(0, 5).join('|');
  if (vus.has(cle)) continue;
  vus.add(cle);
  valeurs.push('(' + l.map(q).join(',') + ')');
}
process.stdout.write('-- ' + valeurs.length + ' PNJ (généré par outils/generateurs/generer-pnj-lieux-metiers.cjs)\n'
  + 'INSERT INTO public.pnj_lieux_metiers(pays,ville,building_id,room_id,nom,job,rel) VALUES\n'
  + valeurs.join(',\n') + '\nON CONFLICT (pays,ville,building_id,room_id,nom) DO UPDATE SET job=EXCLUDED.job,rel=EXCLUDED.rel;\n');
