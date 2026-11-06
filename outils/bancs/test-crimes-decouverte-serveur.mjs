// Garde du 03/11/2026 : la découverte différée des crimes et la trace du hooliganisme sont au serveur.
// node outils/bancs/test-crimes-decouverte-serveur.mjs
import { readFileSync } from 'node:fs';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const echecs = [];
const ecran = ['plateau-core.js', 'plateau-personnage.js', 'plateau-justice-economie.js', 'plateau-organisations-quetes.js']
  .map(f => [f, lire(f)]);
for (const [f, s] of ecran) {
  if (/verifierDecouverteCrimesPasses\s*\(/.test(s)) echecs.push(f + ' : découverte des crimes tirée par l\'écran');
  if (/historiqueCrimes\.push\(\s*\{/.test(s)) echecs.push(f + ' : trace de crime posée par l\'écran');
}
const orga = lire('plateau-organisations-quetes.js');
if (!orga.includes("sbRpc('organisation_hooliganisme'")) echecs.push('hooliganisme : la porte serveur n\'est pas appelée');
const mig = lire('migrations/20261103103615_hooliganisme_serveur.sql');
if (!/crime_tracer_interne\(v_moi, 'hooliganisme'/.test(mig)) echecs.push('migration : trace non posée par le serveur');
if (echecs.length) { console.error('ÉCHEC\n' + echecs.join('\n')); process.exit(1); }
console.log('OK : découverte et trace du hooliganisme au serveur (2/2)');
