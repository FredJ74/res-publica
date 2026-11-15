// Commerce Premium gratuit pendant la beta (decision de Fred, 06/11/2026) : ecran.
// Le serveur est eprouve par le banc annule joue avant la migration 20261106234500.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const ecran=fs.readFileSync(path.join(root,'plateau-commerce-pj.js'),'utf8');
const migration=fs.readFileSync(path.join(root,'migrations/20261106234500_commerce_premium_beta.sql'),'utf8');

// Activation gratuite annulée le 06/11 (Fred : « malentendu », le freemium/premium de Luthécia est le bon ;
// PR #562, migration 20261106235500) : la vitrine payante reste grisée, aucun achat gratuit pendant la bêta.
test('La vitrine Commerce Premium reste payante et désactivée, sans activation gratuite', ()=>{
  assert.ok(!ecran.includes("sbRpcVerdict('fonds_premium_activer'"), 'pas d’activation gratuite depuis l’écran');
  assert.ok(!ecran.includes('onclick="commercePjActiverPremium()"'));
  assert.ok(ecran.includes('Activer Commerce Premium — 4,99 € (bientôt)'), 'vitrine payante grisée');
});

test('Plafonds gratuit 2/4 et premium 3/10 lus sur le fonds', ()=>{
  for (const x of ["('types_commerce_max_base','2')","('references_max_base','4')","('types_commerce_max_premium','3')","('references_max_premium','10')"])
    assert.ok(migration.includes(x), x);
  assert.ok(migration.includes('fonds_types_max_fonds(v_data)') && migration.includes('fonds_references_max_fonds(v_data)'));
});
