#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Banc d'execution REEL -- tracts electoraux ordinaires aupres des PNJ (11 septembre 2026).

Charge le VRAI data.js complet, puis execute dans JavaScriptCore les VRAIES fonctions : helpers
electoraux (plateau-politique.js), distribution (plateau-communication.js), don d'objet a un PNJ
(plateau-justice-economie.js), decompte du cron (api/cron-minuit.js). Horloge simulee ; la RPC
tracts_electoraux_distribuer est bouchonnee (le serveur est teste a part, en base, via MCP).

Usage : python3 .scratch/banc_jsc_tracts_electoraux.py
"""
import os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


def extraire(src, nom, genre='function'):
    m = re.search((r'^(async )?function ' if genre == 'function' else r'^const ') + re.escape(nom) + (r'\(' if genre == 'function' else r'\s*='), src, re.M)
    if not m:
        raise SystemExit('introuvable : ' + nom)
    suite = re.compile(r'^(async function |function |const |let |var |// =====|export )', re.M).search(src, m.end())
    return src[m.start(): suite.start() if suite else len(src)].rstrip() + '\n'


def en_expression(code):
    return re.sub(r'^(async )?function (\w+)\(', lambda m: 'var %s = %sfunction %s(' % (m.group(2), m.group(1) or '', m.group(2)), code, flags=re.M)


P, C, J, CRON, R = lire('plateau-politique.js'), lire('plateau-communication.js'), lire('plateau-justice-economie.js'), lire('api/cron-minuit.js'), lire('plateau-router.js')
SOURCES = ''.join(en_expression(x) for x in [
    extraire(P, 'posteEstLocal'), extraire(P, 'getCleCycle'), extraire(P, 'getPhaseActuelle'),
    extraire(P, 'FUSEAU_ELECTORAL', 'const'), extraire(P, 'CANDIDATURES_MIN_MS', 'const'),
    extraire(P, 'partiesHeureParis'), extraire(P, 'instantHeureParis'), extraire(P, 'dateCalendairePlusJours'),
    extraire(P, 'lundiSemaineParis'), extraire(P, 'datesScrutinSemaine'), extraire(P, 'calendrierPremierTour'),
    extraire(P, 'calendrierTourSuivant'), extraire(P, 'lundiMinuitParisApresSemaines'), extraire(P, 'decalerSemainesParis'),
    extraire(P, 'candidaturesOuvertes'), extraire(P, 'construireNouveauCycleElectoral'), extraire(P, 'resoudreScrutinDepute'),
    extraire(P, 'departageCandidats'),
    extraire(C, 'BOIS_PAR_LOT_TRACTS', 'const'), extraire(C, 'BOIS_PAR_LOT_TRACTS_PSM', 'const'),
    extraire(C, 'QUANTITES_LOTS_TRACTS', 'const'), extraire(C, 'selectTractType'),
    extraire(C, 'stockBoisPersonnel'), extraire(C, 'PRIX_LOT_TRACTS', 'const'),
    extraire(C, 'prixLotTractsAtelier'), extraire(C, 'confirmerImprimerTractsElectoraux'),
    extraire(P, 'POSTES_TRACTS_ELECTORAUX', 'const'), extraire(P, 'LIEUX_PRESIDENTIELLE', 'const'),
    extraire(P, 'attacherEffetsTracts'), extraire(P, 'appliquerEffetsTracts'), extraire(P, 'ajouterEffetTractLocal'),
    extraire(P, 'chargerEffetsTractsPNJ'), extraire(P, 'estDimancheParis'), extraire(P, 'libelleScrutinTract'),
    extraire(P, 'scrutinsDistribuablesPourTract'), extraire(P, 'tractsElectorauxDistribuablesIci'),
    extraire(P, 'calculerScoresBaseCycle'), extraire(P, 'arrondirPourcentages'), extraire(P, 'calculerSondageElectoral'),
    extraire(C, 'volontePnjElectorale'), extraire(C, 'MOTIFS_REFUS_TRACT_ELECTORAL', 'const'),
    extraire(C, 'distribuerTractElectoralPNJ'), extraire(C, 'confirmerDistribuerTractElectoral'),
    extraire(J, 'confirmerDonObjetPnj'),
]).replace('const ', 'var ')
CRON_SCORES = en_expression(extraire(CRON, 'appliquerEffetsTracts').replace('function appliquerEffetsTracts(', 'function appliquerEffetsTractsCron(')
                            + extraire(CRON, 'calculerScoresBaseCycle').replace('function calculerScoresBaseCycle(', 'function calculerScoresBaseCycleCron(').replace('appliquerEffetsTracts(scores', 'appliquerEffetsTractsCron(scores')
                            + extraire(CRON, 'resoudreScrutinDepute').replace('function resoudreScrutinDepute(', 'function resoudreScrutinDeputeCron(').replace('calculerScoresBaseCycle(cycle', 'calculerScoresBaseCycleCron(cycle').replace('departageCandidats(', 'departageCandidatsCron(')
                            + extraire(CRON, 'departageCandidats').replace('function departageCandidats(', 'function departageCandidatsCron(')
                            + extraire(CRON, 'construireNouveauCycleElectoral').replace('function construireNouveauCycleElectoral(', 'function construireNouveauCycleElectoralCron(').replace('calendrierPremierTour(', 'calendrierPremierTourCron(')
                            + extraire(CRON, 'calendrierPremierTour').replace('function calendrierPremierTour(', 'function calendrierPremierTourCron('))

banc = r"""
var window = this, document = {}, localStorage = { getItem: function () { return null; }, setItem: function () {} };
%DATA%
var DONNEES = { WORLD: WORLD, BUILDINGS: BUILDINGS, COUNTRIES: COUNTRIES, POSTES_ELECTIFS: POSTES_ELECTIFS, PHASES_ELECTORALES: PHASES_ELECTORALES };
var VraieDate = Date, MAINTENANT = 0;
var DateSimulee = function () { return arguments.length ? new (Function.prototype.bind.apply(VraieDate, [null].concat([].slice.call(arguments))))() : new VraieDate(MAINTENANT); };
DateSimulee.now = function () { return MAINTENANT; }; DateSimulee.prototype = VraieDate.prototype;
DateSimulee.UTC = VraieDate.UTC; DateSimulee.parse = VraieDate.parse;
var instant = function (iso) { return VraieDate.parse(iso); };

var ETATS = {};
var journal;
function raz() { journal = { toasts: [], appels: [], rpc: [], sauvegardes: 0, pop: [], saisies: {} }; }
var bouchons = {
  state: null, Date: DateSimulee, CYCLES_ELECTORAUX: {}, TEST_MODE: false,
  getFondsDisponiblesOrdinaires: function () { return (bouchons.state.liquide || 0) + (bouchons.state.comptesBancaires?.nationale?.solde || 0); },
  deduireCoutOrdre: function (o) {
    var pa = o.pa || 0, cost = o.cost || 0, st = bouchons.state;
    if ((st.pa || 0) < pa) return Promise.resolve({ ok: false, raison: 'pa_insuffisants' });
    if (cost > bouchons.getFondsDisponiblesOrdinaires()) return Promise.resolve({ ok: false, raison: 'fonds_insuffisants' });
    st.pa -= pa;
    var liq = Math.min(st.liquide || 0, cost); st.liquide -= liq;
    if (cost - liq > 0) st.comptesBancaires.nationale.solde -= (cost - liq);
    st.arg = (st.arg || 0) - cost;
    return Promise.resolve({ ok: true, paPreleves: pa, montantPreleve: cost });
  },
  signalerRefusCout: function (r) { journal.toasts.push('refus | ' + r.raison); },
  crediterCaisseEtatBatiment: function (p, v, b, cle, m) {
    var k = p + '/' + v + '/' + b; ETATS[k] = ETATS[k] || {};
    ETATS[k][cle] = Object.assign({}, ETATS[k][cle], { caisse: ((ETATS[k][cle] || {}).caisse || 0) + m });
    return Promise.resolve(true);
  },
  WORLD: DONNEES.WORLD, BUILDINGS: DONNEES.BUILDINGS, COUNTRIES: DONNEES.COUNTRIES, POSTES_ELECTIFS: DONNEES.POSTES_ELECTIFS, PHASES_ELECTORALES: DONNEES.PHASES_ELECTORALES,
  showToast: function (t, m) { journal.toasts.push(t + ' | ' + (m || '')); },
  addJournalEntry: function () {}, updateUI: function () {}, sauvegarderPersonnageImmediat: function () { journal.appels.push('sauvegardeImmediate'); },
  verifierProgressionCarriere: function (b, s) { journal.appels.push('carriere:' + b + ':' + s); },
  syncCyclesDepuisSupabase: function () { journal.appels.push('sync'); return Promise.resolve(); },
  sbSavePersonnage: function () { journal.sauvegardes++; return Promise.resolve(bouchons._sauvegardeOk ? [{}] : null); },
  sbTractsElectorauxDistribuer: function (rq, j, cid, cand, sens, pnj, vol) {
    journal.rpc.push({ rq: rq, joueur: j, cycleId: cid, candidat: cand, sens: sens, pnj: pnj, vol: vol });
    return Promise.resolve(bouchons._reponse(journal.rpc.length));
  },
  sbTractAppliquerEffetPop: function (n, d) { journal.pop.push(n + ':' + d); return Promise.resolve({ ok: true }); },
  sbAjusterPopJoueur: function (n, d) { journal.pop.push('ANCIEN:' + n + ':' + d); return Promise.resolve(); },
  sbChargerEffetsTractsPNJ: function () { return Promise.resolve(bouchons._lignesEffets || []); },
  sbGetBatimentEtat: function (p, v, b) { return Promise.resolve(JSON.parse(JSON.stringify(ETATS[p + '/' + v + '/' + b] || {}))); },
  sbSetBatimentEtat: function (p, v, b, e) { ETATS[p + '/' + v + '/' + b] = JSON.parse(JSON.stringify(e)); return Promise.resolve(); },
  renderInventory: function () {},
  document: { getElementById: function (id) { return { value: (journal.saisies || {})[id] || '', classList: { add: function () {}, remove: function () {} },
    set textContent(v) { if (id === 'postes-modal-title') journal.titre = v; }, get textContent() { return ''; },
    set innerHTML(v) { if (id === 'postes-body') journal.corps = v; }, get innerHTML() { return ''; } }; } },
  _sauvegardeOk: true, _reponse: function () { return { ok: true, reussi: true, effet: 1, tour: 0, jet: 10, taux: 65 }; }
};
bouchons.window = bouchons;
var auto = {};
var BANC = new Set(['journal', 'raz', 'ETATS', 'bouchons', 'auto', 'bac', 'BANC', 'resultats', 'verifier', 'Math', 'DONNEES', 'JSON', 'Promise', 'Object', 'String', 'Set', 'setTimeout', 'Intl', 'VraieDate', 'MAINTENANT', 'DateSimulee', 'instant', 'Number', 'Array', 'isFinite', 'encodeURIComponent', 'decodeURIComponent']);
var bac = new Proxy(bouchons, {
  has: function (t, k) { return typeof k === 'string' && !BANC.has(k) && (k in t || !(k in globalThis)); },
  get: function (t, k) { if (k === Symbol.unscopables) return undefined; if (k in t) return t[k];
    if (!auto[k]) auto[k] = function () { journal.appels.push(k); return undefined; }; return auto[k]; },
  set: function (t, k, v) { t[k] = v; return true; }
});
var resultats = [];
function verifier(nom, cond, detail) { resultats.push([cond ? 'OK  ' : 'ECHEC', nom, detail || '']); }

with (bac) {
%SOURCES%
%CRON%

  var DIM = instant('2026-09-13T12:00:00+02:00'), SAM = instant('2026-09-12T12:00:00+02:00'), LUN = instant('2026-09-14T12:00:00+02:00');
  var cycleVote = function (posteId, city, debut, candidats) {
    return { posteId: posteId, city: city, phase: 'vote', tour: 1, dateDebutCandidatures: debut - 14 * 864e5, dateDebutCampagne: debut - 7 * 864e5,
      dateVote: debut, dateResultats: debut + 864e5, resultatsTraites: false, candidats: candidats.map(function (n) { return { nom: n }; }), votes: {}, votesPNJ: {} };
  };
  var monde = function (ouverture) {
    bouchons.CYCLES_ELECTORAUX = { republic: {
      maire_ville_a: cycleVote('maire', 'ville_a', ouverture, ['Cand A', 'Cand B']),
      depute_ville_a: cycleVote('depute', 'ville_a', ouverture, ['Cand A', 'Dep D']),
      president: cycleVote('president', null, ouverture, ['Pres X']),
      chef_syndicat: cycleVote('chef_syndicat', null, ouverture, ['Pres X']),
      maire_capitale: cycleVote('maire', 'capitale', ouverture + 7 * 864e5, ['Cand A'])
    } };
  };
  var joueur = function (ville, inventaire) {
    bouchons.state = { country: 'republic', currentCity: ville, char: { name: '__TEST_JSC__' }, pa: 10, pop: 30, inventory: inventaire || [],
      liquide: 500, comptesBancaires: { nationale: { solde: 500 } }, arg: 1000 };
  };
  var tract = function (cible, sens, q, extra) { var t = { type: 'tract', name: 'Tracts ' + sens + ' ' + cible, tractType: sens, cible: cible, quantite: q, legal: true }; for (var k in (extra || {})) t[k] = extra[k]; return t; };
  var libelles = function (t) { return scrutinsDistribuablesPourTract(t).map(function (s) { return s.cle; }).sort().join(','); };
  var ouvertureDim = instant('2026-09-13T00:30:00+02:00');

  var scenarios = async function () {
    // ---- Marche et ancien chemin POP ----
    var ordresMarche = [];
    Object.keys(BUILDINGS).forEach(function (b) { Object.keys(BUILDINGS[b].rooms || {}).forEach(function (r) { (BUILDINGS[b].rooms[r].orders || []).forEach(function (o) { if (o.fn === 'distribuer_tract') ordresMarche.push(b + '/' + r); }); }); });
    verifier('M1. plus aucun ordre « Distribuer un tract » au marche (donnees), ni route, ni fonction',
      ordresMarche.length === 0 && %ROUTE_ABSENTE% && %FONCTIONS_MARCHE_ABSENTES%, JSON.stringify(ordresMarche));

    raz(); joueur('capitale', [tract('Cand A', 'pour', 3)]);
    confirmerDonObjetPnj(0, encodeURIComponent(JSON.stringify({ name: 'Justin Verre (PNJ)', job: 'serveur' })));
    verifier('M2. « Donner un objet » : un tract a un PNJ ne rapporte plus de POP et n\'est pas consomme',
      bouchons.state.pop === 30 && bouchons.state.inventory[0].quantite === 3 && /Distribuer un tract/.test(journal.toasts.join()), journal.toasts.join());

    // ---- Dimanche (heure de Paris) ----
    verifier('D1. dimanche a Paris : dimanche 12h oui, samedi 23h30 UTC (= dimanche 1h30 Paris) oui, dimanche 23h30 UTC (= lundi) non, lundi non',
      estDimancheParis(new VraieDate(DIM)) && estDimancheParis(new VraieDate(instant('2026-09-12T23:30:00Z'))) && !estDimancheParis(new VraieDate(instant('2026-09-13T23:30:00Z')))
      && !estDimancheParis(new VraieDate(LUN)));

    // ---- Fenetre et geographie (affichage) ----
    monde(ouvertureDim); MAINTENANT = DIM;
    joueur('ville_a'); var tA = tract('Cand A', 'pour', 5), tD = tract('Dep D', 'pour', 5), tX = tract('Pres X', 'pour', 5);
    verifier('G1. dimanche + vote ouvert, a PSM : maire et depute de PSM proposes (candidat present aux deux : choix explicite)',
      libelles(tA) === 'depute_ville_a,maire_ville_a' && libelles(tD) === 'depute_ville_a', libelles(tA));
    joueur('capitale');
    verifier('G2. maire/depute de PSM depuis Luthecia : rien ; maire de Luthecia pas encore en vote : rien', libelles(tA) === '' && libelles(tD) === '');
    var lieux = ['capitale', 'ville_a', 'ville_b', 'caserne', 'qhs'].map(function (v) { joueur(v); return v + '=' + libelles(tX); });
    verifier('G3. presidentielle : les 3 villes, la caserne et le QHS ; jamais le chef syndical', lieux.every(function (x) { return /=president$/.test(x); }), lieux.join(' '));
    joueur('caserne'); var locCaserne = libelles(tA); joueur('qhs'); var locQhs = libelles(tD);
    verifier('G4. elections locales depuis la caserne ou le QHS : refusees', locCaserne === '' && locQhs === '');
    joueur('ville_a');
    var tPsm = tract('Cand A', 'pour', 10, { electionPosteId: 'maire', electionCity: 'ville_a' });
    verifier('G5. tract de Port-Sainte-Marie rattache a un scrutin : propose uniquement pour lui', libelles(tPsm) === 'maire_ville_a');
    MAINTENANT = SAM;
    verifier('G6. samedi, meme scrutin : aucun tract propose (bouton masque)', libelles(tA) === '' && (joueur('ville_a', [tA]), tractsElectorauxDistribuablesIci().length === 0));
    MAINTENANT = DIM; monde(instant('2026-09-13T20:00:00+02:00'));
    verifier('G7. dimanche mais vote pas encore ouvert : rien', libelles(tA) === '');
    monde(ouvertureDim);

    // ---- Distribution (RPC bouchonnee : resultat serveur impose) ----
    var essai = async function (reponse, sauvegardeOk) {
      raz(); joueur('ville_a', [tract('Cand A', 'pour', 5), tract('Cand B', 'contre', 5)]);
      bouchons._sauvegardeOk = sauvegardeOk !== false;
      bouchons._reponse = reponse;
      await distribuerTractElectoralPNJ('Justin Verre (PNJ)', encodeURIComponent(JSON.stringify({ name: 'Justin Verre (PNJ)', stats: { VOL: 18 } })));
      return window._tractsElectorauxChoix;
    };
    var choixMaireA = function (ctx) { for (var i = 0; i < ctx.entrees.length; i++) if (ctx.entrees[i].tract.cible === 'Cand A' && ctx.entrees[i].scrutin.cle === 'maire_ville_a') return i; };
    var choixB = function (ctx) { for (var i = 0; i < ctx.entrees.length; i++) if (ctx.entrees[i].tract.cible === 'Cand B') return i; };

    var ctx = await essai(function () { return { ok: true, reussi: true, effet: 1, tour: ouvertureDim, jet: 12, taux: 65 }; });
    verifier('C0. plusieurs couples (tract, scrutin) : liste de choix, rien n\'est encore envoye', ctx.entrees.length === 3 && journal.rpc.length === 0, 'entrees=' + ctx.entrees.length);
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    var r0 = journal.rpc[0], lotA = bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0];
    verifier('C1. POUR reussi : 1 tract consomme, charge exacte (scrutin, candidat, sens, PNJ, VOL du PNJ), +1 dans le decompte local',
      lotA.quantite === 4 && r0.cycleId === 'republic_maire_ville_a' && r0.candidat === 'Cand A' && r0.sens === 'pour' && r0.pnj === 'Justin Verre (PNJ)' && r0.vol === 18
      && journal.sauvegardes === 1 && calculerSondageElectoral(CYCLES_ELECTORAUX.republic.maire_ville_a).some(function (x) { return x.nom === 'Cand A' && x.voix === 1; })
      && journal.appels.indexOf('carriere:politique:true') >= 0 && journal.pop.length === 0,
      JSON.stringify(r0) + ' reste=' + lotA.quantite);

    ctx = await essai(function () { return { ok: true, reussi: false, jet: 90, taux: 65 }; });
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    var q1 = bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite;
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    var q2 = bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite;
    verifier('C2. echec : 1 tract consomme, aucune voix ; nouvelle tentative immediate possible (1 tract de plus)',
      q1 === 4 && q2 === 3 && journal.rpc.length === 2 && /Sans effet/.test(journal.toasts.join()), 'q1=' + q1 + ' q2=' + q2);

    ctx = await essai(function () { return { ok: false, raison: 'pas_dimanche' }; });
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C3. refus serveur (pas dimanche) : aucun tract consomme, motif affiche',
      bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite === 5 && /dimanche/.test(journal.toasts.join()), journal.toasts.join());
    ctx = await essai(function () { return { ok: false, raison: 'deja_vote' }; });
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C4. PNJ ayant deja participe : refus sans consommation', bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite === 5 && /déjà participé/.test(journal.toasts.join()));

    ctx = await essai(function () { return null; });
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C5. reseau indisponible : une relance avec le MEME id, aucun tract consomme',
      journal.rpc.length === 2 && journal.rpc[0].rq === journal.rpc[1].rq && bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite === 5);
    ctx = await essai(function () { return { ok: true, reussi: true, effet: 1, tour: ouvertureDim }; }, false);
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C6. position non enregistrable : rien n\'est envoye ni consomme', journal.rpc.length === 0 && bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite === 5);

    // CONTRE : Cand B a 1 voix de PJ -> 0 ; puis reste 0
    monde(ouvertureDim); CYCLES_ELECTORAUX.republic.maire_ville_a.votes = { 'Un PJ': 'Cand B' };
    ctx = await essai(function () { return { ok: true, reussi: true, effet: -1, tour: ouvertureDim }; });
    await confirmerDistribuerTractElectoral(choixB(ctx));
    var sc1 = calculerScoresBaseCycle(CYCLES_ELECTORAUX.republic.maire_ville_a, []).scores['Cand B'];
    ctx = await essai(function () { return { ok: true, reussi: true, effet: 0, tour: ouvertureDim }; });
    await confirmerDistribuerTractElectoral(choixB(ctx));
    var sc2 = calculerScoresBaseCycle(CYCLES_ELECTORAUX.republic.maire_ville_a, []).scores['Cand B'];
    verifier('C7. CONTRE : 1 -> 0 (-1 voix), puis 0 -> reste 0 ; lot CONTRE consomme a chaque tentative',
      sc1 === 0 && sc2 === 0 && journal.rpc[0].sens === 'contre' && /plus de voix à perdre/.test(journal.toasts.join()), 'scores=' + sc1 + '/' + sc2);

    // ---- 1 PA par tentative individuelle ----
    ctx = await essai(function () { return { ok: true, reussi: true, effet: 1, tour: ouvertureDim, pa: 1 }; });
    var paAvant = bouchons.state.pa;
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C8. tentative reussie : 1 PA consomme en plus du tract', bouchons.state.pa === paAvant - 1, 'pa ' + paAvant + ' -> ' + bouchons.state.pa);
    ctx = await essai(function () { return { ok: true, reussi: false, jet: 99, taux: 60, pa: 1 }; });
    paAvant = bouchons.state.pa;
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C9. tentative ratee : 1 PA consomme aussi', bouchons.state.pa === paAvant - 1);
    ctx = await essai(function () { return { ok: true, reussi: true, effet: 1, tour: ouvertureDim }; });
    bouchons.state.pa = 0;
    await confirmerDistribuerTractElectoral(choixMaireA(ctx));
    verifier('C10. 0 PA : refus avant tout envoi, aucun tract consomme',
      journal.rpc.length === 0 && bouchons.state.inventory.filter(function (i) { return i.cible === 'Cand A'; })[0].quantite === 5 && /1 PA/.test(journal.toasts.join()), journal.toasts.join());

    // ---- Decomptes : plancher, tour, blob, copie cron ----
    var cy = cycleVote('maire', 'ville_a', ouvertureDim, ['A', 'B']);
    cy.votes = { p1: 'A', p2: 'A' }; attacherEffetsTracts(cy, { tour: ouvertureDim, parCandidat: { A: -5, B: 3 } });
    var sClient = calculerScoresBaseCycle(cy, []).scores, sCron = calculerScoresBaseCycleCron(cy, []).scores;
    verifier('S1. decompte client ET cron : effets appliques, jamais negatif (2 - 5 -> 0 ; 0 + 3 -> 3)',
      sClient.A === 0 && sClient.B === 3 && sCron.A === 0 && sCron.B === 3, JSON.stringify(sClient) + ' / ' + JSON.stringify(sCron));
    cy.dateVote = ouvertureDim + 3600000;
    verifier('S2. second tour (autre dateVote) : les effets du premier tour ne comptent plus', calculerScoresBaseCycle(cy, []).scores.B === 0 && calculerScoresBaseCycleCron(cy, []).scores.B === 0);
    verifier('S3. les effets ne sont jamais ecrits dans le blob du cycle (propriete non enumerable)', JSON.stringify(cy).indexOf('_effetsTracts') < 0 && Object.keys(cy).indexOf('_effetsTracts') < 0);
    monde(ouvertureDim);
    bouchons._lignesEffets = [
      { cycle_id: 'republic_maire_ville_a', tour: ouvertureDim, candidat: 'Cand A', effet: 1 },
      { cycle_id: 'republic_maire_ville_a', tour: ouvertureDim, candidat: 'Cand A', effet: 1 },
      { cycle_id: 'republic_maire_ville_a', tour: ouvertureDim - 864e5, candidat: 'Cand A', effet: 1 },
      { cycle_id: 'republic_depute_ville_a', tour: ouvertureDim, candidat: 'Dep D', effet: -1 }];
    await chargerEffetsTractsPNJ('republic');
    verifier('S4. chargement : effets agreges par scrutin et par tour courant uniquement',
      CYCLES_ELECTORAUX.republic.maire_ville_a._effetsTracts.parCandidat['Cand A'] === 2 && CYCLES_ELECTORAUX.republic.depute_ville_a._effetsTracts.parCandidat['Dep D'] === -1,
      JSON.stringify(CYCLES_ELECTORAUX.republic.maire_ville_a._effetsTracts));

    verifier('F. aucun jet cote client dans la distribution electorale : le taux et le jet viennent du serveur', %AUCUN_JET_CLIENT%);

    // ===== Calendrier du dimanche (12 septembre 2026) =====
    var parisTxt = function (ts) { return new Intl.DateTimeFormat('fr-FR', { timeZone: 'Europe/Paris', weekday: 'short', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new VraieDate(ts)); };
    var estDimanche0001 = function (ts) { var p = partiesHeureParis(ts); return new VraieDate(VraieDate.UTC(p.a, p.m - 1, p.j)).getUTCDay() === 0 && p.h === 0 && p.mi === 1; };
    var estLundi0000 = function (ts) { var p = partiesHeureParis(ts); return new VraieDate(VraieDate.UTC(p.a, p.m - 1, p.j)).getUTCDay() === 1 && p.h === 0 && p.mi === 0; };

    var finElection = instant('2026-09-14T00:00:00+02:00');        // lundi 00:00, election precedente terminee
    var cal1 = calendrierPremierTour(finElection);
    verifier('K1. election terminee le lundi 00:00 : candidatures jusqu\'au lundi suivant 00:01, vote le 2e dimanche',
      parisTxt(cal1.dateDebutCampagne) === parisTxt(instant('2026-09-21T00:01:00+02:00'))
      && parisTxt(cal1.dateVote) === parisTxt(instant('2026-09-27T00:01:00+02:00'))
      && parisTxt(cal1.dateResultats) === parisTxt(instant('2026-09-28T00:00:00+02:00')),
      parisTxt(cal1.dateDebutCampagne) + ' | ' + parisTxt(cal1.dateVote) + ' | ' + parisTxt(cal1.dateResultats));
    var cal2 = calendrierPremierTour(instant('2026-09-14T01:00:00+02:00'));   // cron du lundi
    verifier('K2. cycle ouvert par le cron du lundi 01:00 : meme calendrier', cal2.dateVote === cal1.dateVote && cal2.dateDebutCampagne === cal1.dateDebutCampagne);
    var cal3 = calendrierPremierTour(instant('2026-09-16T12:00:00+02:00'));   // mercredi : moins de 6 jours avant le lundi
    verifier('K3. cycle ouvert un mercredi : cloture repoussee d\'une semaine (jamais moins de 6 jours de candidatures)',
      parisTxt(cal3.dateDebutCampagne) === parisTxt(instant('2026-09-28T00:01:00+02:00')) && parisTxt(cal3.dateVote) === parisTxt(instant('2026-10-04T00:01:00+02:00')),
      parisTxt(cal3.dateDebutCampagne) + ' | ' + parisTxt(cal3.dateVote));
    var cal4 = calendrierTourSuivant(cal1.dateVote);
    verifier('K4. second tour : le dimanche suivant, resultat au lundi', parisTxt(cal4.dateVote) === parisTxt(instant('2026-10-04T00:01:00+02:00')) && parisTxt(cal4.dateResultats) === parisTxt(instant('2026-10-05T00:00:00+02:00')),
      parisTxt(cal4.dateVote) + ' | ' + parisTxt(cal4.dateResultats));
    var tousDimanches = [finElection, instant('2026-10-19T01:00:00+02:00'), instant('2026-10-25T23:30:00+01:00'), instant('2026-12-31T12:00:00+01:00'), instant('2027-03-28T05:00:00+02:00')]
      .map(function (t) { var c = calendrierPremierTour(t); return estDimanche0001(c.dateVote) && estLundi0000(c.dateResultats) && estLundi0000(c.dateDebutCampagne - 60000); });
    verifier('K5. tout cycle, y compris aux changements d\'heure : vote dimanche 00:01, cloture lundi 00:01, resultat lundi 00:00', tousDimanches.every(Boolean), tousDimanches.join(','));
    verifier('K6. decalage d\'une semaine (report d\'election) : reste un dimanche 00:01 malgre le changement d\'heure',
      estDimanche0001(decalerSemainesParis(instant('2026-10-25T00:01:00+02:00'), 1)) && parisTxt(decalerSemainesParis(instant('2026-10-25T00:01:00+02:00'), 1)) === parisTxt(instant('2026-11-01T00:01:00+01:00')));
    verifier('K7. fin de mandat (5 semaines) alignee sur le passage au lundi 00:00', estLundi0000(lundiMinuitParisApresSemaines(instant('2026-09-14T01:00:00+02:00'), 5))
      && parisTxt(lundiMinuitParisApresSemaines(instant('2026-09-14T01:00:00+02:00'), 5)) === parisTxt(instant('2026-10-19T00:00:00+02:00')));
    var neuf = construireNouveauCycleElectoral('maire', 'ville_a', finElection), neufCron = construireNouveauCycleElectoralCron('maire', 'ville_a', finElection);
    verifier('K8. nouveau cycle (client ET cron) : candidatures ouvertes, memes dates du dimanche',
      neuf.phase === 'candidatures' && neuf.candidats.length === 0 && neuf.dateVote === cal1.dateVote
      && neufCron.dateVote === cal1.dateVote && neufCron.dateDebutCampagne === cal1.dateDebutCampagne && neufCron.dateResultats === cal1.dateResultats);

    // Candidatures : ouvertes jusqu'a la cloture seulement
    MAINTENANT = instant('2026-09-15T12:00:00+02:00');
    verifier('K9. candidatures ouvertes pendant la premiere semaine, closes des le lundi 00:01',
      candidaturesOuvertes(neuf, MAINTENANT) === true
      && candidaturesOuvertes(neuf, instant('2026-09-21T00:00:00+02:00')) === true
      && candidaturesOuvertes(neuf, instant('2026-09-21T00:02:00+02:00')) === false
      && candidaturesOuvertes(neuf, instant('2026-09-27T12:00:00+02:00')) === false);
    verifier('K10. candidatures fermees en mandat, en vacance et apres depouillement',
      candidaturesOuvertes(Object.assign({}, neuf, { phase: 'mandat' }), MAINTENANT) === false
      && candidaturesOuvertes(Object.assign({}, neuf, { phase: 'vacant' }), MAINTENANT) === false
      && candidaturesOuvertes(Object.assign({}, neuf, { resultatsTraites: true }), MAINTENANT) === false);

    // Phases sur un cycle aligne
    var cycleAligne = Object.assign({}, neuf, { candidats: [{ nom: 'A' }] });
    bouchons.CYCLES_ELECTORAUX = { republic: { maire_ville_a: cycleAligne } };
    var phaseA = function (ts) { MAINTENANT = ts; return getPhaseActuelle('republic', 'maire', 'ville_a'); };
    verifier('K11. phases : campagne avant dimanche, vote du dimanche 00:01 a 23:59, depouillement au passage au lundi',
      phaseA(instant('2026-09-26T23:00:00+02:00')) === 'campagne' && phaseA(instant('2026-09-27T00:00:00+02:00')) === 'campagne'
      && phaseA(instant('2026-09-27T00:01:00+02:00')) === 'vote' && phaseA(instant('2026-09-27T23:59:00+02:00')) === 'vote'
      && phaseA(instant('2026-09-28T00:00:00+02:00')) === 'vacant',
      phaseA(instant('2026-09-27T00:01:00+02:00')) + '/' + phaseA(instant('2026-09-28T00:00:00+02:00')));

    // Tracts : fenetre reelle du dimanche
    MAINTENANT = instant('2026-09-27T12:00:00+02:00');
    joueur('ville_a');
    verifier('K12. tracts : utilisables le dimanche du scrutin, pas la veille ni le lundi',
      scrutinsDistribuablesPourTract(tract('A', 'pour', 3)).length === 1
      && (MAINTENANT = instant('2026-09-26T12:00:00+02:00'), scrutinsDistribuablesPourTract(tract('A', 'pour', 3)).length === 0)
      && (MAINTENANT = instant('2026-09-28T00:30:00+02:00'), scrutinsDistribuablesPourTract(tract('A', 'pour', 3)).length === 0));

    // Legislatives : un seul tour, top 3, departage
    var cyDep = { posteId: 'depute', city: 'ville_a', dateVote: cal1.dateVote, candidats: [
      { nom: 'Ana', dateInscription: 300 }, { nom: 'Bob', dateInscription: 100 }, { nom: 'Cid', dateInscription: 200 }, { nom: 'Dan', dateInscription: 50 }],
      votes: { p1: 'Ana', p2: 'Ana', p3: 'Bob', p4: 'Cid', p5: 'Dan' }, votesPNJ: {} };
    var rDep = resoudreScrutinDepute(cyDep, []), rDepCron = resoudreScrutinDeputeCron(cyDep, []);
    verifier('K13. legislatives : un seul tour, 3 elus, egalite departagee par anciennete (jamais de second tour partiel)',
      rDep.egalite3eSiege === null && rDep.elus.join(',') === 'Ana,Dan,Bob' && rDepCron.elus.join(',') === rDep.elus.join(','),
      rDep.elus.join(',') + ' | cron ' + rDepCron.elus.join(','));

    // ===== Port-Sainte-Marie : tracts electoraux payants =====
    var psm = function () { return ETATS['republic/ville_a/imprimerie-librairie'].imprimerie; };
    var ordrePsm = BUILDINGS['imprimerie-librairie'].rooms.accueil_imprimerie.orders.filter(function (o) { return o.fn === 'imprimer_tracts_electoraux'; })[0];
    var joueurPsm = function (liquide, banque) {
      bouchons.state = { country: 'republic', currentCity: 'ville_a', currentBuilding: 'imprimerie-librairie', currentRoom: 'accueil_imprimerie',
        char: { name: '__TEST_JSC__' }, pa: 10, liquide: liquide, comptesBancaires: { nationale: { solde: banque } }, arg: liquide + banque,
        inventory: [{ stackable: true, stackKey: 'bois', qty: 5, name: 'Bois' }] };
      ETATS = { 'republic/ville_a/imprimerie-librairie': { imprimerie: { caisse: 200 } } };
      bouchons.window._candidatsElectorauxActifs = [{ nom: 'A', posteId: 'maire', city: 'ville_a' }];
      journal.saisies = { 'tract-electoral-cible': '0', 'tract-quantite': '10' };
      bouchons.window._tractType = 'pour';
    };
    raz(); joueurPsm(700, 300); var avantPsm = 1000 + psm().caisse;
    await confirmerImprimerTractsElectoraux(ordrePsm.pa, ordrePsm.cost);
    var lotPsm = bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; })[0];
    verifier('P1. Port-Sainte-Marie : 10 tracts = 150 FR (liquide), 1 PA, 1 bois, caisse Gutenberg +150, acquisition immediate, aucune creation',
      ordrePsm.cost === 150 && bouchons.state.liquide === 550 && bouchons.state.comptesBancaires.nationale.solde === 300 && bouchons.state.pa === 9
      && bouchons.state.inventory[0].qty === 4 && psm().caisse === 350 && lotPsm && lotPsm.quantite === 10 && lotPsm.tractType === 'pour'
      && bouchons.state.liquide + bouchons.state.comptesBancaires.nationale.solde + psm().caisse === avantPsm,
      'liquide=' + bouchons.state.liquide + ' caisse=' + psm().caisse + ' tracts=' + (lotPsm && lotPsm.quantite)
      + ' pa=' + bouchons.state.pa + ' bois=' + JSON.stringify(bouchons.state.inventory[0]) + ' sens=' + (lotPsm && lotPsm.tractType) + ' cost=' + ordrePsm.cost);
    raz(); joueurPsm(100, 300);
    await confirmerImprimerTractsElectoraux(ordrePsm.pa, ordrePsm.cost);
    verifier('P2. Port-Sainte-Marie : liquide 100 + banque 300 -> liquide 0, banque 250, caisse +150',
      bouchons.state.liquide === 0 && bouchons.state.comptesBancaires.nationale.solde === 250 && psm().caisse === 350);
    raz(); joueurPsm(80, 20);
    await confirmerImprimerTractsElectoraux(ordrePsm.pa, ordrePsm.cost);
    verifier('P3. Port-Sainte-Marie : fonds insuffisants -> refus avant production (ni PA, ni bois, ni tract, ni caisse)',
      /Fonds insuffisants/.test(journal.toasts.join()) && bouchons.state.pa === 10 && bouchons.state.inventory[0].qty === 5
      && psm().caisse === 200 && !bouchons.state.inventory.some(function (i) { return i.type === 'tract'; }), journal.toasts.join());
    verifier('P4. tarif unique de Republia : meme point d\'accroche pour les trois ateliers', prixLotTractsAtelier() === 150 && PRIX_LOT_TRACTS === 150);

  };
}

scenarios().then(function () {
  resultats.forEach(function (r) { print(r[0] + ' ' + r[1] + '   [' + r[2] + ']'); });
  print(''); print(resultats.length + ' test(s), ' + resultats.filter(function (r) { return r[0] !== 'OK  '; }).length + ' echec(s)');
}).catch(function (e) { print('ERREUR ' + e + '\n' + (e.stack || '')); });
"""
route_absente = 'true' if "fn === 'distribuer_tract'" not in R else 'false'
tous = ''.join(lire(f) for f in sorted(os.listdir(RACINE)) if f.startswith('plateau') and f.endswith('.js'))
fonctions_absentes = 'true' if not re.search(r'function (doDistribuerTract|confirmerDistribuerTract)\(', tous) else 'false'
corps = extraire(C, 'confirmerDistribuerTractElectoral') + extraire(C, 'distribuerTractElectoralPNJ')
aucun_jet = 'true' if 'Math.random() * 100' not in corps and 'bonusInf' not in corps else 'false'
js = banc.replace('%DATA%', lire('data.js')).replace('%SOURCES%', SOURCES).replace('%CRON%', CRON_SCORES).replace('%ROUTE_ABSENTE%', route_absente).replace('%FONCTIONS_MARCHE_ABSENTES%', fonctions_absentes).replace('%AUCUN_JET_CLIENT%', aucun_jet)
with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
    fh.write(js)
out = subprocess.run([JSC, fh.name], capture_output=True, text=True, timeout=120)
print(out.stdout + out.stderr)
sys.exit(0 if ' 0 echec(s)' in out.stdout else 1)
