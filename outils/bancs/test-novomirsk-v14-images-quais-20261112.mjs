// Novomirsk V14 (pharmacie) réutilise les trois décors de l'immeuble des Quais V16.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import vm from 'node:vm';
const source = readFileSync(new URL('../../data.js', import.meta.url), 'utf8');
const ctx = { console: { log() {}, warn() {} } }; ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(source + ';this.B=BUILDINGS;this.W=WORLD;', ctx);
const ref = ctx.B['logements-novomirsk-quais'].rooms;
const base = ctx.B['logements-novomirsk'].rooms;
const ville = ctx.W.soviet.capitale.buildingContext['logements-novomirsk'];
test('V14 : hall et huit appartements affichent exactement les six WebP des Quais', () => {
  assert.ok(ville?.roomOverrides);
  assert.equal(Object.keys(ref).length, 9);
  for (const [pieceId, piece] of Object.entries(ref)) {
    const image = ville.roomOverrides[pieceId]?.imageUrl;
    assert.equal(image, piece.imageUrl, pieceId);
    assert.ok(image?.endsWith('.webp') && existsSync(new URL('../../' + image, import.meta.url)), pieceId);
    assert.ok(!base[pieceId].imageUrl, 'le gabarit partagé ne reçoit pas d’image globale : ' + pieceId);
    assert.equal(Object.keys(ville.roomOverrides[pieceId]).join(','), 'imageUrl', 'surcharge limitée aux images');
  }
});
test('les baux des huit logements V14 ne changent pas', () => {
  for (const [id, piece] of Object.entries(base)) {
    if (id === 'salle') continue;
    assert.equal(piece.locationData?.prix, id.startsWith('petit') ? 10 : 20);
    assert.equal(piece.locationData?.logementSocial, true);
    assert.equal(piece.orders[0]?.fn, 'gerer_logement_social');
  }
});
test('aucune image des quais injectée à Starovka', () => {
  assert.ok(ctx.W.soviet.ville_a.buildings.includes('logements-novomirsk'));
  assert.ok(!ctx.W.soviet.ville_a.buildingContext?.['logements-novomirsk']?.roomOverrides?.salle?.imageUrl?.includes('Novomirsk_logements_quais'));
});
