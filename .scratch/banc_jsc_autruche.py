#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Banc d'execution REEL -- L'Autruche Entravee (La Tribune de Luthecia), chantier du 11 septembre 2026.

Charge le VRAI data.js complet (WORLD, BUILDINGS, buildingContext des 15 journaux) puis execute dans
JavaScriptCore les VRAIES fonctions : doOrder (routeur), getBuildingContext, deduireCoutOrdre,
debiterFondsOrdinaires, crediterFondsOrdinaires, getFondsDisponiblesOrdinaires, les handlers des
tracts, du choix unique, de la vente de matieres premieres et de « Se renseigner ». Base de donnees
bouchonnee (batiments_etat en memoire) : aucune ecriture reelle.

Usage : python3 .scratch/banc_jsc_autruche.py
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


R, J, C, Q, K, N = (lire(f) for f in ('plateau-router.js', 'plateau-justice-economie.js', 'plateau-communication.js',
                                      'plateau-organisations-quetes.js', 'plateau-core.js', 'plateau-navigation.js'))
SOURCES = ''.join(en_expression(x) for x in [
    extraire(R, 'doOrder'), extraire(R, 'executerOrdreGenerique'), extraire(R, 'applyEffects'),
    extraire(R, 'buildResultLabel'), extraire(R, 'buildResultMsg'), extraire(N, 'getBuildingContext'),
    extraire(K, 'deduireCoutOrdre'), extraire(K, 'debiterFondsOrdinaires'), extraire(K, 'crediterFondsOrdinaires'),
    extraire(K, 'getFondsDisponiblesOrdinaires'),
    extraire(J, 'ouvrirVendreBoisImprimerie'), extraire(J, 'confirmerVendreBoisImprimerie'), extraire(J, 'ENTREPOT_PAR_VILLE', 'const'),
    extraire(J, 'imprimerieCouranteVente'), extraire(J, 'prixAchatBoisImprimerie'),
    extraire(C, 'nomImprimeurLocal'), extraire(C, 'ouvrirChoixImprimerTracts'), extraire(C, 'choisirTypeImprimerTracts'),
    extraire(C, 'selectTractType'), extraire(C, 'ouvrirModalImprimerTractsElectoraux'), extraire(C, 'confirmerImprimerTractsElectoraux'),
    extraire(C, 'BOIS_PAR_LOT_TRACTS', 'const'), extraire(C, 'STOCK_BOIS_MAX_IMPRIMERIE_PNJ', 'const'),
    extraire(C, 'QUANTITES_LOTS_TRACTS', 'const'), extraire(C, 'atelierImprimerieCourant'),
    extraire(C, 'stockBoisAtelier'), extraire(C, 'mouvementBoisAtelier'), extraire(C, 'messageStockBoisInsuffisant'),
    extraire(J, 'plafondBoisImprimerie'),
    extraire(C, 'ouvrirModalImprimerTractsCalomnieux'), extraire(C, 'confirmerImprimerTractsCalomnieux'),
    extraire(Q, 'doSeRenseigner'),
    extraire(C, 'PRIX_LOT_TRACTS', 'const'), extraire(C, 'prixLotTractsAtelier'), extraire(C, 'prixLotTractsCalomnieux'),
    extraire(C, 'confirmerDonTracts'), extraire(C, 'distribuerTractElectoralPNJ'), extraire(C, 'confirmerDistribuerTractElectoral'),
    extraire(C, 'volontePnjElectorale'), extraire(C, 'MOTIFS_REFUS_TRACT_CALOMNIEUX', 'const'),
    extraire(C, 'distribuerTractCalomnieuxPNJ'), extraire(C, 'confirmerDistribuerTractCalomnieux'),
    extraire(N, 'doPasserDouanesAeroport'),
    extraire(J, 'crediterCaisseEtatBatiment'), extraire(C, 'ATELIERS_TRACTS_CALOMNIEUX', 'const'),
    extraire(C, 'lotsTractsDonnables'), extraire(C, 'donnerTracts'), extraire(C, 'recevoirLotTracts'), extraire(C, 'verifierObjetsRecus'),
    extraire(lire('supabase.js'), 'ressourcesAvecBasePop'), extraire(lire('supabase.js'), 'reporterDeltaPopNonEcrit'), extraire(lire('supabase.js'), 'sbSavePersonnage'),
]).replace('const ', 'var ')

banc = r"""
var window = this, document = {}, localStorage = { getItem: function () { return null; }, setItem: function () {} };
%DATA%
var DONNEES = { WORLD: WORLD, BUILDINGS: BUILDINGS, COUNTRIES: COUNTRIES, ORDER_EFFECTS: ORDER_EFFECTS };

var journal;
function raz() { journal = { appels: [], toasts: [], sauvegardes: [], saisies: {}, modals: [] }; }
var ETATS = {};
var bouchons = {
  state: null, TEST_MODE: false, ORDRES_BUDGET_INSTITUTION: [], ACTES_ILLEGAUX: { imprimer_tracts_calomnieux: { type: 'delit_mineur', detectRate: 30 } },
  WORLD: DONNEES.WORLD, BUILDINGS: DONNEES.BUILDINGS, COUNTRIES: DONNEES.COUNTRIES, ORDER_EFFECTS: DONNEES.ORDER_EFFECTS,
  verdictRoleOrdre: function () { return { bloque: false }; },
  showToast: function (t, m) { journal.toasts.push(t + ' | ' + (m || '')); },
  addJournalEntry: function (t) { journal.appels.push('journal:' + t); }, updateUI: function () {}, advanceTime: function () {},
  checkDetection: function (fn) { journal.appels.push('checkDetection:' + fn); },
  signalerRefusCout: function (r) { journal.toasts.push('refus:' + r.raison); },
  sauvegarderPersonnageImmediat: function () { journal.appels.push('sauvegardePJ'); },
  getPrixRessourceEntrepot: function () { return 5; }, getPrixRessource: function () { return 5; },
  sbGetBatimentEtat: function (p, v, b) { return Promise.resolve(JSON.parse(JSON.stringify(ETATS[p + '/' + v + '/' + b] || {}))); },
  sbSetBatimentEtat: function (p, v, b, e) { ETATS[p + '/' + v + '/' + b] = JSON.parse(JSON.stringify(e)); journal.sauvegardes.push(b); return Promise.resolve(); },
  // Meme semantique que la RPC batiment_caisse_mouvement (tout-ou-rien, jamais de solde negatif).
  sbBatimentMouvementCaisse: function (p, v, b, sc, delta, stockCle, stock, stockMax) {
    var cle = p + '/' + v + '/' + b;
    if (!ETATS[cle]) ETATS[cle] = {};
    var o = ETATS[cle][sc] || (ETATS[cle][sc] = {});
    var caisse = o.caisse || 0;
    if (caisse + delta < 0) return Promise.resolve({ ok: false, raison: 'caisse_insuffisante', caisse: caisse });
    if (stockCle && stock) {
      var st = o[stockCle] || 0;
      if (st + stock < 0) return Promise.resolve({ ok: false, raison: 'stock_insuffisant', stock: st, caisse: caisse });
      if (typeof stockMax === 'number' && stockMax !== null && st + stock > stockMax) {
        return Promise.resolve({ ok: false, raison: 'stock_plafond', stock: st, stock_max: stockMax, caisse: caisse });
      }
      o[stockCle] = st + stock;
    }
    o.caisse = caisse + delta;
    journal.sauvegardes.push(b);
    return Promise.resolve({ ok: true, caisse: o.caisse });
  },
  listerCandidatsElectorauxActifs: function () { return [{ nom: 'Cible', posteId: 'maire', city: 'capitale' }]; },
  sbListPersonnages: function () { return Promise.resolve([{ name: 'Cible', country: 'republic' }, { name: '__TEST_JSC__', country: 'republic' }]); },
  document: { getElementById: function (id) { return {
    value: journal.saisies[id], classList: { add: function () { if (id === 'modal-postes') journal.modals.push(journal.titre); }, remove: function () {} },
    set textContent(v) { if (id === 'postes-modal-title') journal.titre = v; }, get textContent() { return ''; },
    set innerHTML(v) { if (id === 'postes-body') journal.corps = v; }, get innerHTML() { return ''; } }; } }
};
bouchons.window = bouchons;
var auto = {};
var BANC = new Set(['journal', 'raz', 'ETATS', 'bouchons', 'auto', 'bac', 'BANC', 'resultats', 'verifier', 'Math', 'DONNEES', 'JSON', 'Promise', 'Object', 'String', 'Set', 'setTimeout']);
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

  var joueur = function (o) {
    o = o || {};
    bouchons.state = { country: o.pays || 'republic', currentCity: o.ville || 'capitale', currentBuilding: 'la-tribune', currentRoom: 'accueil_tribune',
      char: { name: '__TEST_JSC__' }, pa: 10, liquide: o.liquide !== undefined ? o.liquide : 700, comptesBancaires: { nationale: { solde: o.banque !== undefined ? o.banque : 300 } },
      inventory: [{ stackable: true, stackKey: 'bois', qty: 30, name: 'Bois' }], contacts: [{ name: 'Cible' }], day: 5, hour: 12 };
    bouchons.state.arg = bouchons.state.liquide + bouchons.state.comptesBancaires.nationale.solde;
  };
  var fonds = function () { return bouchons.state.liquide + bouchons.state.comptesBancaires.nationale.solde; };
  var imp = function (p, v) { return ETATS[(p || 'republic') + '/' + (v || 'capitale') + '/la-tribune'].imprimerie; };
  var atelier = function (caisse, bois, p, v) { ETATS = {}; ETATS[(p || 'republic') + '/' + (v || 'capitale') + '/la-tribune'] = { imprimerie: { caisse: caisse, stockBois: bois } };
    ETATS['republic/capitale/entrepot-logistique-luthecia'] = { entrepot: { stock: { bois: 750 } } }; };
  var tick = function () { return new Promise(function (r) { setTimeout(r, 0); }); };
  var ordresPiece = function (p, v) {   // meme fusion que renderRoomActions (plateau-politique.js)
    var b = BUILDINGS['la-tribune'], ctx = WORLD[p][v].buildingContext && WORLD[p][v].buildingContext['la-tribune'];
    var ov = ctx && ctx.roomOverrides && ctx.roomOverrides.accueil_tribune || {};
    var excl = ov.excludeOrders || [];
    return [].concat(b.rooms.accueil_tribune.orders, (ctx && ctx.orders) || [], ov.orders || []).filter(function (o) { return excl.indexOf(o.fn) < 0; });
  };
  var tractsDef = BUILDINGS['la-tribune'].rooms.accueil_tribune.orders.filter(function (o) { return o.fn === 'imprimer_tracts_electoraux'; })[0];
  var imprimer = async function (sens, quantite, pa, cost) {   // meme chemin que le vrai bouton
    bouchons.window._candidatsElectorauxActifs = listerCandidatsElectorauxActifs();
    bouchons.window._tractType = sens;
    journal.saisies['tract-electoral-cible'] = '0';
    journal.saisies['tract-quantite'] = String(quantite);
    await confirmerImprimerTractsElectoraux(pa === undefined ? tractsDef.pa : pa, cost === undefined ? tractsDef.cost : cost);
  };
  var vente = BUILDINGS['la-tribune'].rooms.accueil_tribune.orders.filter(function (o) { return o.fn === 'vendre_bois_imprimerie'; })[0];

  var scenarios = async function () {
    // ===== 1. Paiement des tracts electoraux et matiere premiere institutionnelle =====
    raz(); joueur({ liquide: 700, banque: 300 }); atelier(0, 5);
    var avant = fonds() + imp().caisse;
    var boisPerso = function () { var l = bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0]; return l ? l.qty : 0; };
    await imprimer('contre', 10);
    var t = bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; })[0];
    verifier('P1. stock suffisant : -150 liquide, banque intacte, 1 PA, caisse +150, 1 bois DE L\'IMPRIMERIE, 10 tracts CONTRE',
      bouchons.state.liquide === 550 && bouchons.state.comptesBancaires.nationale.solde === 300 && bouchons.state.pa === 9
      && imp().caisse === 150 && imp().stockBois === 4 && t && t.quantite === 10 && t.tractType === 'contre',
      'liquide=' + bouchons.state.liquide + ' pa=' + bouchons.state.pa + ' caisse=' + imp().caisse + ' stockAtelier=' + imp().stockBois);
    verifier('P1 bis. le bois PERSONNEL du joueur n\'est jamais consomme', boisPerso() === 30, 'bois perso=' + boisPerso());
    verifier('P4. aucune creation monetaire (fonds joueur + caisse constants)', fonds() + imp().caisse === avant, 'avant=' + avant + ' apres=' + (fonds() + imp().caisse));

    raz(); joueur({ liquide: 100, banque: 300 }); atelier(0, 5); avant = fonds() + imp().caisse;
    await imprimer('pour', 10);
    verifier('P2. liquide 100 + banque 300 : liquide -> 0, banque -50, caisse +150, sans creation',
      bouchons.state.liquide === 0 && bouchons.state.comptesBancaires.nationale.solde === 250 && imp().caisse === 150 && fonds() + imp().caisse === avant,
      'liquide=' + bouchons.state.liquide + ' banque=' + bouchons.state.comptesBancaires.nationale.solde + ' caisse=' + imp().caisse);

    raz(); joueur({ liquide: 60, banque: 50 }); bouchons.state.arg = 5000;   // arg desynchronise : ne doit rien payer
    atelier(0, 5);
    await imprimer('pour', 10);
    verifier('P3. fonds reels insuffisants (110 < 150, meme avec arg=5000) : refus, et le bois reserve est rendu',
      /Fonds insuffisants/.test(journal.toasts.join()) && bouchons.state.pa === 10 && bouchons.state.liquide === 60
      && imp().caisse === 0 && imp().stockBois === 5 && !bouchons.state.inventory.some(function (i) { return i.type === 'tract'; }),
      journal.toasts.join(' / ') + ' stockAtelier=' + imp().stockBois);

    raz(); joueur({ liquide: 400, banque: 0 }); atelier(0, 5); avant = fonds() + imp().caisse;
    await imprimer('pour', 20);
    verifier('P5. 20 tracts = 2 lots : 300 FR et 2 bois de l\'imprimerie, 1 seul PA, caisse = montant debite',
      imp().caisse === 300 && bouchons.state.liquide === 100 && fonds() + imp().caisse === avant && bouchons.state.pa === 9
      && imp().stockBois === 3 && bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; })[0].quantite === 20,
      'caisse=' + imp().caisse + ' stockAtelier=' + imp().stockBois + ' pa=' + bouchons.state.pa);

    raz(); joueur({ liquide: 700, banque: 300 }); atelier(0, 0); avant = fonds() + imp().caisse;
    await imprimer('pour', 10);
    verifier('P6. imprimerie sans bois : refus propre AVANT tout debit (aucun PA, aucun FR, aucun tract)',
      /Stock de bois insuffisant/.test(journal.toasts.join()) && bouchons.state.pa === 10 && bouchons.state.liquide === 700
      && imp().caisse === 0 && !bouchons.state.inventory.some(function (i) { return i.type === 'tract'; }) && fonds() + imp().caisse === avant,
      journal.toasts.join(' / '));

    raz(); joueur({ liquide: 5000, banque: 0 }); atelier(0, 1);
    await imprimer('pour', 20);
    verifier('P7. stock insuffisant pour la quantite demandee (2 lots pour 1 bois) : refus total',
      /Stock de bois insuffisant/.test(journal.toasts.join()) && bouchons.state.pa === 10 && imp().stockBois === 1
      && !bouchons.state.inventory.some(function (i) { return i.type === 'tract'; }), journal.toasts.join(' / '));

    raz(); joueur({ liquide: 5000, banque: 0 }); atelier(0, 1);
    await Promise.all([imprimer('pour', 10), imprimer('pour', 10)]);
    var lotsDouble = bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; }).reduce(function (s, i) { return s + i.quantite; }, 0);
    verifier('P8. double clic sur 1 seul bois : un seul lot produit, stock a 0, jamais negatif',
      lotsDouble === 10 && imp().stockBois === 0 && imp().caisse === 150,
      'tracts=' + lotsDouble + ' stock=' + imp().stockBois + ' caisse=' + imp().caisse);

    // ===== 2. Vente de matieres premieres : prix, caisse et PLAFOND DE STOCK =====
    raz(); joueur({ liquide: 700, banque: 300 }); atelier(200, 0); avant = fonds() + imp().caisse;
    await (async function () { doOrder(vente.fn, vente.pa, vente.cost, vente.label, vente.desc, vente.successRate); await tick(); })();
    journal.saisies['vendre-bois-qte'] = '10';
    await confirmerVendreBoisImprimerie(vente.pa, vente.cost);
    verifier('V1. vente de 10 bois : caisse -55 (5,50/unite), liquide +55 (fonds depensables), stock a 10, 0 PA',
      imp().caisse === 145 && bouchons.state.liquide === 755 && bouchons.state.comptesBancaires.nationale.solde === 300
      && fonds() + imp().caisse === avant && bouchons.state.pa === 10 && imp().stockBois === 10,
      'caisse=' + imp().caisse + ' liquide=' + bouchons.state.liquide + ' stock=' + imp().stockBois);

    raz(); joueur(); atelier(5, 0); journal.saisies['vendre-bois-qte'] = '10';
    await confirmerVendreBoisImprimerie(vente.pa, vente.cost);
    verifier('V2. caisse insuffisante (5 < 5,5) : refus, aucun mouvement',
      /Caisse vide/.test(journal.toasts.join()) && imp().caisse === 5 && bouchons.state.liquide === 700 && imp().stockBois === 0
      && bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty === 30, journal.toasts.join(' / '));

    raz(); joueur(); atelier(20, 0); avant = fonds() + imp().caisse; journal.saisies['vendre-bois-qte'] = '10';
    await confirmerVendreBoisImprimerie(vente.pa, vente.cost);
    verifier('V3. caisse limitee (20) : vente partielle de 3 bois, caisse -16,5 = liquide +16,5',
      bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty === 27
      && Math.abs(imp().caisse - 3.5) < 1e-9 && Math.abs(bouchons.state.liquide - 716.5) < 1e-9
      && Math.abs(fonds() + imp().caisse - avant) < 1e-9 && imp().stockBois === 3,
      'bois=' + bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty + ' caisse=' + imp().caisse);

    raz(); joueur(); atelier(200, 0); journal.saisies['vendre-bois-qte'] = '5';
    await confirmerVendreBoisImprimerie(1, 0);
    verifier('V4. 0 PA meme si pa=1 transmis ; intitule « Vendre des matieres premieres », 0 PA, 0 FR',
      bouchons.state.pa === 10 && vente.label === 'Vendre des matières premières' && vente.pa === 0 && vente.cost === 0, 'pa=' + bouchons.state.pa);

    // Plafond de stock (regle validee : 10 unites sous gestion PNJ)
    raz(); joueur(); atelier(500, 7); avant = fonds() + imp().caisse; journal.saisies['vendre-bois-qte'] = '10';
    await confirmerVendreBoisImprimerie(0, 0);
    verifier('V5. stock 7 : seules 3 unites sont acceptees (plafond 10), paiement exactement de 3 x 5,50',
      imp().stockBois === 10 && Math.abs(imp().caisse - 483.5) < 1e-9 && Math.abs(bouchons.state.liquide - 716.5) < 1e-9
      && bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty === 27
      && Math.abs(fonds() + imp().caisse - avant) < 1e-9 && /Vente partielle/.test(journal.toasts.join()),
      'stock=' + imp().stockBois + ' caisse=' + imp().caisse + ' liquide=' + bouchons.state.liquide);

    raz(); joueur(); atelier(500, 10); journal.saisies['vendre-bois-qte'] = '5';
    await confirmerVendreBoisImprimerie(0, 0);
    verifier('V6. stock deja a 10 : aucune unite acceptee, rien ne bouge',
      imp().stockBois === 10 && imp().caisse === 500 && bouchons.state.liquide === 700
      && bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty === 30
      && /plein/.test(journal.toasts.join()), journal.toasts.join(' / '));

    raz(); joueur(); atelier(500, 8); journal.saisies['vendre-bois-qte'] = '2';
    await Promise.all([confirmerVendreBoisImprimerie(0, 0), confirmerVendreBoisImprimerie(0, 0)]);
    verifier('V7. deux ventes simultanees pres du plafond : stockBois n\'atteint jamais 11',
      imp().stockBois === 10 && Math.abs(imp().caisse - (500 - 5.5 * 2)) < 1e-9,
      'stock=' + imp().stockBois + ' caisse=' + imp().caisse);

    raz(); joueur(); atelier(500, 0); journal.saisies['vendre-bois-qte'] = '4';
    await confirmerVendreBoisImprimerie(0, 0);
    verifier('V8. coherence caisse <-> bois achete : 4 bois entres, 22 FR sortis de la caisse',
      imp().stockBois === 4 && Math.abs(imp().caisse - 478) < 1e-9 && Math.abs(bouchons.state.liquide - 722) < 1e-9,
      'stock=' + imp().stockBois + ' caisse=' + imp().caisse);

    // ===== 3. Entree unique des tracts et socle commun des trois imprimeries =====
    var lut = ordresPiece('republic', 'capitale').map(function (o) { return o.fn; });
    verifier('F1. Luthecia : une seule entree « Imprimer des tracts », plus de bouton electoral ni calomnieux separe',
      lut.indexOf('imprimer_tracts_choix') >= 0 && lut.indexOf('imprimer_tracts_electoraux') < 0 && lut.indexOf('imprimer_tracts_calomnieux') < 0
      && ['consulter_archives_presse', 'vendre_bois_imprimerie', 'deposer_petite_annonce'].every(function (f) { return lut.indexOf(f) >= 0; }),
      JSON.stringify(lut));
    verifier('F1 bis. « Se renseigner » retire de L\'Autruche SEULEMENT (gabarit et Montrouge conserves)',
      lut.indexOf('se_renseigner') < 0
      && BUILDINGS['la-tribune'].rooms.accueil_tribune.orders.some(function (o) { return o.fn === 'se_renseigner'; })
      && ordresPiece('republic', 'ville_b').map(function (o) { return o.fn; }).indexOf('se_renseigner') >= 0
      && ordresPiece('narco', 'capitale').map(function (o) { return o.fn; }).indexOf('se_renseigner') >= 0,
      'luthecia=' + JSON.stringify(lut) + ' montrouge=' + JSON.stringify(ordresPiece('republic', 'ville_b').map(function (o) { return o.fn; })));

    raz(); joueur(); atelier(0, 50);
    doOrder('imprimer_tracts_choix', 0, 0, 'Imprimer des tracts', '', 100); await tick();
    var ch = bouchons.window._choixImprimerTracts || [];
    verifier('F2. le choix propose les deux mecaniques, aux memes couts que partout (1 PA + 150 chacune)',
      ch.length === 2 && ch[0].fn === 'imprimer_tracts_electoraux' && ch[0] === tractsDef && ch[0].pa === 1 && ch[0].cost === 150 && ch[0].type === 'legal'
      && ch[1].fn === 'imprimer_tracts_calomnieux' && ch[1].pa === 1 && ch[1].cost === 150 && ch[1].type === 'illegal' && journal.titre === 'Imprimer des tracts' && bouchons.state.pa === 10,
      JSON.stringify(ch.map(function (o) { return [o.fn, o.pa, o.cost, o.type]; })));

    raz(); joueur(); atelier(0, 5); avant = fonds() + imp().caisse;
    doOrder('imprimer_tracts_choix', 0, 0, 'Imprimer des tracts', '', 100); await tick();
    choisirTypeImprimerTracts(0); await tick(); await tick(); await tick();
    var titreElectoral = journal.titre, corpsElectoral = journal.corps || '';
    await imprimer('pour', 10, 1, 150);
    verifier('F3. choix « electoraux » -> modal du moteur unique (POUR/CONTRE, quantite), 1 PA, 150 FR, bois de l\'imprimerie',
      titreElectoral === 'Imprimer des tracts électoraux' && /CONTRE le candidat/.test(corpsElectoral) && /QUANTIT/.test(corpsElectoral)
      && bouchons.state.pa === 9 && bouchons.state.liquide === 550 && imp().caisse === 150 && imp().stockBois === 4
      && bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty === 30 && fonds() + imp().caisse === avant,
      'modal=' + titreElectoral + ' pa=' + bouchons.state.pa + ' caisse=' + imp().caisse + ' stockAtelier=' + imp().stockBois);

    raz(); joueur(); atelier(0, 5);
    doOrder('imprimer_tracts_choix', 0, 0, 'Imprimer des tracts', '', 100); await tick();
    choisirTypeImprimerTracts(1); await tick(); await tick(); await tick();
    var titreCalom = journal.titre;
    journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    var tc = bouchons.state.inventory.filter(function (i) { return i.type === 'tract_calomnieux'; })[0];
    verifier('F4. choix « calomnieux » -> meme matiere que l\'electoral : 1 bois DE L\'IMPRIMERIE, 1 PA, 150 FR, detection',
      titreCalom === 'Imprimer des tracts calomnieux' && bouchons.state.pa === 9
      && bouchons.state.inventory.filter(function (i) { return i.stackKey === 'bois'; })[0].qty === 30
      && bouchons.state.liquide === 550 && tc && tc.quantite === 10 && tc.legal === false && imp().caisse === 150 && imp().stockBois === 4
      && journal.appels.indexOf('checkDetection:imprimer_tracts_calomnieux') >= 0,
      'modal=' + titreCalom + ' pa=' + bouchons.state.pa + ' caisse=' + imp().caisse + ' stockAtelier=' + imp().stockBois);

    // Blocus syndical : le choix « electoraux » reste bloque exactement comme un bouton direct
    raz(); joueur(); bouchons.state.blocusActifIci = { intensite: 40 };
    doOrder(tractsDef.fn, tractsDef.pa, tractsDef.cost, tractsDef.label, tractsDef.desc, tractsDef.successRate); await tick();
    var refusDirect = journal.toasts.join();
    raz(); joueur(); bouchons.state.blocusActifIci = { intensite: 40 };
    doOrder('imprimer_tracts_choix', 0, 0, 'Imprimer des tracts', '', 100); await tick(); choisirTypeImprimerTracts(0); await tick();
    verifier('F5. blocus : « electoraux » via le choix = meme refus que le bouton direct', /Bloqué/.test(refusDirect) && journal.toasts.join() === refusDirect, journal.toasts.join());

    var autres = [['republic', 'ville_b'], ['narco', 'capitale'], ['soviet', 'capitale'], ['khalija', 'capitale']].map(function (pv) {
      var f = ordresPiece(pv[0], pv[1]).map(function (o) { return o.fn; });
      return pv.join('/') + ':' + (f.indexOf('imprimer_tracts_electoraux') >= 0 && f.indexOf('imprimer_tracts') < 0 && f.indexOf('vendre_bois_imprimerie') >= 0);
    });
    verifier('F6. autres journaux : meme moteur unique et meme vente de matieres premieres', autres.every(function (x) { return /:true$/.test(x); }), autres.join(' '));

    // SOCLE COMMUN : les trois imprimeries de Republia exposent les trois memes services.
    var socle = function (pays, ville, building, salles) {
      var b = BUILDINGS[building], ctx = WORLD[pays][ville].buildingContext && WORLD[pays][ville].buildingContext[building];
      var fns = [];
      salles.forEach(function (salle) {
        var ov = (ctx && ctx.roomOverrides && ctx.roomOverrides[salle]) || {};
        var extra = (ctx && ctx.roomsExtra && ctx.roomsExtra[salle] && ctx.roomsExtra[salle].orders) || [];
        var base = (b.rooms[salle] && b.rooms[salle].orders) || [];
        var excl = ov.excludeOrders || [];
        [].concat(base, extra, ov.orders || []).forEach(function (o) { if (excl.indexOf(o.fn) < 0) fns.push(o); });
      });
      return fns;
    };
    var socles = {
      'Luthecia (Autruche Entravee)': socle('republic', 'capitale', 'la-tribune', ['accueil_tribune']),
      'Montrouge (LCI)': socle('republic', 'ville_b', 'la-tribune', ['accueil_tribune', 'imprimerie']),
      'Port-Sainte-Marie (Gutenberg)': socle('republic', 'ville_a', 'imprimerie-librairie', ['accueil_imprimerie', 'atelier'])
    };
    var manques = [];
    Object.keys(socles).forEach(function (nom) {
      var fns = socles[nom].map(function (o) { return o.fn; });
      var aElectoraux = fns.indexOf('imprimer_tracts_electoraux') >= 0 || fns.indexOf('imprimer_tracts_choix') >= 0;
      var aCalomnieux = fns.indexOf('imprimer_tracts_calomnieux') >= 0 || fns.indexOf('imprimer_tracts_choix') >= 0;
      if (!aElectoraux) manques.push(nom + ':electoraux');
      if (!aCalomnieux) manques.push(nom + ':calomnieux');
      if (fns.indexOf('vendre_bois_imprimerie') < 0) manques.push(nom + ':vente');
    });
    verifier('E1. socle commun : les 3 imprimeries de Republia ont tracts electoraux + calomnieux + vente de matieres premieres', manques.length === 0, manques.join(' '));

    var couts = [];
    Object.keys(socles).forEach(function (nom) {
      socles[nom].forEach(function (o) {
        var lst = o.fn === 'imprimer_tracts_choix' ? o.choix.map(function (c) { return c.label ? c : tractsDef; }) : [o];
        lst.forEach(function (x) {
          if (x.fn === 'imprimer_tracts_electoraux' || x.fn === 'imprimer_tracts_calomnieux') couts.push(nom + '/' + x.fn + '=' + x.pa + 'PA/' + x.cost);
          if (x.fn === 'vendre_bois_imprimerie') couts.push(nom + '/vente=' + x.pa + 'PA/' + x.cost + '/' + x.label);
        });
      });
    });
    verifier('E2. memes couts partout : 1 PA + 150 par lot pour les deux tracts, vente a 0 PA et 0 FR',
      couts.every(function (c) { return /imprimer_tracts_(electoraux|calomnieux)=1PA\/150$/.test(c) || /vente=0PA\/0\/Vendre des matières premières$/.test(c); }), couts.join(' '));

    // ===== 4. Nom de l'imprimeur : jamais « Gustave » la ou il n'est pas affiche =====
    var noms = [], faux = [];
    ['republic', 'narco', 'soviet', 'khalija'].forEach(function (p) {
      Object.keys(WORLD[p]).forEach(function (v) {
        if ((WORLD[p][v].buildings || []).indexOf('la-tribune') < 0) return;
        joueur({ pays: p, ville: v });
        var n = nomImprimeurLocal();
        var ctx = getBuildingContext('la-tribune'), ov = ctx && ctx.roomOverrides && ctx.roomOverrides.accueil_tribune;
        var affiches = (ov && ov.persons && ov.persons.length) ? ov.persons : ((ctx && ctx.persons && ctx.persons.length) ? ctx.persons : BUILDINGS['la-tribune'].rooms.accueil_tribune.persons);
        if (n && !affiches.some(function (x) { return String(x.name).indexOf(n) === 0; })) faux.push(p + '/' + v);
        noms.push(p + '/' + v + '=' + (n || '(neutre)'));
      });
    });
    verifier('N1. nom de l\'imprimeur = PNJ reellement affiche dans la piece, sinon texte neutre', faux.length === 0 && noms[0] === 'republic/capitale=Gustave Encre', noms.join(' ; '));

    raz(); joueur({ pays: 'narco', ville: 'capitale' }); atelier(0, 0, 'narco', 'capitale'); journal.saisies['vendre-bois-qte'] = '5';
    await confirmerVendreBoisImprimerie(0, 0);
    raz(); joueur({ pays: 'narco', ville: 'capitale' }); atelier(0, 0, 'narco', 'capitale');
    await confirmerVendreBoisImprimerie(0, 0);
    var nNarco = (function () { joueur({ pays: 'narco', ville: 'capitale' }); return nomImprimeurLocal(); })();
    raz(); joueur({ pays: 'narco', ville: 'capitale' }); atelier(0, 0, 'narco', 'capitale'); journal.saisies['vendre-bois-qte'] = '5';
    await confirmerVendreBoisImprimerie(0, 0);
    verifier('N2. El Narco Times : message sans « Gustave » sauf si un Gustave y est affiche', nNarco && /Gustave/.test(nNarco) ? true : !/Gustave/.test(journal.toasts.join()), journal.toasts.join());

    // ===== 6. Tracts calomnieux : prix 150 par lot, paiement standard, acquisition immediate =====
    var entree = ordresPiece('republic', 'capitale').filter(function (o) { return o.fn === 'imprimer_tracts_choix'; })[0];
    var cliqueBoutonLuthecia = async function (indexChoix) {   // meme appel que le rendu du bouton (plateau-politique.js)
      doOrder(entree.fn, entree.pa, entree.cost, entree.label.replace(/'/g, ' '), (entree.desc || '').replace(/'/g, ' '), entree.successRate || 70); await tick();
      choisirTypeImprimerTracts(indexChoix); await tick(); await tick();
    };
    raz(); joueur({ liquide: 700, banque: 300 }); atelier(0, 5); avant = fonds() + imp().caisse;
    await cliqueBoutonLuthecia(1);
    var titreCal = journal.titre, corpsCal = journal.corps || '';
    journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(window._choixImprimerTracts[1].pa, window._choixImprimerTracts[1].cost);
    var lc = bouchons.state.inventory.filter(function (i) { return i.type === 'tract_calomnieux'; })[0];
    verifier('K1. calomnieux (vrai bouton Luthecia) : 1 PA + 150 + 1 bois DE L\'IMPRIMERIE, caisse +150, 10 tracts immediats, detection',
      titreCal === 'Imprimer des tracts calomnieux' && /150 FR/.test(corpsCal) && bouchons.state.pa === 9 && bouchons.state.liquide === 550 && bouchons.state.comptesBancaires.nationale.solde === 300
      && bouchons.state.inventory[0].qty === 30 && imp().caisse === 150 && imp().stockBois === 4 && lc && lc.quantite === 10 && lc.legal === false && lc.cible === 'Cible'
      && journal.appels.indexOf('checkDetection:imprimer_tracts_calomnieux') >= 0 && fonds() + imp().caisse === avant,
      'pa=' + bouchons.state.pa + ' liquide=' + bouchons.state.liquide + ' boisPerso=' + bouchons.state.inventory[0].qty + ' caisse=' + imp().caisse + ' stockAtelier=' + imp().stockBois);

    raz(); joueur({ liquide: 100, banque: 300 }); atelier(0, 5); avant = fonds() + imp().caisse; journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    verifier('K2. calomnieux liquide 100 + banque 300 : liquide 0, banque 250, caisse +150, sans creation',
      bouchons.state.liquide === 0 && bouchons.state.comptesBancaires.nationale.solde === 250 && imp().caisse === 150 && fonds() + imp().caisse === avant,
      'liquide=' + bouchons.state.liquide + ' banque=' + bouchons.state.comptesBancaires.nationale.solde + ' caisse=' + imp().caisse);

    raz(); joueur({ liquide: 80, banque: 20 }); bouchons.state.arg = 5000; atelier(0, 5); journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    verifier('K3. calomnieux fonds reels insuffisants (100 < 150) : refus, et le bois reserve est rendu a l\'imprimerie',
      /Fonds insuffisants/.test(journal.toasts.join()) && bouchons.state.pa === 10 && bouchons.state.liquide === 80
      && !bouchons.state.inventory.some(function (i) { return i.type === 'tract_calomnieux'; })
      && journal.appels.indexOf('checkDetection:imprimer_tracts_calomnieux') < 0 && imp().caisse === 0 && imp().stockBois === 5,
      journal.toasts.join(' / ') + ' stockAtelier=' + imp().stockBois);

    raz(); joueur({ liquide: 700, banque: 300 }); atelier(0, 0); journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    verifier('K3 bis. calomnieux sans bois a l\'imprimerie : refus propre, aucun PA, aucun FR, aucun tract',
      /Stock de bois insuffisant/.test(journal.toasts.join()) && bouchons.state.pa === 10 && bouchons.state.liquide === 700
      && imp().caisse === 0 && !bouchons.state.inventory.some(function (i) { return i.type === 'tract_calomnieux'; }),
      journal.toasts.join(' / '));

    raz(); joueur({ ville: 'ville_b' }); bouchons.state.currentRoom = 'imprimerie'; atelier(200, 5, 'republic', 'ville_b'); journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    verifier('K4. Montrouge (LCI, salle Imprimerie) : meme prix, credite la caisse de l\'atelier de Montrouge', imp('republic', 'ville_b').caisse === 350 && bouchons.state.liquide === 550,
      'caisse=' + imp('republic', 'ville_b').caisse);

    // Port-Sainte-Marie : etat REEL apres migration (republic_ville_a_imprimerie-librairie = {imprimerie:{caisse:200}})
    var psm = function () { return ETATS['republic/ville_a/imprimerie-librairie'].imprimerie; };
    raz(); joueur({ ville: 'ville_a' }); bouchons.state.currentBuilding = 'imprimerie-librairie'; bouchons.state.currentRoom = 'atelier';
    ETATS = { 'republic/ville_a/imprimerie-librairie': { imprimerie: { caisse: 200, stockBois: 5 } } }; avant = fonds() + psm().caisse; journal.saisies['tract-calomnieux-cible'] = 'Cible';
    var ordrePsm = BUILDINGS['imprimerie-librairie'].rooms.atelier.orders.filter(function (o) { return o.fn === 'imprimer_tracts_calomnieux'; })[0];
    doOrder(ordrePsm.fn, ordrePsm.pa, ordrePsm.cost, ordrePsm.label, ordrePsm.desc, ordrePsm.successRate); await tick();
    var corpsPsm = journal.corps || '';
    await confirmerImprimerTractsCalomnieux(ordrePsm.pa, ordrePsm.cost);
    verifier('K5. Port-Sainte-Marie (vrai bouton de l\'atelier Gutenberg) : 1 PA + 150 + 1 bois de Gutenberg, caisse +150, 10 tracts immediats',
      ordrePsm.cost === 150 && /150 FR/.test(corpsPsm) && bouchons.state.pa === 9 && bouchons.state.liquide === 550
      && bouchons.state.inventory[0].qty === 30 && psm().caisse === 350 && psm().stockBois === 4
      && bouchons.state.inventory.some(function (i) { return i.type === 'tract_calomnieux' && i.quantite === 10; }) && fonds() + psm().caisse === avant,
      'liquide=' + bouchons.state.liquide + ' caisse=' + psm().caisse + ' stock=' + psm().stockBois);

    raz(); joueur({ ville: 'ville_a', liquide: 100, banque: 20 }); bouchons.state.currentBuilding = 'imprimerie-librairie'; bouchons.state.currentRoom = 'atelier';
    ETATS = { 'republic/ville_a/imprimerie-librairie': { imprimerie: { caisse: 200, stockBois: 5 } } }; journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    verifier('K5 bis. Port-Sainte-Marie, fonds insuffisants (120 < 150) : refus, bois rendu, rien ne bouge',
      /Fonds insuffisants/.test(journal.toasts.join()) && bouchons.state.pa === 10 && psm().caisse === 200 && psm().stockBois === 5
      && !bouchons.state.inventory.some(function (i) { return i.type === 'tract_calomnieux'; }), journal.toasts.join());

    raz(); joueur(); bouchons.state.currentBuilding = 'marche'; ETATS = {}; journal.saisies['tract-calomnieux-cible'] = 'Cible';
    await confirmerImprimerTractsCalomnieux(1, 150);
    verifier('K7. hors d\'un atelier d\'imprimerie : refus, aucun paiement ni tract (jamais d\'impression gratuite)',
      /Atelier introuvable/.test(journal.toasts.join()) && bouchons.state.liquide === 700 && bouchons.state.pa === 10 && journal.sauvegardes.length === 0, journal.toasts.join());

    raz(); joueur(); atelier(0, 5);
    await cliqueBoutonLuthecia(0);
    await imprimer('pour', 10, window._choixImprimerTracts[0].pa, window._choixImprimerTracts[0].cost);
    verifier('K6. electoraux (vrai bouton Luthecia) : 10 tracts immediatement en inventaire, aucune autre etape',
      bouchons.state.inventory.some(function (i) { return i.type === 'tract' && i.quantite === 10 && i.tractType === 'pour' && i.cible === 'Cible'; }) && imp().caisse === 150);

    // ===== 7. Utilisation des tracts ordinaires (constats) =====
    var pops = [];
    var anciensAppels = [];
    bouchons.sbTractAppliquerEffetPop = function (n, d) { pops.push(n + ':' + d); return Promise.resolve({ ok: true }); };
    bouchons.sbAjusterPopJoueur = function (n, d) { anciensAppels.push(n + ':' + d); return Promise.resolve(); };
    bouchons.getStatEffective = function () { return 10; };
    var alea = function (seq) { var k = 0; Math.random = function () { return seq[Math.min(k++, seq.length - 1)]; }; };
    var lotTract = function (tt, q) { bouchons.state.inventory.push({ type: 'tract', name: 'Tracts ' + tt, tractType: tt, cible: 'Cible', quantite: q, legal: true }); };

    // Ordre du marche « Distribuer un tract » (+/-3 a 8 POP) supprime le 11 septembre 2026 : les
    // tracts ordinaires sont exclusivement electoraux (banc dedie : banc_jsc_tracts_electoraux.py).
    bouchons.syncCyclesDepuisSupabase = function () { return Promise.resolve(); };
    bouchons.tractsElectorauxDistribuablesIci = function () { return []; };   // aucun scrutin ouvert (helper reel teste dans le banc dedie)
    bouchons.estDimancheParis = function () { return false; };
    raz(); joueur(); lotTract('pour', 3); lotTract('contre', 2);
    await distribuerTractElectoralPNJ('Un PNJ', encodeURIComponent('{"name":"Un PNJ"}')); await tick();
    verifier('U4. PNJ, aucun scrutin ouvert (hors dimanche de vote) : refus, aucun tract consomme, aucun effet POP',
      /Aucun tract utilisable ici/.test(journal.toasts.join()) && bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; }).reduce(function (s, i) { return s + i.quantite; }, 0) === 5
      && pops.length === 0 && anciensAppels.length === 0, journal.toasts.join());

    // ===== Dons de tracts entre vrais PJ =====
    var ordre = [], envois = [], sauvegardes = [];
    var reponseDon = function () { return { ok: true }; }, reponseSauvegarde = function () { return [{}]; };
    bouchons.sbSavePersonnage = function (st) { ordre.push('sauvegarde'); sauvegardes.push(JSON.stringify(st.inventory)); return Promise.resolve(reponseSauvegarde()); };
    bouchons.sbTractsDonnerJoueur = function (rq, exp, dest, obj) { ordre.push('envoi'); envois.push({ rq: rq, exp: exp, dest: dest, obj: JSON.parse(JSON.stringify(obj)) }); return Promise.resolve(reponseDon(dest)); };
    var total = function (inv, type) { return inv.filter(function (i) { return i.type === type; }).reduce(function (s, i) { return s + i.quantite; }, 0); };
    var lotCal2 = function (q) { bouchons.state.inventory.push({ type: 'tract_calomnieux', name: 'Tracts calomnieux contre X', icon: 'ti-alert-triangle', cible: 'X', quantite: q, legal: false }); };

    raz(); joueur(); ordre = []; envois = []; lotTract('contre', 5); bouchons.state.pjSimules = []; journal.saisies['don-tract-0'] = '3';
    await confirmerDonTracts(0, 'UnVraiJoueur');
    var lotRestant = bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; })[0];
    verifier('G1. don partiel de 3 tracts ordinaires CONTRE a un vrai PJ : donneur -3, envoi exact, sauvegarde AVANT envoi',
      lotRestant.quantite === 2 && envois.length === 1 && envois[0].dest === 'UnVraiJoueur' && envois[0].exp === '__TEST_JSC__'
      && envois[0].obj.quantite === 3 && envois[0].obj.type === 'tract' && envois[0].obj.tractType === 'contre' && envois[0].obj.cible === 'Cible' && envois[0].obj.legal === true
      && ordre.join() === 'sauvegarde,envoi' && /^don-tracts-/.test(envois[0].rq),
      'restant=' + lotRestant.quantite + ' ordre=' + ordre.join() + ' objet=' + JSON.stringify(envois[0] && envois[0].obj));
    var envoiG1 = envois[0] || { rq: 'don-tracts-aucun', obj: { type: 'tract', tractType: 'contre', cible: 'Cible', quantite: 0, name: 'aucun' } };

    raz(); joueur(); ordre = []; envois = []; lotCal2(10); bouchons.state.pjSimules = []; journal.saisies['don-tract-0'] = '10';
    await confirmerDonTracts(0, 'UnVraiJoueur');
    verifier('G2. don TOTAL d\'un lot calomnieux : lot retire du donneur, objet illegal transmis tel quel',
      total(bouchons.state.inventory, 'tract_calomnieux') === 0 && envois.length === 1 && envois[0].obj.type === 'tract_calomnieux' && envois[0].obj.legal === false && envois[0].obj.quantite === 10 && envois[0].obj.cible === 'X',
      JSON.stringify(envois[0] && envois[0].obj));

    raz(); joueur(); ordre = []; envois = []; lotTract('pour', 5); bouchons.state.pjSimules = []; journal.saisies['don-tract-0'] = '5';
    reponseDon = function () { return { ok: false, raison: 'destinataire_introuvable' }; };
    await confirmerDonTracts(0, 'JoueurDisparu');
    var lotG3 = bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; });
    verifier('G3. destinataire disparu : refus propre, lot restitue intact (5, memes donnees), aucune perte',
      lotG3.length === 1 && lotG3[0].quantite === 5 && lotG3[0].tractType === 'pour' && /n'existe plus/.test(journal.toasts.join()) && ordre.join() === 'sauvegarde,envoi,sauvegarde',
      'lot=' + JSON.stringify(lotG3) + ' ordre=' + ordre.join());

    raz(); joueur(); ordre = []; envois = []; lotTract('pour', 5); bouchons.state.pjSimules = []; journal.saisies['don-tract-0'] = '2';
    reponseDon = function () { return null; };
    await confirmerDonTracts(0, 'UnVraiJoueur');
    verifier('G4. reseau en echec : une relance avec le MEME id, puis restitution (aucune perte)',
      envois.length === 2 && envois[0].rq === envois[1].rq && total(bouchons.state.inventory, 'tract') === 5, 'envois=' + envois.length + ' total=' + total(bouchons.state.inventory, 'tract'));

    raz(); joueur(); ordre = []; envois = []; lotTract('pour', 5); bouchons.state.pjSimules = []; journal.saisies['don-tract-0'] = '2';
    reponseDon = function () { return { ok: true }; }; reponseSauvegarde = function () { return null; };
    await confirmerDonTracts(0, 'UnVraiJoueur');
    verifier('G5. sauvegarde du donneur impossible : RIEN n\'est envoye, lot restitue',
      envois.length === 0 && total(bouchons.state.inventory, 'tract') === 5 && /n'a pas pu être enregistré/.test(journal.toasts.join()), journal.toasts.join());
    reponseSauvegarde = function () { return [{}]; };

    // Reception chez le destinataire : reclamation exclusive puis fusion avec le lot identique
    var reclamations = 0, lignes = [{ id: envoiG1.rq, expediteur: '__TEST_JSC__', objet: envoiG1.obj }];
    bouchons.sbGetObjetsRecus = function () { return Promise.resolve(lignes); };
    bouchons.sbTractsReclamerDon = function (id) { reclamations++; return Promise.resolve(reclamations === 1 ? { id: id, expediteur: '__TEST_JSC__', objet: envoiG1.obj } : null); };
    raz(); joueur(); bouchons.state.char = { name: 'UnVraiJoueur' }; lotTract('contre', 4);
    await verifierObjetsRecus(); await verifierObjetsRecus();
    var lotsRecus = bouchons.state.inventory.filter(function (i) { return i.type === 'tract'; });
    verifier('G6. reception : 3 tracts CONTRE ajoutes une seule fois (2 passages), fusionnes au lot identique (4 + 3 = 7)',
      lotsRecus.length === 1 && lotsRecus[0].quantite === 7 && lotsRecus[0].tractType === 'contre' && reclamations === 2, 'lots=' + JSON.stringify(lotsRecus));
    verifier('G7. conservation stricte : le donneur a perdu 3, le destinataire a gagne 3', 5 - 2 === 3 && 7 - 4 === 3 && envoiG1.obj.quantite === 3);

    raz(); joueur(); lotTract('pour', 5); bouchons.state.pjSimules = [{ name: 'PJ Simule', inventory: [] }]; journal.saisies['don-tract-0'] = '2'; envois = [];
    await confirmerDonTracts(0, 'PJ Simule');
    verifier('G8. PJ simule : comportement inchange (inventaire local de la simulation, aucun envoi reseau)',
      envois.length === 0 && bouchons.state.pjSimules[0].inventory[0].quantite === 2 && total(bouchons.state.inventory, 'tract') === 3);

    // ===== Sauvegarde de la POP en delta (vrai sbSavePersonnage) =====
    delete bouchons.sbSavePersonnage;
    var ecritures = [], reponseEcriture = function () { return [{}]; };
    bouchons.sbEcrirePersonnage = function (d) { ecritures.push(JSON.parse(JSON.stringify(d.resources))); return Promise.resolve(reponseEcriture()); };
    bouchons.sbSaveQueue = Promise.resolve();
    raz(); joueur(); bouchons.state.inf = 10; bouchons.state.dis = 40; bouchons.state.pop = 50; bouchons.state._popEnvoye = 50;
    bouchons.state.pop = 52; var t1 = sbSavePersonnage(bouchons.state);
    bouchons.state.pop = 55; var t2 = sbSavePersonnage(bouchons.state);
    await t1; await t2;
    verifier('S1. deux sauvegardes en file : deltas disjoints (+2 puis +3), jamais le meme changement compte deux fois',
      ecritures.length === 2 && ecritures[0].pop === 52 && ecritures[0].popBase === 50 && ecritures[1].pop === 55 && ecritures[1].popBase === 52 && bouchons.state._popEnvoye === 55,
      JSON.stringify(ecritures));
    ecritures = []; reponseEcriture = function () { return null; };
    bouchons.state.pop = 57; await sbSavePersonnage(bouchons.state);
    reponseEcriture = function () { return [{}]; };
    bouchons.state.pop = 58; await sbSavePersonnage(bouchons.state);
    verifier('S2. sauvegarde refusee : son delta (+2) est reporte sur la suivante (base 55, pop 58 = +3)',
      ecritures.length === 2 && ecritures[1].popBase === 55 && ecritures[1].pop === 58 && bouchons.state._popEnvoye === 58, JSON.stringify(ecritures));
    ecritures = []; raz(); joueur(); bouchons.state.pop = 40; delete bouchons.state._popEnvoye;
    await sbSavePersonnage(bouchons.state);
    verifier('S3. avant le chargement serveur (_popEnvoye absent) : POP ecrite telle quelle, sans popBase', ecritures.length === 1 && ecritures[0].pop === 40 && !('popBase' in ecritures[0]), JSON.stringify(ecritures));

    // ===== 8. Distribution des tracts calomnieux (mecanique serveur du 12 septembre 2026) =====
    var lotCal = function (q) { bouchons.state.inventory.push({ type: 'tract_calomnieux', name: 'Tracts calomnieux contre Cible', cible: 'Cible', quantite: q, legal: false }); };
    var detentions = [];
    bouchons.enregistrerDetention = function (n, motif, fin) { detentions.push(n + ':' + motif + ':' + fin); return Promise.resolve(); };
    bouchons.state = null;

    var appelsCal = [], reponseCal = { ok: true, reussi: true, critique: false, pa: 1, consomme: 1, jet: 12, taux: 60, juridiction: 'republic' };
    var ordreCal = [];
    bouchons.sbSavePersonnage = function () { ordreCal.push('sauvegarde'); return Promise.resolve([{}]); };
    bouchons.sbCalomnieDistribuer = function (rq, joueur, cible, pnj, vol) {
      ordreCal.push('rpc'); appelsCal.push({ rq: rq, joueur: joueur, cible: cible, pnj: pnj, vol: vol });
      return Promise.resolve(reponseCal && typeof reponseCal === 'function' ? reponseCal() : reponseCal);
    };
    var nbCal = function () { var l = bouchons.state.inventory.filter(function (i) { return i.type === 'tract_calomnieux'; }); return l.reduce(function (s, i) { return s + i.quantite; }, 0); };

    raz(); joueur(); lotCal(10); appelsCal = []; ordreCal = []; bouchons.state.inf = 20;
    reponseCal = { ok: true, reussi: true, critique: false, pa: 1, consomme: 1, jet: 12, taux: 60, juridiction: 'republic' };
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ', encodeURIComponent('{"name":"Un PNJ"}'));
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ', encodeURIComponent('{"name":"Un PNJ"}'));
    verifier('C1. reussite : 1 PA et 1 tract par tentative, effet POP/INF cote serveur uniquement (aucun calcul local)',
      bouchons.state.pa === 8 && nbCal() === 8 && appelsCal.length === 2 && appelsCal[0].cible === 'Cible' && appelsCal[0].pnj === 'Un PNJ' && appelsCal[0].vol === 10
      && ordreCal.slice(0, 2).join() === 'sauvegarde,rpc' && /-5 POP et -2 INF/.test(journal.toasts.join()),
      'pa=' + bouchons.state.pa + ' tracts=' + nbCal() + ' ordre=' + ordreCal.join());

    raz(); joueur(); lotCal(10); appelsCal = [];
    reponseCal = { ok: true, reussi: false, critique: false, pa: 1, consomme: 1, jet: 90, taux: 60, juridiction: 'republic' };
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C2. echec normal : 1 PA + 1 tract consommes, aucun effet, aucune detention, retentable',
      bouchons.state.pa === 9 && nbCal() === 9 && !bouchons.state.estEmprisonne && /Sans effet/.test(journal.toasts.join()), journal.toasts.join());

    raz(); joueur(); lotCal(10); lotCal(4); detentions = [];
    reponseCal = { ok: true, reussi: false, critique: true, pa: 1, consomme: 1, jet: 95, taux: 60, juridiction: 'republic', poursuite: 'flagrant_delit' };
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C3. echec critique DANS le pays competent : flagrant delit, tous les lots detruits, 1 jour de detention',
      nbCal() === 0 && bouchons.state.estEmprisonne && bouchons.state.estEmprisonne.jours === 1 && detentions.length === 1 && bouchons.state.pa === 9,
      'detention=' + JSON.stringify(bouchons.state.estEmprisonne) + ' registre=' + detentions.join());

    raz(); joueur(); lotCal(10); detentions = []; bouchons.state.immuniteMilitaireActuelle = true;
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C4. echec critique sous immunite militaire : tracts detruits, pas de detention', nbCal() === 0 && !bouchons.state.estEmprisonne && detentions.length === 0);

    // Juridiction internationale : faits commis hors du pays de residence de la victime.
    raz(); joueur({ pays: 'narco' }); lotCal(10); detentions = [];
    var mandat = { id: 'rech-calomnie-xyz', type: 'condamnation', origine: 'serveur', country: 'republic',
                   motifs: [{ type: 'Distribution de tracts calomnieux', jours: 1 }] };
    reponseCal = { ok: true, reussi: false, critique: true, pa: 1, consomme: 1, jet: 95, taux: 60, juridiction: 'republic', poursuite: 'mandat', mandat: mandat };
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C4 bis. echec critique HORS du pays competent : aucune arrestation ni destruction sur place, mandat reflete localement avec son pays',
      !bouchons.state.estEmprisonne && detentions.length === 0 && nbCal() === 9 && bouchons.state.pa === 9
      && (bouchons.state.recherche || []).length === 1 && bouchons.state.recherche[0].country === 'republic'
      && bouchons.state.recherche[0].type === 'condamnation',
      'recherche=' + JSON.stringify(bouchons.state.recherche) + ' tracts=' + nbCal());

    raz(); joueur(); lotCal(10); appelsCal = [];
    reponseCal = { ok: false, raison: 'deja_convaincu' };
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C4 ter. refus serveur (PNJ deja convaincu contre cette cible aujourd\'hui) : aucun PA, aucun tract consomme',
      bouchons.state.pa === 10 && nbCal() === 10 && /déjà relayé/.test(journal.toasts.join()), journal.toasts.join());

    raz(); joueur(); lotCal(10); bouchons.state.pa = 0;
    appelsCal = [];
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C4 quater. 0 PA : refus avant tout appel serveur, aucun tract consomme', appelsCal.length === 0 && nbCal() === 10 && /PA insuffisants/.test(journal.toasts.join()), journal.toasts.join());

    raz(); joueur(); lotCal(10); appelsCal = [];
    reponseCal = null;   // reseau indisponible
    await confirmerDistribuerTractCalomnieux('Cible', 'Un PNJ');
    verifier('C4 quinquies. reseau indisponible : une relance avec le MEME id, puis aucun tract ni PA consomme',
      appelsCal.length === 2 && appelsCal[0].rq === appelsCal[1].rq && nbCal() === 10 && bouchons.state.pa === 10, 'appels=' + appelsCal.length);
    delete bouchons.sbSavePersonnage;
    delete bouchons.sbCalomnieDistribuer;

    raz(); joueur({ ville: 'ville_a' }); lotCal(10); lotTract('pour', 5); bouchons.state.currentBuilding = 'centre-multinodal-port-sainte-marie'; bouchons.state.dis = 50;
    bouchons.getMalusISN = function () { return 0; }; bouchons.addMailNotification = function (de, sujet) { journal.appels.push('mail:' + sujet); };
    doPasserDouanesAeroport();
    verifier('C5. controle douanier : tracts calomnieux confisques + convocation (possession_illegale_douane), tracts ordinaires conserves',
      !bouchons.state.inventory.some(function (i) { return i.type === 'tract_calomnieux'; }) && bouchons.state.inventory.some(function (i) { return i.type === 'tract'; })
      && bouchons.state.convocations.some(function (c) { return c.motif === 'possession_illegale_douane'; }), JSON.stringify(bouchons.state.convocations.map(function (c) { return c.motif; })));

    // ===== 5. Boucle amorcee et « Se renseigner » (inchange) =====
    raz(); joueur({ liquide: 1000, banque: 0 }); atelier(200, 0); avant = fonds() + imp().caisse;
    journal.saisies['vendre-bois-qte'] = '10';
    await confirmerVendreBoisImprimerie(0, 0);
    var e1 = JSON.parse(JSON.stringify(imp()));
    await imprimer('pour', 20, 1, 150);
    verifier('D. boucle fermee : caisse 200 -> achat de 10 bois (-55) -> 20 tracts (+300, -2 bois) -> 445, monnaie conservee',
      e1.caisse === 145 && e1.stockBois === 10 && imp().caisse === 445 && imp().stockBois === 8
      && fonds() + imp().caisse === avant,
      'caisse=' + e1.caisse + ' -> ' + imp().caisse + ' stock=' + imp().stockBois + ' conserve=' + (fonds() + imp().caisse === avant));

    raz(); joueur();
    doOrder('se_renseigner', 0, 0, 'Se renseigner', '', 100); await tick();
    verifier('C. se renseigner (inchange) : 0 PA, « Rien de particulier a signaler ici. »', bouchons.state.pa === 10 && /Rien de particulier/.test(journal.corps || ''));
  };
}

scenarios().then(function () {
  resultats.forEach(function (r) { print(r[0] + ' ' + r[1] + '   [' + r[2] + ']'); });
  print(''); print(resultats.length + ' test(s), ' + resultats.filter(function (r) { return r[0] !== 'OK  '; }).length + ' echec(s)');
}).catch(function (e) { print('ERREUR ' + e + '\n' + (e.stack || '')); });
"""
js = banc.replace('%DATA%', lire('data.js')).replace('%SOURCES%', SOURCES)
with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
    fh.write(js)
out = subprocess.run([JSC, fh.name], capture_output=True, text=True, timeout=120)
print(out.stdout + out.stderr)
sys.exit(0 if ' 0 echec(s)' in out.stdout else 1)
