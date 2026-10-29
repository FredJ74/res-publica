// Banc des locaux a loyer fixe (29/10/2026). Usage : node outils/bancs/banc-locaux-loyers.cjs
// 1. Le referentiel serveur `locaux_loyers_referentiel` (migration 20261029190000) est EQUIVALENT
//    aux locationData de data.js : meme liste de locaux louables, memes prix et bonus. Un loyer
//    change dans data.js sans la migration (ou l'inverse) fait rougir ce banc.
// 2. Les centres des trois villes de Republia emploient le gabarit commun : aucune ville ne
//    redefinit un loyer (seuls nom et images different).
// 3. L'ecran signe le bail par `local_louer` et n'ecrit plus le bail lui-meme ; le
//    rafraichissement des ordres apres chargement des baux n'est plus reserve a une ville.
'use strict';
const fs = require('fs'), path = require('path');
const racine = path.resolve(__dirname, '..', '..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
let echecs = 0, total = 0;
function att(nom, ok, detail) { total++; if (ok) console.log('  ok  ' + nom); else { echecs++; console.log('  *** ' + nom + (detail ? '\n        ' + detail : '')); } }

global.window = {}; global.document = { addEventListener() {}, getElementById() { return null; } };
const vm = require('vm'); const ctx = vm.createContext({ window: {}, document: global.document, console });
vm.runInContext(lire('data.js').replace(/^const (\w+)\s*=/gm, 'globalThis.$1 ='), ctx);
const B = ctx.BUILDINGS, W = ctx.WORLD;

const attendus = {};
for (const [b, def] of Object.entries(B)) for (const [r, R] of Object.entries(def.rooms || {})) {
  const l = R.locationData;
  if (l && (R.orders || []).some(o => o.fn === 'louer_local'))
    attendus[b + '|' + r + '|*'] = [l.prix, l.bonusPOP || 0, l.bonusINF || 0, l.bonusDIS || 0].join(',');
}
const postes = typeof ctx.bureauxOpenSpaceCentreAffaires === 'function' ? ctx.bureauxOpenSpaceCentreAffaires() : {};
for (const [r, R] of Object.entries(postes)) {
  const l = R.locationData; attendus['centre-affaires|' + r + '|capitale'] = [l.prix, l.bonusPOP, l.bonusINF, l.bonusDIS].join(',');
}

const sql = lire('migrations/20261029184321_location_locaux_par_serveur.sql');
const serveur = {}; const nonLouables = [];
for (const m of sql.matchAll(/\('([a-z-]+)','([a-z_-]+)','([*a-z_]+)',(\d+),(\d+),(\d+),(\d+),'[^']*',(true|false)\)/g)) {
  if (m[8] === 'false') { nonLouables.push(m[1] + '|' + m[2] + '|' + m[3]); continue; }
  if (m[2] === 'box-portuaire') continue;
  serveur[m[1] + '|' + m[2] + '|' + m[3]] = [m[4], m[5], m[6], m[7]].join(',');
}

console.log('1. EQUIVALENCE DU REFERENTIEL SERVEUR');
const manquants = Object.keys(attendus).filter(k => serveur[k] === undefined);
const enTrop = Object.keys(serveur).filter(k => attendus[k] === undefined);
const differents = Object.keys(attendus).filter(k => serveur[k] !== undefined && serveur[k] !== attendus[k]);
att(Object.keys(attendus).length + ' locaux louables de data.js, tous au referentiel', manquants.length === 0, manquants.join(', '));
att('aucun local au referentiel absent de data.js', enTrop.length === 0, enTrop.join(', '));
att('memes prix et bonus', differents.length === 0, differents.map(k => k + ' data=' + attendus[k] + ' serveur=' + serveur[k]).join(' ; '));
att("l'open space unique de Luthecia n'est pas louable (remplace par ses postes)", nonLouables.includes('centre-affaires|open_space|capitale'));

console.log('2. UN SEUL GABARIT POUR LES CENTRES DES TROIS VILLES');
const villes = W.republic || {};
for (const v of ['capitale', 'ville_a', 'ville_b']) {
  const ctxV = (villes[v] && villes[v].buildingContext) || {};
  for (const c of ['centre-commercial', 'centre-artisanal', 'centre-affaires']) {
    const o = ctxV[c] || {};
    if (c === 'centre-commercial') att(v + ' : surcharge de ville du centre commercial lue', !!ctxV[c]);
    const surch = Object.values(o.roomOverrides || {}).concat(Object.values(o.roomsExtra || {}));
    const loyers = surch.filter(x => x && x.locationData && x.locationData.prix !== undefined && !(v === 'capitale' && c === 'centre-affaires'));
    att(v + ' / ' + c + ' : aucun loyer redefini par la ville', loyers.length === 0);
  }
}

console.log("3. L'ECRAN SIGNE PAR LE SERVEUR");
const je = lire('plateau-justice-economie.js');
const i = je.indexOf('async function confirmerLocation('), corps = je.slice(i, je.indexOf('\nfunction ', i));
att('confirmerLocation appelle local_louer', corps.includes("sbRpcVerdict('local_louer'"));
att("et n'ecrit plus le bail ni ne debite le loyer elle-meme", !corps.includes('sbSaveLocation(') && !corps.includes('debiterFondsOrdinaires('));
att("le rafraichissement apres chargement des baux n'est plus reserve a Port-Sainte-Marie",
  !/state\.currentCity === 'ville_a' &&\s*\n\s*batiment === 'centre-commercial'/.test(je));

console.log(echecs ? 'ECHEC : ' + echecs + ' epreuve(s) sur ' + total + ' en defaut.' : 'LES ' + total + ' EPREUVES SONT VERTES.');
process.exit(echecs ? 1 : 0);
