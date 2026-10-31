// node outils/audits/auditer-socle-villes-republia.cjs
// Audit des batiments de Port-Sainte-Marie (ville_a) et Montrouge (ville_b) par rapport au socle de
// Luthecia (capitale), 01/11/2026. Lecture seule : charge le vrai data.js et la vraie fusion des
// ordres (ordresDeclaresDeLaPiece, plateau-navigation.js), puis compare chaque batiment a son
// homologue de Luthecia : ordres absents, ordres en plus, couts differents.
// Declarations uniquement : les ordres dynamiques et les droits serveur ne sont pas deduits ici.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const ctx = vm.createContext({ console, state: { country: 'republic', currentCity: 'capitale' } });
vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
const nav = fs.readFileSync(path.join(root, 'plateau-navigation.js'), 'utf8');
vm.runInContext(nav.slice(nav.indexOf('function getBuildingContext('), nav.indexOf('function joursRestantsPeine(')), ctx);
const villes = vm.runInContext(`(() => { const out = {};
  for (const ville of ['capitale', 'ville_a', 'ville_b']) { state.currentCity = ville; const cite = WORLD.republic[ville]; out[ville] = {};
    for (const id of cite.buildings) { const b = BUILDINGS[id], local = cite.buildingContext?.[id], ordres = [];
      for (const [pid, piece] of Object.entries({ ...b.rooms, ...local?.roomsExtra }))
        for (const o of ordresDeclaresDeLaPiece(piece, local, pid)) ordres.push({ fn: o.fn, pa: o.pa | 0, cost: o.cost | 0 });
      out[ville][id] = { nom: local?.name || b.name, ordres };
    } }
  return JSON.parse(JSON.stringify(out)); })()`, ctx);

// Homologues : meme fonction dans la ville, identifiant different (ou identique quand le gabarit est partage).
const HOMOLOGUES = [
  ['mairie', 'mairie-capitale'], ['banque-locale', 'banque-nationale'], ['dispensaire-public-v', 'dispensaire-public'],
  ['commissariat-local', 'commissariat'], ['tribunal-local', 'tribunal'],
  ['centre-multinodal-port-sainte-marie', 'centre-multinodal-luthecia', 'ville_a'], ['centre-multinodal-montrouge', 'centre-multinodal-luthecia', 'ville_b'],
  ['entrepot-logistique-psm', 'entrepot-logistique-luthecia', 'ville_a'], ['entrepot-logistique-montrouge', 'entrepot-logistique-luthecia', 'ville_b'],
  ['terrain-a-batir-8', 'terrain-a-batir-1', 'ville_a'], ['terrain-a-batir-6', 'terrain-a-batir-1', 'ville_b'], ['terrain-a-batir-montrouge-3', 'terrain-a-batir-1', 'ville_b'],
  ['hotel-port', 'hotel-republica', 'ville_a'], ['hotel-mineur', 'hotel-republica', 'ville_b'],
  ['marche-psm', 'marche', 'ville_a'], ['marche', 'marche', 'ville_b'],
  ['centre-commercial', 'centre-commercial'], ['centre-artisanal', 'centre-artisanal'], ['centre-affaires', 'centre-affaires'], ['stade', 'stade'],
  ['armurerie', 'armurerie', 'ville_b'], ['chasse-peche-psm', 'armurerie', 'ville_a'], ['loge-maconnique', 'loge-maconnique', 'ville_b'], ['la-tribune', 'la-tribune', 'ville_b'],
  ['pole-tabac-alcools-psm', 'usine-pharmaceutique-luthecia', 'ville_a'], ['raffinerie-montrouge', 'usine-pharmaceutique-luthecia', 'ville_b'],
  ['musee-port-sainte-marie', 'musee-national-republia', 'ville_a'], ['musee-histoire-montrouge', 'musee-national-republia', 'ville_b'],
];
const NOM = { ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' };
const fns = (b) => new Set(b.ordres.map(o => o.fn));
const lignes = ['| Ville | Bâtiment | Homologue à Luthécia | Absents par rapport à Luthécia | En plus | Coûts différents |', '|---|---|---|---|---|---|'];
for (const [local, ref, seule] of HOMOLOGUES) for (const ville of seule ? [seule] : ['ville_a', 'ville_b']) {
  const b = villes[ville][local], r = villes.capitale[ref];
  if (!b) continue;
  const fb = fns(b), fr = fns(r);
  const absents = [...fr].filter(f => !fb.has(f)), plus = [...fb].filter(f => !fr.has(f));
  const couts = new Set();
  for (const o of r.ordres) for (const p of b.ordres) if (p.fn === o.fn && (p.pa !== o.pa || p.cost !== o.cost)) couts.add(`${o.fn} ${o.pa} PA/${o.cost} → ${p.pa} PA/${p.cost}`);
  lignes.push(`| ${NOM[ville]} | ${b.nom} | ${r.nom} | ${absents.join(', ') || '—'} | ${plus.join(', ') || '—'} | ${[...couts].join(' ; ') || '—'} |`);
}
console.log(lignes.join('\n'));
