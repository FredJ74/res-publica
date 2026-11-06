// Garde du 03/11/2026 : état d'urgence et registre des ventes d'armes écrits par le serveur seul.
// node outils/bancs/test-urgence-registre-armes.mjs
import { readFileSync, readdirSync } from 'node:fs';
const racine = new URL('../../', import.meta.url);
const echecs = [];
for (const f of readdirSync(racine).filter(f => /^(plateau-.*|supabase)\.js$/.test(f))) {
  const s = readFileSync(new URL(f, racine), 'utf8');
  if (/sb(Insert|Update|Upsert)\(\s*'(etats_urgence|registre_ventes_armes)'/.test(s)) echecs.push(f + ' : écriture directe');
  if (/sbSetEtatUrgence\s*\(|sbEnregistrerVenteArme\s*\(/.test(s)) echecs.push(f + ' : ancien écrivain appelé');
}
if (!readFileSync(new URL('plateau-politique.js', racine), 'utf8').includes("sbRpc('etat_urgence_decider'")) echecs.push('porte etat_urgence_decider non appelée');
if (echecs.length) { console.error('ÉCHEC\n' + echecs.join('\n')); process.exit(1); }
console.log('OK : état d\'urgence et registre des armes au serveur');
