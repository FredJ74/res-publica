import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

test('Starovka : gare en entrée, port terminus et flèche basse en attente', () => {
  const ctx = vm.createContext({console, state:{country:'soviet',currentCity:'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
  vm.runInContext(fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8'), ctx);
  const result = vm.runInContext(`({
    depart:RUE_CENTRALE_DEPART.soviet.ville_a,
    serveur:rueCentraleServeur('soviet','ville_a'),
    gare:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-gare'],
    port:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-port-industriel'],
    nodes:RUE_CENTRALE_NOEUDS.soviet,
    haut:RC_FLECHE_HAUT,
    bas:RC_FLECHE_BAS
  })`,ctx);
  assert.equal(result.depart, 'starovka-rue-gare');
  assert.equal(result.serveur, true);
  assert.equal(result.gare.image, 'images/Sovarka/Starovka/Starovka_rue_gare.webp');
  assert.equal(result.port.image, 'images/Sovarka/Starovka/Starovka_rue_port industriel.webp');
  assert.deepEqual(Object.keys(result.gare.liens), ['toutDroit']);
  assert.equal(result.gare.liens.toutDroit, 'starovka-rue-port-industriel');
  assert.equal(result.gare.liensEnAttente.arriere, true);
  assert.equal(result.gare.flechesStyle.toutDroit, result.haut);
  assert.equal(result.gare.flechesStyle.arriere, result.bas);
  assert.deepEqual(Object.keys(result.port.liens), ['arriere']);
  assert.equal(result.port.liens.arriere, 'starovka-rue-gare');
  assert.equal(result.port.flechesStyle.arriere, result.bas);
  assert.equal(result.port.liensEnAttente, undefined);
  assert.deepEqual(Object.keys(result.port.zones), []);
  for (const image of [result.gare.image, result.port.image]) {
    const filename=path.join(root,image);
    assert.ok(fs.statSync(filename).size>100, image);
    assert.ok(image.endsWith('.webp'), image);
  }
  assert.deepEqual(fs.readdirSync(path.join(root,'images/Sovarka/Starovka')).filter(s=>s.endsWith('.png')),[]);
  assert.equal(result.nodes['krasnov-rue-gare'].liens.arriere,'krasnov-rue-entrepot');
});

test('Starovka : SQL serveur interdit une destination non définie depuis la gare', () => {
  const sql=fs.readFileSync(path.join(root, 'migrations/20261105220000_starovka_gare_port_industriel.sql'),'utf8');
  assert.match(sql,/starovka-rue-port-industriel/);
  assert.match(sql,/"toutDroit":"starovka-rue-port-industriel"/);
  assert.match(sql,/"arriere":"starovka-rue-gare"/);
  assert.match(sql,/\'{"liens":{"toutDroit":"starovka-rue-port-industriel"},"parArrivee":{}}\'::jsonb/);
});
