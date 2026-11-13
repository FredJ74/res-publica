// Relecture de Fred du 13/11/2026 : raccordements de l'écran et du serveur Vercel.
// Banc serveur annulé : outils/bancs/banc-relecture-fred-20261113.sql (migration 20261113193000).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const lire = (f) => fs.readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

test('chambres créées pour un logement construit en cours de partie, d\'après le serveur', async () => {
  const B = { 'terrain-x': { rooms: {
    accueil: { name: 'Terrain' },
    logement_1: { name: 'Logement n°1', imageBg: '#111', locationData: { logementSocial: true, type: 'petit' } },
    logement_2: { name: 'Logement n°2', imageBg: '#111', locationData: { logementSocial: true, type: 'petit' } }
  } } };
  const c = { console, BUILDINGS: B, rendus: 0,
    state: { country: 'soviet', currentCity: 'capitale', currentBuilding: 'terrain-x', currentRoom: 'logement_1' } };
  c.window = c; c.renderOngletsPieces = () => { c.rendus++; };
  c.sbGet = async (t, q) => { assert.equal(t, 'logements_premium'); assert.match(q, /select=piece,chambres/); return [{ piece: 'logement_1', chambres: 1 }]; };
  vm.createContext(c);
  vm.runInContext(lire('plateau-appartements.js'), c);
  c.logementRafraichirOnglets('terrain-x', 'logement_1');
  await new Promise(r => setTimeout(r, 0));
  const ch = B['terrain-x'].rooms.logement_1_chambre_1;
  assert.ok(ch && ch.chambreLogement && ch.baseLogement === 'logement_1', 'chambre créée');
  assert.equal(B['terrain-x'].rooms.logement_1_chambre_2, undefined, 'petit logement : une seule chambre');
  assert.equal(B['terrain-x'].rooms.logement_2_chambre_1, undefined, 'logement non premium : aucune chambre');
  assert.equal(c.logementChambreVisible('terrain-x', 'logement_1_chambre_1', ch), true);
  assert.equal(c.logementChambreVisible('terrain-x', 'logement_1_chambre_1', ch, 'accueil'), false);
  assert.ok(c.rendus >= 1);
});

test('demande du colocataire : bouton explicite, réponse du titulaire par le courrier', () => {
  const a = lire('plateau-appartements.js');
  assert.match(a, /logement_premium_demander/);
  assert.match(a, /logement_premium_demande_repondre/);
  assert.match(a, /c\\'est le titulaire du bail, \{nom\}, qui décide/);
  assert.match(a, /L\\'option ne sera activée que s\\'il l\\'accepte/);
  const f = lire('forum.js');
  assert.match(f, /premium_oui:\s*\{ fn:'logementPremiumDemandeRepondre', n:1, apres:\['true'\]/);
  assert.match(f, /premium_non:\s*\{ fn:'logementPremiumDemandeRepondre', n:1, apres:\['false'\]/);
  const ui = lire('i18n/forum-ui.js');
  assert.equal((ui.match(/"premium_oui"/g) || []).length, 9);
  assert.equal((ui.match(/"premium_non"/g) || []).length, 9);
});

test('images de référence : champ, case de droits, envoi avant la génération', () => {
  const a = lire('plateau-appartements.js');
  assert.match(a, /id="logement-atelier-sources"/);
  assert.match(a, /id="logement-atelier-droits"/);
  assert.match(a, /atelierAppel\('clear_sources'\)/);
  assert.match(a, /atelierAppel\('upload_source'/);
  const e = lire('supabase/edge-functions/logement-decoration/index.ts');
  assert.match(e, /"upload_source","clear_sources"/);
  assert.match(e, /logements_decors_sources/);
  assert.match(e, /Cinq images maximum/);
});

test('trinquer : réaction écrite par DeepSeek, sans nouvelle fonction Vercel', () => {
  const chat = lire('api/chat.js');
  assert.match(chat, /req\.query\.mode === 'trinquer'\) return handlerReactionHabitant/);
  const r = lire('api/_reaction-habitant.js');
  assert.match(r, /sovarka_maison_trinquer_lire/);
  assert.match(r, /'Dolgor Tsybikova'/);
  assert.match(r, /'Stepan Kouznetsov'/);
  assert.ok(!fs.existsSync(new URL('../../api/reaction-habitant.js', import.meta.url)), 'module préfixé « _ »');
  const p = lire('plateau-sovarka-provinces.js');
  assert.match(p, /\/api\/chat\?mode=trinquer/);
  assert.match(p, /v\._requete = requete/);
});

test('repas chez l\'habitant : +1 PA annoncé dans les neuf langues', () => {
  const s = lire('i18n/sovarka-provinces-resources.js');
  const notes = [...s.matchAll(/"mealNote": "([^"]+)"/g)].map(m => m[1]);
  assert.equal(notes.length, 9);
  for (const n of notes) { assert.match(n, /\+1/); assert.doesNotMatch(n, /\+2/); }
});

test('migration : formule du vol d\'archives et plafond des malus', () => {
  const m = lire('migrations/20261113193000_relecture_fred_20261113.sql');
  assert.match(m, /vol_archives_formule_v2/);
  assert.match(m, /\/ 3\.0/);
  assert.match(m, /least\(33, public\.crime_malus_isn_interne/);
  assert.match(m, /securite_dissuasion/);
  assert.match(m, /SET montant = 1 WHERE source = 'repas_habitant'/);
  // Arithmétique décidée avec Fred : moyen 45, espion optimisé (plafonds à 16) ≈ 78, maladroit ≈ 33.
  const taux = (dis, vol, dup) => Math.min(85, Math.max(5, Math.round(45 + (dis - 50) / 3 + (vol - 8) + (dup - 8))));
  assert.equal(taux(50, 8, 8), 45);
  assert.equal(taux(100, 16, 16), 78);
  assert.equal(taux(30, 5, 6), 33);
  assert.equal(Math.max(5, taux(100, 16, 16) - Math.min(33, 25 + 40)), 45, 'espion optimisé jamais sous 45 %');
});
