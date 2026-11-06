// Garde des PNJ de Sovarka (06/11/2026) : noms propres, pas de portrait de Republia, une fiche de
// dialogue par PNJ renomme, table serveur synchronisee avec data.js. node outils/bancs/test-pnj-sovarka-20261106.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';
import { profilExiste } from '../../api/_pnj-profils.js';
import { PNJ_SOVARKA_RENOMMES } from '../../api/_pnj-sovarka-genere.js';

const ctx = vm.createContext({ console });
vm.runInContext(fs.readFileSync(new URL('../../data.js', import.meta.url), 'utf8')
  + ';this.W = WORLD; this.B = BUILDINGS; this.G = PNJ_SOVARKA_GENERIQUES;', ctx);
const { W, B, G } = ctx;

function personnes(pays, ville) {
  const cite = W[pays][ville], out = [];
  for (const id of cite.buildings || []) {
    const b = B[id]; if (!b) continue;
    const c = (cite.buildingContext || {})[id] || {};
    const pieces = Object.assign({}, b.rooms || {}, c.roomsExtra || {});
    const premiere = Object.keys(b.rooms || {})[0];
    for (const r of Object.keys(pieces)) {
      const ro = (c.roomOverrides || {})[r];
      const ps = ro?.personsVides ? [] : ro?.persons?.length ? ro.persons
        : (r === premiere && c.persons?.length) ? c.persons : (pieces[r].persons || []);
      for (const p of ps) out.push({ ville, id, r, ...p });
    }
  }
  return out;
}

const republia = new Set(Object.keys(W.republic).flatMap(v => personnes('republic', v)).map(p => p.name));
const sovarka = Object.keys(W.soviet).flatMap(v => personnes('soviet', v));

test('aucun PNJ nomme de Republia en Sovarka (seuls les intitulés génériques sont partagés)', () => {
  const communs = sovarka.filter(p => republia.has(p.name) && !Object.prototype.hasOwnProperty.call(G, p.name));
  assert.deepEqual(communs.map(p => `${p.ville}/${p.id}/${p.r}: ${p.name}`), []);
});

test('aucun portrait de Republia sur un PNJ de Sovarka issu du gabarit', () => {
  const avecPhoto = sovarka.filter(p => republia.has(p.name) && (p.photoUrl || p.photo));
  assert.deepEqual(avecPhoto.map(p => p.name), []);
});

test('chaque PNJ renommé a une fiche de dialogue', () => {
  const sansFiche = sovarka.filter(p => p.profilId && !profilExiste(p.profilId)).map(p => p.profilId);
  assert.deepEqual([...new Set(sansFiche)], []);
});

test('pas de doublon de nom entre villes de Sovarka', () => {
  const villesParNom = new Map();
  for (const p of sovarka) {
    if (!p.profilId || ['caserne', 'qhs'].includes(p.ville)) continue;
    (villesParNom.get(p.name) || villesParNom.set(p.name, new Set()).get(p.name)).add(p.ville);
  }
  assert.deepEqual([...villesParNom].filter(([, v]) => v.size > 1).map(([n]) => n), []);
});

test('table serveur à jour avec data.js', () => {
  const sortie = execFileSync('node', [new URL('../generateurs/generer-pnj-sovarka.cjs', import.meta.url).pathname]).toString();
  assert.equal(sortie, fs.readFileSync(new URL('../../api/_pnj-sovarka-genere.js', import.meta.url), 'utf8'));
  assert.ok(PNJ_SOVARKA_RENOMMES.length > 50);
});
