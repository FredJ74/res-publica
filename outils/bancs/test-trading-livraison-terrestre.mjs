// Trading national : livraison terrestre à l'entrepôt choisi (décision de Fred, 04/11/2026).
//   node --test outils/bancs/test-trading-livraison-terrestre.mjs
// Gardes de l'écran ; le parcours serveur est éprouvé par banc-trading-livraison-terrestre.sql.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const RACINE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (f) => fs.readFileSync(path.join(RACINE, f), 'utf8');

test("l'achat de trading envoie l'entrepôt de livraison et ne parle plus du port de PSM", () => {
  const src = lire('plateau-equipements.js');
  const achat = src.slice(src.indexOf('async function tradingAcheter('), src.indexOf('async function ouvrirTradingTraders('));
  assert.match(achat, /p_livraison: livraison/);
  assert.doesNotMatch(achat, /Port-Sainte-Marie|port industriel/);
  assert.match(src, /id="trading-livraison"/);
});

test('les trois entrepôts logistiques proposent « Réceptionner une caisse » à la Salle des ventes', () => {
  const data = lire('data.js');
  for (const id of ['entrepot-logistique-luthecia', 'entrepot-logistique-montrouge', 'entrepot-logistique-psm']) {
    const debut = data.indexOf("'" + id + "': {");
    assert.ok(debut > 0, id);
    const bloc = data.slice(debut, data.indexOf('salle_ventes', debut) + 2000);
    assert.match(bloc, /fn:'receptionner_commande'/, id);
  }
});

test('la réception ne liste que les caisses livrées dans le bâtiment courant, et la bonne pièce', () => {
  const src = lire('plateau-justice-economie.js');
  const rec = src.slice(src.indexOf('async function ouvrirReceptionnerCommande('), src.indexOf('async function afficherCaisseArriveeFret('));
  assert.equal((rec.match(/building_destination=eq\./g) || []).length, 1);
  assert.match(rec, /\+ ici\)/);
  assert.match(src, /startsWith\('entrepot-logistique-'\) \? 'salle_ventes' : ROOM_CHARGEMENT_FRET/);
});

test('la réception fait constater les arrivées terrestres échues avant de lister (tranches de 4 h)', () => {
  const src = lire('plateau-justice-economie.js');
  const rec = src.slice(src.indexOf('async function ouvrirReceptionnerCommande('), src.indexOf('async function afficherCaisseArriveeFret('));
  const constat = rec.indexOf("sbRpc('fret_arrivees_constater'");
  assert.ok(constat > 0 && constat < rec.indexOf("sbGet('caisses_fret'"));
});

test("le courrier d'arrivée est déclenché par la lecture du courrier et par la tâche de minuit", () => {
  const core = lire('plateau-core.js');
  assert.match(core, /sbRpc\('fret_arrivees_constater'[\s\S]{0,80}verifierNouveauxMails\(\)/);
  assert.match(core, /setInterval\(\(\) => lancerLectureFond\('mails', constaterArriveesPuisMails\)/);
  const cron = lire('api/cron-minuit.js');
  const f = cron.slice(cron.indexOf('async function traiterArriveesCaissesFret('));
  assert.ok(f.indexOf("sbRpc('fret_arrivees_constater'") < f.indexOf("sbGet('caisses_fret'"));
});

test('le manifeste du port affiche des noms de villes et des statuts en clair, jamais les identifiants', () => {
  const src = lire('plateau-justice-economie.js');
  const f = src.slice(src.indexOf('async function doConsulterManifeste('), src.indexOf('// FRET MARITIME INTERNATIONAL — CAISSES PERSISTANTES'));
  assert.match(f, /VILLES\[pays\]\?\.\[ville\]\?\.nom/);
  assert.match(f, /en_transit: 'En mer'/);
  assert.doesNotMatch(f, /'Origine : ' \+ \(c\.ville_origine/);
  assert.doesNotMatch(f, /'Statut : ' \+ \(c\.statut/);
});
