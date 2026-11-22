#!/usr/bin/env node
// Référentiel serveur des informateurs (refonte des informateurs, Fred 19/11/2026, étape K du 22/11/2026).
// GAME-DESIGN-CRIMINALITE.md, « Barème commun des informateurs » : le rôle d'informateur passe aux PNJ présents
// dans les lieux. Ce générateur lit le VRAI data.js et la vraie résolution du casting par ville
// (getBuildingContext + personnesNormalesDeLaPiece, comme generer-pnj-lieux-metiers.cjs) et classe chaque PNJ :
//   - « lieu »        : réceptionnistes, serveuses et hôtesses, personnel de l'Assemblée, de la présidence et des
//                       mairies, chefs de gare, commandants et directeurs de port, agents de sécurité privée ;
//   - « generaliste » : barmans (et patrons de bar) ;
//   - « sujet »       : entraîneurs et dealers (drogue), lobbyistes (politique), dirigeants syndicaux (syndicat).
// Non-informateurs (magistrats, policiers et militaires en service, religieux, soignants, notaires et clercs, guides
// de musée, vendeurs de souvenirs, journalistes) : leurs métiers ne sont jamais retenus.
// Républia et Sovarka seulement : le barème n'existe que pour ces deux empires.
// Usage : node outils/generateurs/generer-informateurs-lieux.cjs          -> VALUES SQL (migration)
//         node outils/generateurs/generer-informateurs-lieux.cjs --json   -> JSON
'use strict';
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..');

const PAYS = ['republic', 'soviet'];
const LIEU = new Set(['hotesse', 'hotesse_accueil', 'receptionniste', 'hotelier', 'chef_gare', 'capitaine_port',
  'agent_securite', 'securite', 'protocole']);

function classer(p, batiment) {
  const job = p.job || '', role = String(p.role || '');
  // Lieux de soins : les soignants ne sont pas informateurs, et l'accueil d'un dispensaire non plus (secret médical).
  if (/dispensaire|clinique|hopital/.test(batiment)) return null;
  if (job === 'barman') return { profil: 'generaliste', sujet: null };
  if (job === 'serveur') return /patron du bar|barman/i.test(role) ? { profil: 'generaliste', sujet: null } : { profil: 'lieu', sujet: null };
  if (LIEU.has(job)) return { profil: 'lieu', sujet: null };
  if (job === 'secretaire' && /^(mairie|assemblee|palais-presidentiel)/.test(batiment)) return { profil: 'lieu', sujet: null };
  if (job === 'entraineur') return { profil: 'sujet', sujet: 'drogue' };
  if (job === 'criminel' && /dealer/i.test(role)) return { profil: 'sujet', sujet: 'drogue' };
  if (job === 'lobbyiste') return { profil: 'sujet', sujet: 'politique' };
  if (job === 'syndicaliste') return { profil: 'sujet', sujet: 'syndicat' };
  return null;
}

function lignes() {
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
  ctx.PAYS_INFORMATEURS = PAYS;
  const brut = vm.runInContext(`(() => { const out = [];
    for (const pays of PAYS_INFORMATEURS) for (const ville of Object.keys(WORLD[pays] || {})) {
      const cite = WORLD[pays][ville]; if (!cite || !Array.isArray(cite.buildings)) continue;
      state.country = pays; state.currentCity = ville;
      for (const id of cite.buildings) {
        const b = BUILDINGS[id]; if (!b) continue;
        const c = getBuildingContext(id);
        const pieces = new Set([...Object.keys(b.rooms || {}), ...Object.keys(c?.roomsExtra || {})]
          .filter(p => !(c?.roomsExclues || []).includes(p)));
        for (const piece of pieces) for (const p of (personnesNormalesDeLaPiece(id, piece) || [])) {
          if (!p || p.isPJ || typeof p.name !== 'string') continue;
          out.push({ pays, ville, batiment: id, piece, nom: p.name.replace(' (PNJ)', '').trim(), job: p.job || '', role: p.role || '' });
        }
      } }
    return JSON.parse(JSON.stringify(out)); })()`, ctx);
  const vus = new Set(), out = [];
  for (const l of brut) {
    const k = classer(l, l.batiment);
    if (!k) continue;
    const id = [l.pays, l.ville, l.batiment, l.piece, l.nom].join(':');
    if (vus.has(id)) continue;
    vus.add(id);
    out.push({ id, pays: l.pays, ville: l.ville, batiment: l.batiment, piece: l.piece, nom: l.nom, role: l.role, profil: k.profil, sujet: k.sujet });
  }
  // L'habitué du Bar Sever de Krasnov (lot de Krasnov, point 8) : généraliste, piste du colonel Voronov au premier choix.
  out.push({ id: 'habitue_krasnov', pays: 'soviet', ville: 'ville_b', batiment: 'cafe-tabac-cheminots-montrouge', piece: null,
    nom: 'L’habitué du Bar Sever', role: 'Habitué du bar', profil: 'generaliste', sujet: null });
  return out.sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

if (require.main === module) {
  const l = lignes();
  if (process.argv.includes('--json')) { process.stdout.write(JSON.stringify(l, null, 1) + '\n'); }
  else {
    const q = (s) => s === null || s === undefined ? 'NULL' : "'" + String(s).replace(/'/g, "''") + "'";
    process.stdout.write('-- ' + l.length + ' informateurs (généré par outils/generateurs/generer-informateurs-lieux.cjs)\n'
      + l.map(x => '(' + [x.id, x.pays, x.ville, x.batiment, x.piece, x.nom, x.role, x.profil, x.sujet].map(q).join(', ') + ')').join(',\n') + '\n');
  }
}
module.exports = { lignes, classer };
