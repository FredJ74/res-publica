#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DE REGRESSION — CHANTIER A (les 4 P0 autonomes), 14 septembre 2026.

Doctrine identique aux bancs existants du depot (.scratch/banc_*.py) : on charge le VRAI code de
api/cron-minuit.js dans JavaScriptCore, enveloppe dans une IIFE, avec un faux fetch() qui simule
PostgREST sur une base en memoire. Aucune fonction n'est reecrite pour le test : si le banc passe,
c'est le code de production qui passe.

Couverture demandee :
  1.  pret traite une fois
  2.  rejeu du meme pret le meme jour
  3.  erreur pendant le traitement du pret
  4.  cron partiellement execute puis rejoue
  5.  erreur Supabase simulee -> pas de faux succes HTTP 200
  6.  detention unique arrivee a echeance
  7.  detention avec plusieurs motifs dont un seul arrive a echeance
  8.  echeance sans joueur connecte
  9.  rejeu de la liberation
  10. chacune des huit taches financieres executee deux fois -> un seul effet
"""
import json, os, re, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CRON = os.path.join(RACINE, "api", "cron-minuit.js")


def source_cron():
    """Le vrai fichier, rendu chargeable hors ESM : on retire l'import et l'export."""
    s = open(CRON, encoding="utf-8").read()
    s = re.sub(r"^import .*$", "", s, flags=re.M)
    s = re.sub(r"^export default async function handler", "async function handler", s, flags=re.M)
    return s


HARNESS = r"""
// JavaScriptCore n'a ni process ni console : on fournit le strict minimum attendu par le module.
var process = { env: { SUPABASE_URL: 'https://zztest.supabase.co', SUPABASE_ANON_KEY: 'zzanon',
                       SUPABASE_SERVICE_ROLE_KEY: 'zzservice', CRON_SECRET: 'zzsecret' } };
var console = { error: function () {}, log: function () {}, warn: function () {} };

// ---------------------------------------------------------------- faux PostgREST
var BASE = {};              // table -> [lignes]
var JOURNAL_REQUETES = [];  // trace de toutes les ecritures
var PANNES = {};            // "METHODE table" -> nombre d'appels a faire echouer
var ENVOIS_MAIL = [];

function clone(o) { return JSON.parse(JSON.stringify(o)); }

function filtrerLignes(table, query) {
  var lignes = (BASE[table] || []).slice();
  if (!query) return lignes;
  query.split('&').forEach(function (clause) {
    if (clause.indexOf('=') === -1) return;
    var i = clause.indexOf('=');
    var champ = decodeURIComponent(clause.slice(0, i));
    var val = clause.slice(i + 1);
    if (champ === 'select' || champ === 'order' || champ === 'limit') return;
    var m = /^(eq|neq|is|not)\.(.*)$/.exec(val);
    if (!m) return;
    var op = m[1], attendu = decodeURIComponent(m[2]);
    lignes = lignes.filter(function (l) {
      var v = l[champ];
      if (op === 'eq')  return String(v) === attendu;
      if (op === 'neq') return String(v) !== attendu;
      if (op === 'is')  return attendu === 'null' ? (v === null || v === undefined) : String(v) === attendu;
      if (op === 'not') return attendu === 'is.null' ? (v !== null && v !== undefined) : true;
      return true;
    });
  });
  return lignes;
}

globalThis.fetch = function (url, opts) {
  opts = opts || {};
  var methode = opts.method || 'GET';
  var sansBase = String(url).replace(/^.*\/rest\/v1\//, '');
  var estRpc = sansBase.indexOf('rpc/') === 0;
  var table = sansBase.split('?')[0].replace(/^rpc\//, '');
  var query = sansBase.split('?')[1] || '';
  var cle = methode + ' ' + table;

  if (PANNES[cle] && PANNES[cle] > 0) {
    PANNES[cle]--;
    JOURNAL_REQUETES.push({ methode: methode, table: table, echec: true });
    return Promise.resolve({ ok: false, status: 500,
      text: function () { return Promise.resolve('panne simulee sur ' + cle); },
      json: function () { return Promise.resolve(null); } });
  }

  if (estRpc) {
    JOURNAL_REQUETES.push({ methode: 'RPC', table: table });
    return Promise.resolve({ ok: true, status: 200, json: function () { return Promise.resolve([{}]); },
      text: function () { return Promise.resolve(''); } });
  }

  var corps = opts.body ? JSON.parse(opts.body) : null;

  if (methode === 'GET') {
    return Promise.resolve({ ok: true, status: 200,
      json: function () { return Promise.resolve(clone(filtrerLignes(table, query))); },
      text: function () { return Promise.resolve(''); } });
  }

  if (methode === 'POST') {
    BASE[table] = BASE[table] || [];
    var nouvelles = Array.isArray(corps) ? corps : [corps];
    nouvelles.forEach(function (l) { BASE[table].push(clone(l)); });
    if (table === 'mails') nouvelles.forEach(function (l) { ENVOIS_MAIL.push(clone(l)); });
    JOURNAL_REQUETES.push({ methode: 'POST', table: table, data: clone(corps) });
    return Promise.resolve({ ok: true, status: 201, json: function () { return Promise.resolve(clone(nouvelles)); },
      text: function () { return Promise.resolve(''); } });
  }

  if (methode === 'PATCH') {
    var cibles = filtrerLignes(table, query);
    (BASE[table] || []).forEach(function (l) {
      for (var k = 0; k < cibles.length; k++) {
        if (cibles[k].id !== undefined ? cibles[k].id === l.id
            : (cibles[k].name !== undefined ? cibles[k].name === l.name : cibles[k] === l)) {
          for (var c in corps) l[c] = corps[c];
          break;
        }
      }
    });
    JOURNAL_REQUETES.push({ methode: 'PATCH', table: table, query: query, data: clone(corps), touchees: cibles.length });
    return Promise.resolve({ ok: true, status: 200, json: function () { return Promise.resolve(clone(cibles)); },
      text: function () { return Promise.resolve(''); } });
  }

  if (methode === 'DELETE') {
    var aSupprimer = filtrerLignes(table, query);
    BASE[table] = (BASE[table] || []).filter(function (l) { return aSupprimer.indexOf(l) === -1; });
    JOURNAL_REQUETES.push({ methode: 'DELETE', table: table });
    return Promise.resolve({ ok: true, status: 204, json: function () { return Promise.resolve([]); },
      text: function () { return Promise.resolve(''); } });
  }

  return Promise.resolve({ ok: false, status: 405, text: function () { return Promise.resolve('methode inconnue'); } });
};

// ---------------------------------------------------------------- assertions
var RESULTATS = [];
function verifier(nom, condition, detail) {
  RESULTATS.push({ nom: nom, ok: !!condition, detail: detail === undefined ? '' : String(detail) });
}
function reinitialiser() {
  BASE = {}; JOURNAL_REQUETES = []; PANNES = {}; ENVOIS_MAIL = [];
  ECHECS_PASSE = []; REGISTRE_JOURS_PASSE = null;
}
function argDe(nom) {
  var l = (BASE.personnages || []).filter(function (p) { return p.name === nom; })[0];
  return l ? l.arg : null;
}
"""

SCENARIOS = r"""
// ==========================================================================================
// P0-1 — PRETS
// ==========================================================================================
async function testsPrets() {
  // --- 1. pret traite une fois -------------------------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Emprunteur', arg: 10000, liquide: 10000, moral: 75 }];
  BASE.prets = [{ id: 'zztest-pret-1', emprunteur: 'Zztest Emprunteur', country: 'republic',
                  building_id: 'terrain-zz', type_banque: 'nationale', montant_initial: 1000,
                  montant_restant: 1000, mensualite: 100, jours_impayes: 0,
                  jour_dernier_prelevement: null, statut: 'en_cours',
                  created_at: '2026-09-20T00:00:00Z' }];
  var r1 = await preleverPretsBancairesServeur();
  verifier('P0-1/1 une mensualite prelevee', r1.preleves === 1, 'preleves=' + r1.preleves);
  verifier('P0-1/1 arg debite de 100', argDe('Zztest Emprunteur') === 9900, argDe('Zztest Emprunteur'));
  verifier('P0-1/1 dette reduite a 900', BASE.prets[0].montant_restant === 900, BASE.prets[0].montant_restant);
  verifier('P0-1/1 marqueur pose au jour courant',
           BASE.prets[0].jour_dernier_prelevement === jourCourantISO(), BASE.prets[0].jour_dernier_prelevement);

  // --- 2. rejeu le meme jour ---------------------------------------------------------------
  var r2 = await preleverPretsBancairesServeur();
  verifier('P0-1/2 rejeu ne preleve rien', r2.preleves === 0, 'preleves=' + r2.preleves);
  verifier('P0-1/2 arg inchange apres rejeu', argDe('Zztest Emprunteur') === 9900, argDe('Zztest Emprunteur'));
  verifier('P0-1/2 dette inchangee apres rejeu', BASE.prets[0].montant_restant === 900, BASE.prets[0].montant_restant);

  // --- 3. erreur pendant le traitement du pret ---------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Panne', arg: 10000, liquide: 10000, moral: 75 }];
  BASE.prets = [{ id: 'zztest-pret-2', emprunteur: 'Zztest Panne', country: 'republic',
                  building_id: 'terrain-zz', type_banque: 'nationale', montant_initial: 1000,
                  montant_restant: 1000, mensualite: 100, jours_impayes: 0,
                  jour_dernier_prelevement: null, statut: 'en_cours',
                  created_at: '2026-09-20T00:00:00Z' }];
  PANNES['GET personnages'] = 99;   // la lecture de l'emprunteur echoue
  var r3 = await preleverPretsBancairesServeur();
  verifier('P0-1/3 aucun prelevement quand la lecture echoue', r3.preleves === 0, 'preleves=' + r3.preleves);
  verifier('P0-1/3 arg intact', argDe('Zztest Panne') === 10000, argDe('Zztest Panne'));
  verifier('P0-1/3 echec remonte au registre de passe', ECHECS_PASSE.length > 0, 'nb=' + ECHECS_PASSE.length);
  PANNES = {};

  // --- fonds insuffisants : escalade, mail reellement expedie ------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Fauche', arg: 10, liquide: 10, moral: 75 }];
  BASE.prets = [{ id: 'zztest-pret-3', emprunteur: 'Zztest Fauche', country: 'republic',
                  building_id: 'terrain-zz', type_banque: 'nationale', montant_initial: 1000,
                  montant_restant: 1000, mensualite: 100, jours_impayes: 0,
                  jour_dernier_prelevement: null, statut: 'en_cours',
                  created_at: '2026-09-20T00:00:00Z' }];
  var r4 = await preleverPretsBancairesServeur();
  verifier('P0-1/4 impaye compte', r4.impayes === 1, 'impayes=' + r4.impayes);
  verifier('P0-1/4 arg non entame', argDe('Zztest Fauche') === 10, argDe('Zztest Fauche'));
  verifier('P0-1/4 jours_impayes incremente', BASE.prets[0].jours_impayes === 1, BASE.prets[0].jours_impayes);
  verifier('P0-1/4 avertissement reellement expedie', ENVOIS_MAIL.length === 1, 'mails=' + ENVOIS_MAIL.length);
  var m = ENVOIS_MAIL[0] || {};
  verifier('P0-1/4 mail au bon schema de colonnes',
           m.to_player === 'Zztest Fauche' && !!m.from_player && !!m.subject && !!m.body && !!m.id,
           JSON.stringify(Object.keys(m)));
  verifier('P0-1/4 aucune colonne francaise residuelle',
           m.destinataire === undefined && m.sujet === undefined && m.corps === undefined, 'ok');
  verifier('P0-1/4 aucun echec signale', ECHECS_PASSE.length === 0, JSON.stringify(ECHECS_PASSE));

  // --- gel des prets anterieurs a la reparation --------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Historique', arg: 100000, liquide: 100000, moral: 75 }];
  BASE.prets = [{ id: 'zztest-pret-vieux', emprunteur: 'Zztest Historique', country: 'republic',
                  building_id: 'terrain-zz', type_banque: 'nationale', montant_initial: 100000,
                  montant_restant: 110000, mensualite: 3667, jours_impayes: 0,
                  jour_dernier_prelevement: null, statut: 'en_cours',
                  created_at: '2026-08-15T21:44:45Z' }];
  var r5 = await preleverPretsBancairesServeur();
  verifier('P0-1/5 pret historique gele', r5.gelesPourArbitrage.length === 1, JSON.stringify(r5.gelesPourArbitrage));
  verifier('P0-1/5 aucun prelevement sur le gele', r5.preleves === 0 && r5.impayes === 0, 'p=' + r5.preleves);
  verifier('P0-1/5 ligne strictement intacte',
           BASE.prets[0].montant_restant === 110000 && BASE.prets[0].jours_impayes === 0 &&
           BASE.prets[0].jour_dernier_prelevement === null && BASE.prets[0].statut === 'en_cours', 'ok');
  verifier('P0-1/5 argent du joueur intact', argDe('Zztest Historique') === 100000, argDe('Zztest Historique'));
}

// ==========================================================================================
// P0-3 — DETENTION
// ==========================================================================================
var JOUR_MS = 24 * 60 * 60 * 1000;

async function testsDetention() {
  // --- 6. detention unique arrivee a echeance ----------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Detenu', arg: 0, detention_qhs: null,
    est_emprisonne: { jours: 2, jourFin: 12, raison: 'Vol', detentionId: 'zzdet-1',
                      debutTs: Date.now() - 3 * JOUR_MS } }];
  BASE.detentions = [{ id: 'zzdet-1', nom: 'Zztest Detenu', jour_debut: 10, jour_fin: 12,
                       mode_fin: null, motifs: [{ type: 'Vol', jours: 2 }] }];
  var d1 = await libererDetentionsEchuesServeur();
  verifier('P0-3/6 detenu libere', d1.liberes === 1, JSON.stringify(d1));
  verifier('P0-3/6 est_emprisonne remis a null', BASE.personnages[0].est_emprisonne === null, BASE.personnages[0].est_emprisonne);
  verifier('P0-3/6 registre clos en purgee', BASE.detentions[0].mode_fin === 'purgee', BASE.detentions[0].mode_fin);
  verifier('P0-3/6 motifs preserves', JSON.stringify(BASE.detentions[0].motifs) === JSON.stringify([{ type: 'Vol', jours: 2 }]), 'ok');
  verifier('P0-3/6 date de fin reelle posee', !!BASE.detentions[0].date_fin_effective, BASE.detentions[0].date_fin_effective);
  verifier('P0-3/6 mail de liberation expedie', ENVOIS_MAIL.length === 1 && ENVOIS_MAIL[0].to_player === 'Zztest Detenu', 'ok');

  // --- 9. rejeu de la liberation ------------------------------------------------------------
  var d2 = await libererDetentionsEchuesServeur();
  verifier('P0-3/9 rejeu ne libere personne', d2.liberes === 0, JSON.stringify(d2));
  verifier('P0-3/9 rejeu n\'envoie pas un second mail', ENVOIS_MAIL.length === 1, 'mails=' + ENVOIS_MAIL.length);

  // --- peine non echue ----------------------------------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Frais', arg: 0, detention_qhs: null,
    est_emprisonne: { jours: 5, jourFin: 15, raison: 'Vol', detentionId: 'zzdet-2',
                      debutTs: Date.now() - 1 * JOUR_MS } }];
  BASE.detentions = [{ id: 'zzdet-2', nom: 'Zztest Frais', jour_debut: 10, jour_fin: 15, mode_fin: null }];
  var d3 = await libererDetentionsEchuesServeur();
  verifier('P0-3/x peine non echue non liberee', d3.liberes === 0, JSON.stringify(d3));
  verifier('P0-3/x detenu toujours detenu', BASE.personnages[0].est_emprisonne !== null, 'ok');

  // --- 7. plusieurs motifs, un seul arrive a echeance ---------------------------------------
  // Le modele du jeu empile les motifs dans UNE ligne dont jour_fin couvre leur somme :
  // 1 jour de vol echu + 5 jours de recel non echu = 6 jours, la peine ne doit pas tomber.
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Multi', arg: 0, detention_qhs: null,
    est_emprisonne: { jours: 6, jourFin: 16, raison: 'Vol + recel', detentionId: 'zzdet-3',
                      debutTs: Date.now() - 2 * JOUR_MS } }];
  BASE.detentions = [{ id: 'zzdet-3', nom: 'Zztest Multi', jour_debut: 10, jour_fin: 16, mode_fin: null,
    motifs: [{ type: 'Vol', jours: 1, source: 'flagrant_delit' },
             { type: 'Recel', jours: 5, source: 'jugement' }] }];
  var d4 = await libererDetentionsEchuesServeur();
  verifier('P0-3/7 motif echu seul ne libere pas', d4.liberes === 0, JSON.stringify(d4));
  verifier('P0-3/7 les deux motifs restent intacts', BASE.detentions[0].motifs.length === 2, 'ok');
  verifier('P0-3/7 ligne toujours ouverte', BASE.detentions[0].mode_fin === null, BASE.detentions[0].mode_fin);

  // --- une autre ligne de detention encore ouverte ------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Deux', arg: 0, detention_qhs: null,
    est_emprisonne: { jours: 1, jourFin: 11, raison: 'Vol', detentionId: 'zzdet-4',
                      debutTs: Date.now() - 9 * JOUR_MS } }];
  BASE.detentions = [
    { id: 'zzdet-4', nom: 'Zztest Deux', jour_debut: 10, jour_fin: 11, mode_fin: null },
    { id: 'zzdet-5', nom: 'Zztest Deux', jour_debut: 10, jour_fin: 40, mode_fin: null }
  ];
  var d5 = await libererDetentionsEchuesServeur();
  verifier('P0-3/x autre detention ouverte : pas de liberation', d5.liberes === 0 && d5.autreDetentionActive === 1, JSON.stringify(d5));
  verifier('P0-3/x detenu maintenu', BASE.personnages[0].est_emprisonne !== null, 'ok');
  verifier('P0-3/x aucune ligne close', BASE.detentions[0].mode_fin === null && BASE.detentions[1].mode_fin === null, 'ok');

  // --- QHS hors perimetre --------------------------------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Qhs', arg: 0,
    detention_qhs: '{"enQHS":true,"paLimite1Jour":false}',
    est_emprisonne: { jours: 1, jourFin: 11, raison: 'Rebellion', detentionId: 'zzdet-6',
                      debutTs: Date.now() - 30 * JOUR_MS } }];
  BASE.detentions = [{ id: 'zzdet-6', nom: 'Zztest Qhs', jour_debut: 10, jour_fin: 11, mode_fin: null }];
  var d6 = await libererDetentionsEchuesServeur();
  verifier('P0-3/x QHS jamais libere par le filet', d6.liberes === 0 && d6.qhsIgnores === 1, JSON.stringify(d6));
  verifier('P0-3/x QHS reste detenu', BASE.personnages[0].est_emprisonne !== null, 'ok');

  // --- donnee historique sans ancre temps reel ----------------------------------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Ancien', arg: 0, detention_qhs: null,
    est_emprisonne: { jours: 8, jourFin: 10, raison: 'Crime' } }];
  var d7 = await libererDetentionsEchuesServeur();
  verifier('P0-3/x sans ancre : signale, jamais devine', d7.liberes === 0 && d7.sansAncre === 1, JSON.stringify(d7));
  verifier('P0-3/x sans ancre : donnee intacte', BASE.personnages[0].est_emprisonne !== null, 'ok');

  // --- 8. echeance sans joueur connecte ------------------------------------------------------
  // Le filet ne lit que la base : aucun state client, aucune session. Ce test le prouve en
  // n'exposant volontairement AUCUN objet de jeu cote client.
  reinitialiser();
  verifier('P0-3/8 aucun state client dans le contexte', typeof state === 'undefined', 'ok');
  BASE.personnages = [{ name: 'Zztest Absent', arg: 0, detention_qhs: null,
    est_emprisonne: { jours: 3, jourFin: 13, raison: 'Vol', detentionId: 'zzdet-7',
                      debutTs: Date.now() - 10 * JOUR_MS } }];
  BASE.detentions = [{ id: 'zzdet-7', nom: 'Zztest Absent', jour_debut: 10, jour_fin: 13, mode_fin: null }];
  var d8 = await libererDetentionsEchuesServeur();
  verifier('P0-3/8 joueur absent libere quand meme', d8.liberes === 1, JSON.stringify(d8));

  // --- double encodage : un est_emprisonne stringifie ne bloque plus a vie ------------------
  reinitialiser();
  BASE.personnages = [{ name: 'Zztest Chaine', arg: 0, detention_qhs: null,
    est_emprisonne: JSON.stringify({ jours: 2, jourFin: 12, raison: 'Garde a vue',
                                     detentionId: 'zzdet-8', debutTs: Date.now() - 5 * JOUR_MS }) }];
  BASE.detentions = [{ id: 'zzdet-8', nom: 'Zztest Chaine', jour_debut: 10, jour_fin: 12, mode_fin: null }];
  var d9 = await libererDetentionsEchuesServeur();
  verifier('P0-3/x est_emprisonne double-encode : lu et libere', d9.liberes === 1, JSON.stringify(d9));
}

// ==========================================================================================
// P0-4 — IDEMPOTENCE DES HUIT TACHES FINANCIERES
// ==========================================================================================
var HUIT_TACHES = ['taxe_fonciere', 'preemptions_etat', 'livraisons_entrepots', 'exportations_port',
                   'arrivage_criee', 'production_transformateurs', 'effets_blocus', 'effort_de_guerre'];

async function testsIdempotence() {
  // --- 10. chaque tache executee deux fois -> un seul effet ---------------------------------
  reinitialiser();
  var compteurs = {};
  for (var i = 0; i < HUIT_TACHES.length; i++) {
    var nom = HUIT_TACHES[i];
    compteurs[nom] = 0;
    /* jshint loopfunc:true */
    var fn = (function (n) { return function () { compteurs[n]++; return { effet: 1 }; }; })(nom);
    await tacheQuotidienne(nom, fn);
    var deuxieme = await tacheQuotidienne(nom, fn);
    verifier('P0-4/10 ' + nom + ' : un seul effet sur deux passes', compteurs[nom] === 1, 'appels=' + compteurs[nom]);
    verifier('P0-4/10 ' + nom + ' : rejeu explicitement ignore',
             deuxieme && deuxieme.ignoree === 'deja_executee_ce_jour', JSON.stringify(deuxieme));
  }
  verifier('P0-4/10 registre persiste en base', (BASE.batiments_etat || []).length === 1,
           'lignes=' + ((BASE.batiments_etat || []).length));
  var registre = JSON.parse(BASE.batiments_etat[0].data).joursCron;
  verifier('P0-4/10 les huit taches sont marquees', Object.keys(registre).length === 8, JSON.stringify(Object.keys(registre)));

  // --- 4. cron partiellement execute puis rejoue --------------------------------------------
  // Trois taches passent, la quatrieme echoue, la passe est relancee : les trois premieres ne
  // doivent PAS rejouer, la quatrieme et les suivantes doivent reprendre.
  reinitialiser();
  var appels = {};
  function tache(n) {
    return function () { appels[n] = (appels[n] || 0) + 1;
                         if (n === 'exportations_port' && (appels[n] === 1)) throw new Error('panne simulee'); return { ok: 1 }; };
  }
  async function passe() {
    for (var k = 0; k < HUIT_TACHES.length; k++) {
      try { await tacheQuotidienne(HUIT_TACHES[k], tache(HUIT_TACHES[k])); }
      catch (e) { signalerEchec('tache:' + HUIT_TACHES[k], e); }
    }
  }
  await passe();
  var apresPremiere = JSON.stringify(appels);
  await passe();   // rejeu de toute la passe
  verifier('P0-4/4 taches deja reussies non rejouees',
           appels.taxe_fonciere === 1 && appels.preemptions_etat === 1 && appels.livraisons_entrepots === 1,
           apresPremiere + ' -> ' + JSON.stringify(appels));
  verifier('P0-4/4 taches suivantes bien executees',
           appels.arrivage_criee === 1 && appels.production_transformateurs === 1 &&
           appels.effets_blocus === 1 && appels.effort_de_guerre === 1, JSON.stringify(appels));
  verifier('P0-4/4 la tache tombee est marquee et non retentee le meme jour',
           appels.exportations_port === 1, 'appels=' + appels.exportations_port);
  verifier('P0-4/4 l\'echec reste visible', ECHECS_PASSE.length >= 1, 'nb=' + ECHECS_PASSE.length);

  // --- marqueur non persistable : la tache ne tourne pas (fail-closed) ----------------------
  reinitialiser();
  var tourne = 0;
  PANNES['GET batiments_etat'] = 99;
  PANNES['POST batiments_etat'] = 99;
  PANNES['PATCH batiments_etat'] = 99;
  var res = await tacheQuotidienne('taxe_fonciere', function () { tourne++; return {}; });
  verifier('P0-4/x marqueur impossible : tache non executee', tourne === 0, 'tourne=' + tourne);
  verifier('P0-4/x marqueur impossible : signale', ECHECS_PASSE.length > 0, JSON.stringify(ECHECS_PASSE));
  PANNES = {};
}

// ==========================================================================================
// P0-2 — PAS DE FAUX SUCCES
// ==========================================================================================
async function testsEchecs() {
  // --- 5. erreur Supabase simulee -> l'echec est enregistre et nomme ------------------------
  reinitialiser();
  PANNES['GET cycles_electoraux'] = 1;
  var lu = await sbGet('cycles_electoraux', 'select=*');
  verifier('P0-2/5 lecture en echec rend null', lu === null, String(lu));
  verifier('P0-2/5 echec enregistre', ECHECS_PASSE.length === 1, JSON.stringify(ECHECS_PASSE));
  verifier('P0-2/5 etape nommee precisement',
           ECHECS_PASSE[0].etape === 'sbGet:cycles_electoraux', ECHECS_PASSE[0].etape);

  // table vide vs erreur : une table vide ne doit JAMAIS ressembler a un echec
  reinitialiser();
  BASE.cycles_electoraux = [];
  var vide = await sbGet('cycles_electoraux', 'select=*');
  verifier('P0-2/x table vide rend un tableau, pas null',
           Array.isArray(vide) && vide.length === 0, JSON.stringify(vide));
  verifier('P0-2/x table vide ne signale aucun echec', ECHECS_PASSE.length === 0, JSON.stringify(ECHECS_PASSE));

  // toutes les primitives alimentent le registre
  reinitialiser();
  PANNES['POST mails'] = 1; PANNES['PATCH personnages'] = 1; PANNES['DELETE mails'] = 1;
  await sbInsert('mails', { id: 'zz', to_player: 'a', from_player: 'b', subject: 'c', body: 'd' });
  await sbUpdate('personnages', 'name=eq.zz', { arg: 1 });
  await sbDelete('mails', 'id=eq.zz');
  verifier('P0-2/x les trois primitives d\'ecriture signalent', ECHECS_PASSE.length === 3, JSON.stringify(ECHECS_PASSE.map(function (e) { return e.etape; })));

  // le code source lui-meme ne doit plus contenir la sortie 200 anticipee
  verifier('P0-2/x plus de "Aucun cycle electoral trouve" en sortie anticipee',
           SOURCE_CRON.indexOf("res.status(200).json({ ok: true, message: 'Aucun cycle") === -1, 'ok');
  verifier('P0-2/x le handler conclut sur le registre d\'echecs',
           SOURCE_CRON.indexOf('ECHECS_PASSE.length > 0') !== -1 &&
           SOURCE_CRON.indexOf('return res.status(500).json(corps)') !== -1, 'ok');
  // Aucune insertion dans la table mails ne doit plus porter le schema francais inexistant.
  // (La colonne 'destinataire' existe bel et bien sur objets_recus : on ne cible que mails.)
  var insertsMails = SOURCE_CRON.split("sbInsert('mails'");
  var francais = 0;
  for (var q = 1; q < insertsMails.length; q++) {
    var extrait = insertsMails[q].slice(0, 400);
    if (/\bdestinataire\s*:|\bexpediteur\s*:|\bsujet\s*:|\bcorps\s*:/.test(extrait)) francais++;
  }
  verifier('P0-2/x plus aucune insertion de mail au schema francais', francais === 0, 'restants=' + francais);
  verifier('P0-2/x la brique d\'envoi existe et est utilisee',
           SOURCE_CRON.indexOf('async function envoyerMailSysteme') !== -1 &&
           SOURCE_CRON.split('envoyerMailSysteme(').length - 1 >= 15, 'ok');
}

// ==========================================================================================
(async function () {
  try {
    await testsPrets();
    await testsDetention();
    await testsIdempotence();
    await testsEchecs();
  } catch (e) {
    RESULTATS.push({ nom: 'EXCEPTION NON RATTRAPEE', ok: false, detail: String(e) + ' | ' + (e && e.stack) });
  }
  print(JSON.stringify(RESULTATS));
})();
"""


def main():
    src = source_cron()
    prog = (
        HARNESS
        + "\nvar SOURCE_CRON = " + json.dumps(src) + ";\n"
        + src
        + "\n"
        + SCENARIOS
    )
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
        f.write(prog)
        chemin = f.name
    try:
        out = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=180)
    finally:
        os.unlink(chemin)

    brut = (out.stdout or "").strip().splitlines()
    ligne = brut[-1] if brut else ""
    if out.returncode != 0 and not ligne.startswith("["):
        print("ECHEC D'EXECUTION\n", out.stdout, out.stderr)
        return 1
    try:
        resultats = json.loads(ligne)
    except Exception:
        print("SORTIE ILLISIBLE\n", out.stdout, out.stderr)
        return 1

    for r in resultats:
        if not r["ok"]:
            print("  KO   %-62s %s" % (r["nom"], r["detail"]))
    total = len(resultats)
    ko = sum(1 for r in resultats if not r["ok"])
    print("\n%d assertions, %d en echec." % (total, ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
