// Serrures (issue #434, 04/11/2026) : gardes du navigateur.
//   node outils/bancs/test-serrures-client.mjs
// 1. La quincaillerie n'entre jamais dans le circuit des armes (ni ARMES_CATALOGUE, ni
//    RECETTES_PRODUCTION) ; le miroir serveur la porte en source 'quincaillerie'.
// 2. Les ecrans des serrures n'ecrivent rien eux-memes : uniquement les portes serveur.
// 3. L'ordre « Equipements et serrure » apparait dans un local a louer, jamais a l'hotel.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const RACINE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (f) => fs.readFileSync(path.join(RACINE, f), 'utf8');

test('la quincaillerie reste hors du circuit des armes, et le miroir la porte', () => {
  const src = lire('plateau-actions-illegales-rumeurs.js');
  const rp = src.slice(src.indexOf('const RECETTES_PRODUCTION = {'), src.indexOf('function getRecettesPays('));
  assert.ok(!/serrure_cle|cle_vierge/.test(rp), 'RECETTES_PRODUCTION ne doit pas contenir la quincaillerie');
  const armes = src.slice(src.indexOf('const ARMES_CATALOGUE'), src.indexOf('};', src.indexOf('const ARMES_CATALOGUE')));
  assert.ok(!/serrure|cle_vierge/.test(armes), 'ARMES_CATALOGUE ne doit pas contenir la quincaillerie');
  const sortie = execFileSync('python3', [path.join(RACINE, 'outils/generateurs/generer_miroirs_entreprises.py'), '--json'],
    { cwd: RACINE, encoding: 'utf8' });
  const d = JSON.parse(sortie);
  const q = d.recettes_commerce.filter((r) => r.source === 'quincaillerie');
  assert.deepEqual(q.map((r) => [r.id, r.pa, r.portions, r.materiaux.metal]).sort(),
    [['cle_vierge', 1, 10, 1], ['serrure_cle', 1, 2, 2]]);
  assert.ok(!d.recettes_production.some((r) => /serrure|cle_vierge/.test(r.id)));
  const rep = d.armureries.find((a) => a.pays === 'republic');
  assert.equal(rep.parametres.prixVente.serrure_cle, 60);
  assert.equal(rep.parametres.prixVente.cle_vierge, 14);
  for (const pays of ['narco', 'soviet']) {
    const a = d.armureries.find((x) => x.pays === pays);
    assert.ok(!('serrure_cle' in a.parametres.prixVente), pays + ' : pas de quincaillerie hors Republia');
  }
});

test('les ecrans des serrures ne passent que par les portes serveur', () => {
  const src = lire('plateau-equipements.js');
  const bloc = src.slice(src.indexOf('// SERRURES (4 novembre 2026'));
  assert.ok(bloc.length > 1000);
  assert.ok(!/sbInsert|sbUpdate|sbDelete|fetch\(|Math\.random|inventory\.push|state\.inventory\s*=/.test(bloc),
    'aucune ecriture ni tirage dans le navigateur');
  const appels = new Set([...bloc.matchAll(/(?:sbRpc|executerReceptionInventaire)\('([a-z_]+)'/g)].map((m) => m[1]));
  assert.deepEqual([...appels].sort(), ['cle_dupliquer', 'equipements_local_lire', 'serrure_basculer', 'serrure_etat', 'serrure_poser', 'serrures_batiments_lire', 'serrures_portes_lire']);
  const migrations = fs.readdirSync(path.join(RACINE, 'migrations')).filter((f) => /serrures/.test(f))
    .map((f) => lire(path.join('migrations', f))).join('\n')
    + (fs.existsSync(path.join(RACINE, 'historique/migrations-appliquees')) ? fs.readdirSync(path.join(RACINE, 'historique/migrations-appliquees'))
      .filter((f) => /serrures/.test(f)).map((f) => lire(path.join('historique/migrations-appliquees', f))).join('\n') : '');
  for (const fn of ['cle_dupliquer', 'serrure_basculer', 'serrure_etat', 'serrure_poser', 'quincaillerie_acheter', 'serrures_portes_lire', 'serrures_batiments_lire']) {
    assert.match(migrations, new RegExp('GRANT EXECUTE ON FUNCTION public\\.' + fn + '\\('), fn + ' ouverte aux joueurs');
  }
  const vitrine = lire('plateau-actions-illegales-rumeurs.js');
  assert.match(vitrine, /executerReceptionInventaire\('quincaillerie_acheter'/);
});

test("l'ordre « Equipements et serrure » : local a louer oui, hotel non", () => {
  const src = lire('plateau-equipements.js');
  const debut = src.indexOf('function ordresSerrureDuLocal(');
  const fin = src.indexOf('if (typeof window', debut);
  const ctx = {
    BUILDINGS: {
      'centre-commercial': { rooms: { vitrine_principale: { isLocationRoom: true }, hall: {} } },
      'hotel-du-port': { rooms: { suite: { isLocationRoom: true } } }
    },
    getBuildingContext: () => null
  };
  vm.createContext(ctx);
  vm.runInContext(src.slice(debut, fin) + '; this.f = ordresSerrureDuLocal;', ctx);
  assert.equal(ctx.f('centre-commercial', 'vitrine_principale')[0].fn, 'installer_equipements');
  assert.equal(ctx.f('centre-commercial', 'vitrine_principale')[0].pa, 0);
  assert.equal(ctx.f('centre-commercial', 'hall').length, 0);
  assert.equal(ctx.f('hotel-du-port', 'suite').length, 0);
});
