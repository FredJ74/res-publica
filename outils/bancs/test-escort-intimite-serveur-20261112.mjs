// Garde-fou : « Faire l'amour » ne calcule plus aucun effet à l'écran (une seule vérité, Fred 12/11/2026).
import { readFileSync } from 'node:fs';
const src = readFileSync(new URL('../../plateau-pnj.js', import.meta.url), 'utf8');
const mig = readFileSync(new URL('../../migrations/20261112014500_escort_intimite_serveur.sql', import.meta.url), 'utf8');
const corps = (nom) => { const a = src.indexOf(nom); if (a < 0) throw new Error('absent : ' + nom); const b = src.indexOf('\n}\n', a); return src.slice(a, b); };
const echecs = [];
const acte = corps('async function escortIntimiteServeur(');
if (!acte.includes("'escort_intimite'")) echecs.push('escortIntimiteServeur n’appelle pas escort_intimite');
for (const interdit of ['Math.min(100', 'appliquerGainENT', 'debiterFondsOrdinaires', 'bonusParPalier', 'escortInfo.palier = palierVise'])
  if (acte.includes(interdit)) echecs.push('calcul écran resté dans l’acte : ' + interdit);
for (const f of ['async function confirmerFaireLAmour(', 'async function confirmerEtapeEscort(']) {
  const c = corps(f);
  if (!c.includes('escortIntimiteServeur(') || c.includes('debiterFondsOrdinaires') || c.includes('state.moral')) echecs.push(f + ' ne passe pas par le serveur');
}
if (!corps('async function ouvrirModalFaireLAmour(').includes("'escort_complicite'")) echecs.push('le palier n’est pas lu au serveur');
for (const v of ['ARRAY[15, 18, 22, 28]', 'ARRAY[5, 6, 7, 10]', 'ARRAY[2, 2, 3, 4]', 'WHEN 1 THEN 100 WHEN 2 THEN 300 WHEN 3 THEN 600', 'c_prestation constant integer := 300', 'ent_gain_quotidien_interne'])
  if (!mig.includes(v)) echecs.push('barème serveur manquant : ' + v);
// Tournées (12/11/2026) : plus aucun gain écran, plus d'écriture directe.
const rum = readFileSync(new URL('../../plateau-actions-illegales-rumeurs.js', import.meta.url), 'utf8');
const sb = readFileSync(new URL('../../supabase.js', import.meta.url), 'utf8');
for (const [txt, ou, nom] of [[rum, 'appliquerGainENT(', 'rumeurs'], [src, 'function appliquerGainENT', 'pnj'], [rum, 'sbClaimResolutionTournee', 'rumeurs'], [sb, "sbInsert('tournees'", 'supabase'], [sb, "sbUpdate('tournees'", 'supabase']])
  if (txt.includes(ou)) echecs.push('ancien chemin de tournée resté (' + nom + ') : ' + ou);
if (/state\.moral\s*=\s*Math\.min\(100,\s*\(state\.moral \|\| 0\) \+ 2\)/.test(rum)) echecs.push('bonus de Moral de tournée calculé à l’écran');
if (echecs.length) { console.error(echecs.join('\n')); process.exit(1); }
console.log('Faire l’amour : effets, palier et paiement décidés par le serveur.');
