// Garde du 03/11/2026 : l'écran n'écrit plus indices_villes ; les actes passent par leurs portes serveur.
// node outils/bancs/test-indices-villes-serveur.mjs
import { readFileSync, readdirSync } from 'node:fs';
const racine = new URL('../../', import.meta.url);
const lire = f => readFileSync(new URL(f, racine), 'utf8');
const echecs = [];
const ecran = readdirSync(racine).filter(f => /^(plateau-.*|supabase|data)\.js$/.test(f));
for (const f of ecran) {
  const s = lire(f);
  if (/sb(Upsert|Insert|Update)\(\s*'indices_villes'/.test(s)) echecs.push(f + ' : écriture directe de indices_villes');
  if (/sbSaveIndicesVille\s*\(/.test(s)) echecs.push(f + ' : sbSaveIndicesVille appelée');
}
const pol = lire('plateau-politique.js');
for (const rpc of ['manifestation_interdire', 'manifestation_reprimer']) {
  if (!pol.includes("sbRpc('" + rpc + "'")) echecs.push('porte ' + rpc + ' non appelée');
}
if (/sbUpdate\('personnages', `name=eq\.\$\{encodeURIComponent\(r\.name\)\}`, \{ hp: nouveauHp/.test(pol)) echecs.push('répression : fiche d\'autrui écrite par l\'écran');
if (!lire('plateau-effort-guerre.js').includes("sbRpc('effort_guerre_renouveler'")) echecs.push('renouvellement de l\'Effort non porté');
if (echecs.length) { console.error('ÉCHEC\n' + echecs.join('\n')); process.exit(1); }
console.log('OK : indices de ville écrits par le serveur seul');
