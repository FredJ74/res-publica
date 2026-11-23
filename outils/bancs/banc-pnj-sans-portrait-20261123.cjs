// Banc transversal des portraits de PNJ (mission Novomirsk du 23/11/2026, bloc 7, point 40).
//
// 1. Liste TOUS les PNJ du jeu sans portrait, rangés par pays, ville, bâtiment et pièce, dans
//    outils/audits/portraits/pnj-sans-portrait-20261123.json (relevé, jamais une erreur).
// 2. ÉCHOUE si un portrait raccordé (photoUrl d'un PNJ affiché dans une pièce, ou toute chaîne
//    photoUrl:'images/…' de data.js, ou le registre PNJ_PHOTOS de plateau-core.js) pointe vers un
//    fichier absent du dépôt ou mal orthographié (casse comprise : la production tourne sous Linux).
//
// La liste des PNJ d'une pièce suit EXACTEMENT personnesNormalesDeLaPiece (plateau-multijoueur.js) :
// roomOverrides[piece].persons, sinon buildingContext.persons pour la première pièce, sinon le gabarit
// BUILDINGS[bâtiment].rooms[piece].persons ; personsVides:true vide la pièce.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const racine = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const contexte = vm.createContext({});
vm.runInContext(lire('data.js'), contexte, { filename: 'data.js' });
const WORLD = vm.runInContext('WORLD', contexte);
const BUILDINGS = vm.runInContext('BUILDINGS', contexte);

const PAYS = { republic: 'Républia', narco: 'El Estado', soviet: 'Sovarka', khalija: 'Al Khalija' };

// Existence exacte d'un fichier (casse et octets du nom, comme sous Linux). Sous macOS seulement,
// la comparaison tolère la normalisation Unicode (NFC/NFD), que le système de fichiers mélange.
const cacheDossiers = new Map();
function fichierExiste(rel) {
  const propre = decodeURI(String(rel).split(/[?#]/)[0]);
  const dossier = path.join(racine, path.dirname(propre));
  if (!cacheDossiers.has(dossier)) {
    let noms = [];
    try { noms = fs.readdirSync(dossier); } catch { noms = null; }
    cacheDossiers.set(dossier, noms);
  }
  const noms = cacheDossiers.get(dossier);
  if (!noms) return false;
  const base = path.basename(propre);
  if (noms.includes(base)) return true;
  if (process.platform === 'darwin') return noms.some(n => n.normalize('NFC') === base.normalize('NFC'));
  return false;
}
const estLocal = url => typeof url === 'string' && url.startsWith('images/');

function personnesDeLaPiece(b, ctx, roomId) {
  const room = b?.rooms?.[roomId] || ctx?.roomsExtra?.[roomId];
  const premiere = Object.keys(b?.rooms || {})[0] === roomId;
  const sur = ctx?.roomOverrides?.[roomId];
  if (sur?.personsVides === true) return [];
  if (sur?.persons?.length > 0) return sur.persons;
  if (premiere && ctx?.persons?.length > 0) return ctx.persons;
  return room?.persons || [];
}

const sansPortrait = [];
const absents = [];
let pnjVus = 0, avecPortrait = 0;
const parPays = {};
for (const [pays, villes] of Object.entries(WORLD)) {
  for (const [villeId, ville] of Object.entries(villes || {})) {
    if (!ville || typeof ville !== 'object') continue;
    const ctxs = ville.buildingContext || {};
    const ids = [...new Set([...(ville.buildings || []), ...Object.keys(ctxs)])];
    for (const batId of ids) {
      const b = BUILDINGS[batId];
      const ctx = ctxs[batId] || null;
      if (!b && !ctx) continue;
      const pieces = [...new Set([...Object.keys(b?.rooms || {}), ...Object.keys(ctx?.roomsExtra || {})])];
      for (const roomId of pieces) {
        for (const p of personnesDeLaPiece(b, ctx, roomId)) {
          if (!p || p.isPJ || !p.name) continue;
          pnjVus++;
          const lieu = {
            pays, paysNom: PAYS[pays] || pays, ville: villeId, villeNom: ville.name,
            batiment: batId, batimentNom: ctx?.name || b?.name || batId,
            piece: roomId, pieceNom: ctx?.roomOverrides?.[roomId]?.name || b?.rooms?.[roomId]?.name || ctx?.roomsExtra?.[roomId]?.name || roomId,
          };
          if (p.photoUrl) {
            avecPortrait++;
            if (estLocal(p.photoUrl) && !fichierExiste(p.photoUrl)) absents.push({ ...lieu, pnj: p.name, photoUrl: p.photoUrl });
            continue;
          }
          sansPortrait.push({ ...lieu, pnj: p.name, role: p.role || '', job: p.job || '' });
          const k = (PAYS[pays] || pays) + ' / ' + ville.name;
          parPays[k] = (parPays[k] || 0) + 1;
        }
      }
    }
  }
}

// Toute chaîne photoUrl de data.js, même hors d'une pièce (PNJ ajoutés par un module ou un événement).
const litteraux = [...lire('data.js').matchAll(/photoUrl\s*:\s*['"](images\/[^'"]+)['"]/g)].map(m => m[1]);
for (const url of new Set(litteraux)) if (!fichierExiste(url)) absents.push({ source: 'data.js (littéral)', photoUrl: url });
const core = lire('plateau-core.js');
const registre = core.slice(core.indexOf('const PNJ_PHOTOS'), core.indexOf('};', core.indexOf('const PNJ_PHOTOS')));
for (const m of registre.matchAll(/['"](images\/[^'"]+)['"]/g)) if (!fichierExiste(m[1])) absents.push({ source: 'plateau-core.js PNJ_PHOTOS', photoUrl: m[1] });

// Relevé écrit (tri stable pour des diffs lisibles).
const cle = x => [x.paysNom, x.villeNom, x.batimentNom, x.pieceNom, x.pnj].join('\u0000');
sansPortrait.sort((a, b) => cle(a).localeCompare(cle(b), 'fr'));
const arbre = {};
for (const x of sansPortrait) {
  const v = ((arbre[x.paysNom] ||= {})[x.villeNom] ||= {});
  const bat = (v[`${x.batimentNom} [${x.batiment}]`] ||= {});
  (bat[`${x.pieceNom} [${x.piece}]`] ||= []).push(x.role ? `${x.pnj} — ${x.role}` : x.pnj);
}
const sortie = {
  genere_par: 'outils/bancs/banc-pnj-sans-portrait-20261123.cjs',
  note: "Une ligne par apparition dans une pièce (un même PNJ peut figurer dans plusieurs pièces). PNJ du serveur (informateurs, agents, soldats) et PNJ ajoutés dynamiquement par les modules non compris.",
  totaux: {
    apparitions_pnj: pnjVus,
    avec_portrait: avecPortrait,
    sans_portrait: sansPortrait.length,
    pnj_distincts_sans_portrait: new Set(sansPortrait.map(x => x.pays + '|' + x.ville + '|' + x.pnj)).size,
    par_ville: Object.fromEntries(Object.entries(parPays).sort()),
  },
  sans_portrait: arbre,
};
const dossier = path.join(racine, 'outils/audits/portraits');
fs.mkdirSync(dossier, { recursive: true });
fs.writeFileSync(path.join(dossier, 'pnj-sans-portrait-20261123.json'), JSON.stringify(sortie, null, 2) + '\n');

console.log(`PNJ en pièce : ${pnjVus} apparitions, ${avecPortrait} avec portrait, ${sansPortrait.length} sans portrait.`);
for (const [k, n] of Object.entries(sortie.totaux.par_ville)) console.log(`  ${k} : ${n} sans portrait`);
assert.deepEqual(absents, [], 'Portrait raccordé vers un fichier absent ou mal orthographié :\n' + JSON.stringify(absents, null, 2));
console.log('OK : aucun portrait raccordé ne pointe vers un fichier absent.');
