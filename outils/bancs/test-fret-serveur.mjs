// #433 (04/11/2026) : le fret et le contrôle douanier des caisses passent par le serveur.
// Garde : l'écran n'écrit plus caisses_fret / contenu_caisses_fret, ne tire plus le contrôle
// du Chef des Douanes et le jet de douane mort (doControlDouanes) ne revient pas.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const clients = readdirSync(racine).filter(f => f.endsWith('.js'));

test('aucune écriture directe du fret par l’écran', () => {
  for (const f of clients) {
    const s = readFileSync(new URL(f, racine), 'utf8');
    assert.doesNotMatch(s, /sb(Insert|Update|Upsert|Delete)\(\s*'(caisses_fret|contenu_caisses_fret)'/, f);
  }
});

test('le contrôle du Chef et les commandes de caisse passent par leurs portes serveur', () => {
  const s = readFileSync(new URL('plateau-justice-economie.js', racine), 'utf8');
  const debut = s.indexOf('async function confirmerControleCaisseFret(');
  const corps = s.slice(debut, s.indexOf('\n}\n', debut));
  assert.match(corps, /douane_caisse_controler/);
  assert.doesNotMatch(corps, /Math\.random/);
  assert.match(s, /'fret_caisse_commande'/);
  assert.doesNotMatch(s, /dissimulation-fret/);
});

test('le jet de douane du navigateur ne revient pas', () => {
  for (const f of clients) {
    const s = readFileSync(new URL(f, racine), 'utf8');
    assert.doesNotMatch(s, /function doControlDouanes\s*\(/, f);
    assert.doesNotMatch(s, /fn === 'controle_douanes'/, f);
  }
});
