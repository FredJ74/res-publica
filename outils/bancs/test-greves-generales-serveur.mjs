// Garde du 03/11/2026 : la grève générale est écrite par le serveur seul.
// node outils/bancs/test-greves-generales-serveur.mjs
import { readFileSync, readdirSync } from 'node:fs';
const racine = new URL('../../', import.meta.url);
const echecs = [];
for (const f of readdirSync(racine).filter(f => /^(plateau-.*|supabase|forum)\.js$/.test(f))) {
  const s = readFileSync(new URL(f, racine), 'utf8');
  if (/sb(Insert|Update|Upsert)\(\s*'greves_generales'/.test(s)) echecs.push(f + ' : écriture directe de greves_generales');
}
const o = readFileSync(new URL('plateau-organisations-quetes.js', racine), 'utf8');
for (const rpc of ['greve_generale_lancer', 'greve_generale_repondre', 'greve_generale_retirer', 'greve_generale_lier_sujet']) {
  if (!o.includes("sbRpc('" + rpc + "'")) echecs.push('porte ' + rpc + ' non appelée');
}
if (echecs.length) { console.error('ÉCHEC\n' + echecs.join('\n')); process.exit(1); }
console.log('OK : grève générale au serveur');
