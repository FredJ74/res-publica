// Appartements populaires (GAME-DESIGN-APPARTEMENTS.md, 12/11/2026) : chambres premium dans data.js,
// onglets des chambres, fenêtre « Mon logement » et catalogue des huit langues.
// Le serveur est éprouvé à part : outils/bancs/banc-appartements-populaires-20261112.sql.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import vm from 'node:vm';
const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

const ctx = { console: { log() {}, warn() {} } }; ctx.window = ctx; ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(lire('data.js') + ';this.B=BUILDINGS;this.W=WORLD;', ctx);

test('chambres : 1 par petit appartement, 2 par grand, dans les quatre immeubles dessinés', () => {
  const attendu = { 'logements-montrouge': 6, 'logements-novomirsk': 12, 'logements-novomirsk-marche': 12, 'logements-novomirsk-quais': 12 };
  for (const [id, n] of Object.entries(attendu)) {
    const rooms = ctx.B[id].rooms;
    const ch = Object.entries(rooms).filter(([, r]) => r.chambreLogement);
    assert.equal(ch.length, n, id);
    for (const [pid, r] of ch) {
      assert.match(pid, /^(petit|grand)_appartement_\d_chambre_[12]$/);
      assert.ok(rooms[r.baseLogement]?.locationData?.logementSocial, pid);
      assert.ok(!r.isLocationRoom && !r.locationData, 'une chambre n\'est pas un bail : ' + pid);
      assert.equal(r.orders[0].fn, 'gerer_logement_social');
      if (pid.startsWith('petit')) assert.ok(pid.endsWith('_chambre_1'));
    }
  }
});

test('images de chambre des Quais et du Marché raccordées, fichiers présents', () => {
  for (const nom of ['marche', 'quais']) {
    const ch = Object.values(ctx.B['logements-novomirsk-' + nom].rooms).filter(r => r.chambreLogement);
    for (const r of ch) {
      assert.equal(r.imageUrl, 'images/Sovarka/Novomirsk/Novomirsk_logements_' + nom + '_chambre.webp');
      assert.ok(existsSync(new URL('../../' + r.imageUrl, import.meta.url)));
    }
  }
  // Starovka (gabarit partagé) : pas d'image empruntée.
  assert.ok(!Object.values(ctx.B['logements-novomirsk'].rooms).some(r => r.chambreLogement && r.imageUrl));
});

test('onglets : une chambre n\'apparaît que dans son appartement premium', async () => {
  const c = { console, state: { country: 'soviet', currentCity: 'capitale', currentBuilding: 'logements-novomirsk', currentRoom: 'grand_appartement_1' },
    BUILDINGS: ctx.B, rendus: 0 };
  c.window = c; c.renderOngletsPieces = () => { c.rendus++; };
  c.sbGet = async (t, q) => { assert.equal(t, 'logements_premium'); assert.match(q, /batiment=eq\.logements-novomirsk/); return [{ piece: 'grand_appartement_1' }]; };
  vm.createContext(c);
  vm.runInContext(lire('plateau-appartements.js'), c);
  const r1 = ctx.B['logements-novomirsk'].rooms.grand_appartement_1_chambre_1;
  const r3 = ctx.B['logements-novomirsk'].rooms.grand_appartement_3_chambre_1;
  assert.equal(c.logementChambreVisible('logements-novomirsk', 'grand_appartement_1_chambre_1', r1), false, 'avant lecture du serveur');
  await c.logementChargerPremium('logements-novomirsk', true);
  assert.ok(c.rendus >= 1);
  assert.equal(c.logementChambreVisible('logements-novomirsk', 'grand_appartement_1_chambre_1', r1), true);
  assert.equal(c.logementChambreVisible('logements-novomirsk', 'grand_appartement_1_chambre_1', r1, 'grand_appartement_1_chambre_2'), true, 'depuis l\'autre chambre');
  assert.equal(c.logementChambreVisible('logements-novomirsk', 'grand_appartement_1_chambre_1', r1, 'salle'), false, 'depuis le hall');
  assert.equal(c.logementChambreVisible('logements-novomirsk', 'grand_appartement_3_chambre_1', r3), false, 'appartement non premium');
  assert.equal(c.logementChambreVisible('logements-novomirsk', 'salle', ctx.B['logements-novomirsk'].rooms.salle), true, 'les autres pièces ne sont jamais filtrées');
});

test('catalogue : chaque texte de l\'écran a ses huit langues, mêmes variables', () => {
  const s = lire('plateau-appartements.js') + lire('plateau-equipements.js');
  const fr = {};
  for (const m of s.matchAll(/texteAppart\('([^']+)',\s*'((?:[^'\\]|\\.)*)'/g)) fr[m[1]] = m[2];
  for (const m of s.matchAll(/\[\s*'((?:refus|role)\.[^']+)',\s*'((?:[^'\\]|\\.)*)'\]/g)) fr[m[1]] = m[2];
  const c = {}; c.window = c; vm.createContext(c);
  vm.runInContext(lire('i18n/appartements-resources.js'), c);
  const cles = new Set(c.RPAppartementsI18n.cles);
  assert.deepEqual([...cles].sort(), Object.keys(fr).sort());
  const vars = (t) => [...String(t).matchAll(/\{(\w+)\}/g)].map(x => x[1]).sort().join(',');
  c.RP_I18N_GAME_ENABLED = true;
  for (const lang of c.RPAppartementsI18n.langues) {
    c.RPPlateauI18n = { language: () => lang };
    for (const k of cles) {
      const t = c.RPAppartementsI18n.texte(k, fr[k]);
      assert.ok(t && t !== fr[k] || /^\{|Chambre|Bail/.test(fr[k]) || lang === 'pt-BR' || lang === 'es', lang + ' ' + k);
      assert.equal(vars(t), vars(fr[k]), lang + ' ' + k);
    }
  }
});

test('raccordements : sommeil, onglets, décor, fenêtre, équipements, scripts', () => {
  assert.match(lire('plateau-personnage.js'), /vRepos\?\.logement/);
  assert.doesNotMatch(lire('plateau-personnage.js'), /getBonusLogementSocialDormir\(\)/);
  const nav = lire('plateau-navigation.js');
  assert.match(nav, /logementChambreVisible\(buildingId, roomId, room, roomActifId\)/);
  assert.match(nav, /logementRafraichirOnglets\(buildingId, roomId\)/);
  assert.match(nav, /logementAppliquerDecor\(pieceImg, buildingId, roomId\)/);
  assert.match(lire('plateau-logements-montrouge.js'), /ouvrirMonLogement\(\)/);
  assert.match(lire('plateau-equipements.js'), /room\.chambreLogement/);
  const html = lire('plateau.html');
  assert.match(html, /plateau-appartements\.js/);
  assert.match(html, /i18n\/appartements-resources\.js/);
});
