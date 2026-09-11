#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Banc d'execution REEL des circuits de vente face aux lois d'interdiction (11 septembre 2026).

Extrait des sources les VRAIES fonctions (gestionnaires client, primitives Assemblee, fonctions du
cron) et les execute dans JavaScriptCore (jsc) avec des bouchons pour le DOM et la base. Les appels a
assemblee_verifier_vente / assemblee_achat_illegal sont servis par les REPONSES REELLES du serveur,
capturees au prealable (capture.json) pour chaque charge exacte : une charge inattendue fait echouer
le test. Chaque scenario est joue avec et sans loi en vigueur.

Usage : python3 .scratch/banc_jsc_interdictions.py <capture.json>
"""
import json, os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


def extraire(src, nom, genre='function'):
    """Declaration de premier niveau `nom`, jusqu'a la declaration de premier niveau suivante."""
    if genre == 'function':
        m = re.search(r'^(async )?function ' + re.escape(nom) + r'\(', src, re.M)
    else:
        m = re.search(r'^const ' + re.escape(nom) + r'\s*=', src, re.M)
    if not m:
        raise SystemExit('introuvable : ' + nom)
    fin = re.compile(r'^(async function |function |const |let |var |// =====|export )', re.M)
    suite = fin.search(src, m.end())
    return src[m.start(): suite.start() if suite else len(src)].rstrip() + '\n'


ILL = lire('plateau-actions-illegales-rumeurs.js')
JE = lire('plateau-justice-economie.js')
ASS = lire('plateau-assemblee.js')
CRON = lire('api/cron-minuit.js')
DATA = lire('data.js')

morceaux = [
    extraire(ASS, 'assembleeLoiApplicable'), extraire(ASS, 'assembleeNouvelleRequete'),
    extraire(ASS, 'assembleeControlerVenteLegale'), extraire(ASS, 'assembleeSignalerAchatIllegal'),
    extraire(ILL, 'ARMES_CATALOGUE', 'const'), extraire(ILL, 'RECETTES_ALIMENTAIRES', 'const'),
    extraire(ILL, 'PRODUITS_MARCHE', 'const'), extraire(ILL, 'resoudreProduitCommerce'),
    extraire(ILL, 'confirmerAchatArme'), extraire(ILL, 'confirmerAchatArmeIllegal'),
    extraire(ILL, 'commanderProduitCommerce'), extraire(ILL, 'vendreMatiereCommerce'),
    extraire(JE, 'confirmerAchatEntrepot'), extraire(JE, 'confirmerVenteDirecteUsine'),
    extraire(JE, 'confirmerAcheterCriee'), extraire(JE, 'acheterLotNonReclameeFret'),
    extraire(DATA, 'RESSOURCES_ECONOMIE', 'const'),
    extraire(CRON, 'RESSOURCES_ECONOMIE_SERVEUR', 'const'), extraire(CRON, 'ACHATS_INTER_USINES', 'const'),
    extraire(CRON, 'PART_ACHAT_INTER_USINES', 'const'), extraire(CRON, 'EXPORTATIONS_PORT', 'const'),
    extraire(CRON, 'matieresInterditesRepublia'), extraire(CRON, 'traiterAchatsInterUsinesQuotidien'),
    extraire(CRON, 'traiterExportationsPortQuotidien'),
]

capture = json.load(open(sys.argv[1], encoding='utf-8'))

banc = r"""
const CAPTURE = %CAPTURE%;
// Charge normalisee -> nom de la charge capturee
const CHARGES = {
  P_couteau: [{stackKey:null,type:'arme',sousType:'blanche'}], P_revolver: [{stackKey:null,type:'arme',sousType:'poing'}],
  P_boeuf: [{stackKey:'boeuf_bourguignon',type:null,sousType:null}],
  P_entrepot_cereales_viande: [{stackKey:'cereales',type:null,sousType:null},{stackKey:'viande',type:null,sousType:null}],
  P_entrepot_cereales: [{stackKey:'cereales',type:null,sousType:null}], P_poisson: [{stackKey:'poisson',type:null,sousType:null}],
  P_alcool: [{stackKey:'alcool',type:null,sousType:null}], P_tabac: [{stackKey:'tabac',type:null,sousType:null}],
  P_viande: [{stackKey:'viande',type:null,sousType:null}]
};
const norm = objs => JSON.stringify((objs || []).map(o => ({ stackKey: o.stackKey || null, type: o.type || null, sousType: o.sousType || null })));
const INDEX = {}; Object.keys(CHARGES).forEach(k => { INDEX[norm(CHARGES[k])] = k; });

let SCENARIO = 'avec_lois', MODE_ILLEGAL = 'achat_illegal_detecte', journal;
function raz() { journal = { toasts: [], debits: [], stock: [], inventaire: 0, sbUpdate: 0, setEtat: 0, signaux: [], charges: [], rpc: [] }; }
const bouchons = {
  state: null, COUNTRIES: { republic: { cur: 'FR' } },
  showToast: (t, m) => journal.toasts.push(t + ' | ' + (m || '')),
  deduireCoutOrdre: o => { journal.debits.push(o); return Promise.resolve({ ok: true }); },
  debiterFondsOrdinaires: m => { journal.debits.push({ fonds: m }); return Promise.resolve({ ok: true }); },
  getFondsDisponiblesOrdinaires: () => 1e9,
  addToInventory: o => { journal.inventaire += (o.qty || 1); return o.qty || 1; },
  sbAssembleeVerifierVente: (objets) => {
    const k = INDEX[norm(objets)];
    journal.charges.push(k || ('INATTENDUE ' + norm(objets)));
    if (!k) return Promise.reject(new Error('charge inattendue'));
    return Promise.resolve(CAPTURE[SCENARIO][k]);
  },
  sbAssembleeAchatIllegal: (nom, circuit, ref, rq) => { journal.signaux.push(circuit + '/' + ref); return Promise.resolve(CAPTURE[MODE_ILLEGAL]); },
  sbSavePersonnage: () => Promise.resolve(), sauvegarderPersonnageImmediat: () => {}, updateUI: () => {}, addJournalEntry: () => {},
  rafraichirAssembleeInterdictions: () => Promise.resolve(), assembleeInterdictionMatiere: () => null,
  resoudreArmeAffichage: a => a, appliquerTaxeTransaction: p => Promise.resolve({ net: p }),
  chargerArmurerieLocale: () => Promise.resolve(bouchons._armurerie),
  sbSaveEntreprise: (id, d) => { journal.stock.push(JSON.stringify(d.stockProduits || d.stockMatieres || {})); return Promise.resolve(); },
  BONUS_CARRIERE_VOL: {}, getIndiceVille: () => 0, consommerBonusBenediction: t => t, INDICES_NATIONAUX: {},
  COMMERCE_SANS_CAISSE_AUTONOME: {}, chargerCommerce: () => Promise.resolve(bouchons._commerce),
  matieresAccepteesParCommerce: () => ['viande', 'cereales'], plafondEffectifCommerce: () => 999,
  prixAchatMatiereCommerce: () => 10, crediterStockMatiereCommerce: (d, m, q) => { d.stockMatieres[m] = (d.stockMatieres[m] || 0) + q; },
  getPrixRessourceEntrepot: () => 10, getPrixRessource: () => 10, produitsUsine: () => ['alcool', 'tabac'],
  RESSOURCES_CRIEE_VENDABLES: ['poisson'], PLAFOND_INVENTAIRE_EMPILABLE: 100, getTotalInventaire: () => 0, RATIO_PRIX_LIQUIDATION_FRET: 0.5,
  totalContenuFret: l => l.reduce((s, x) => s + (x.quantite || 0), 0),
  chargerContenuCaisseFret: () => Promise.resolve([{ id: 'l1', objet: { stackKey: 'viande', stackable: true, name: 'Viande' }, quantite: 3 }]),
  sbGet: () => Promise.resolve([{ statut: 'a_vendre', pays_destination: 'republic', valeur_declaree: 100, quantite_arrivee: 3, building_destination: 'x' }]),
  sbUpdate: () => { journal.sbUpdate++; return Promise.resolve([{}]); },
  sbGetBatimentEtat: (p, v, b) => Promise.resolve(JSON.parse(JSON.stringify(bouchons._etats[b] || bouchons._etats.defaut))),
  sbSetBatimentEtat: () => { journal.setEtat++; return Promise.resolve(); },
  getPrixRessourceServeur: () => 10, ENTREPOTS_VILLES: [{ city: 'capitale', buildingId: 'entrepot-capitale' }],
  VILLE_ID_PORT_PSM: 'ville_a', BUILDING_ID_PORT_PSM: 'port', VILLE_ID_PORT: 'ville_a', BUILDING_ID_PORT: 'port',
  sbRpc: (fn, params) => { journal.rpc.push(fn + ':' + (params.p_objets || []).length); return Promise.resolve(CAPTURE[SCENARIO].P_cron); },
  document: { getElementById: id => ({ value: bouchons._saisies[id] || '', classList: { add() {}, remove() {} }, innerHTML: '' }) },
  _saisies: {}, _etats: {}, _armurerie: null, _commerce: null
};
const auto = {};
// Liaisons propres au banc : jamais interceptees par le mandataire.
const BANC = new Set(['CAPTURE', 'CHARGES', 'norm', 'INDEX', 'SCENARIO', 'MODE_ILLEGAL', 'journal', 'raz', 'bouchons', 'auto', 'bac', 'resultats', 'verifier', 'BANC']);
const bac = new Proxy(bouchons, {
  has: (t, k) => typeof k === 'string' && !(k in globalThis) && !BANC.has(k),
  get: (t, k) => {
    if (k === Symbol.unscopables) return undefined;
    if (k in t) return t[k];
    if (!auto[k]) auto[k] = function () { return Promise.resolve(undefined); };
    return auto[k];
  },
  set: (t, k, v) => { t[k] = v; return true; }
});

var resultats = [];
function verifier(nom, cond, detail) { resultats.push([cond ? 'OK  ' : 'ECHEC', nom, detail || '']); }

with (bac) {
%SOURCES%

  var joueur = async function () {
    bouchons.state = { country: 'republic', currentCity: 'capitale', char: { name: '__TEST_JSC__' }, pa: 10, arg: 1e9, liquide: 1e9,
                       inventory: [{ stackable: true, stackKey: 'viande', qty: 5, name: 'Viande' }], historiqueCrimes: [], convocations: [], dis: 40, day: 5, hour: 12 };
  }

  var scenarios = async function () {
    for (const sc of ['avec_lois', 'sans_loi']) {
      SCENARIO = sc; const loi = sc === 'avec_lois';

      // 1. Armurerie LEGALE : couteau (Armes blanches) et revolver (non vise)
      for (const [arme, vise] of [['couteau', true], ['revolver', false]]) {
        raz(); await joueur();
        bouchons._armurerie = { id: 'armurerie-republic-capitale', stockProduits: { couteau: 3, revolver: 3 }, parametres: { prixVente: {} }, caisse: 0, historique: [] };
        const avant = bouchons.state.inventory.length;
        await confirmerAchatArme(arme);
        const vendu = bouchons.state.inventory.length > avant;
        verifier('[' + sc + '] armurerie legale ' + arme + (loi && vise ? ' -> refusee' : ' -> vendue'),
          loi && vise ? (!vendu && journal.debits.length === 0 && bouchons._armurerie.stockProduits[arme] === 3)
                      : (vendu && journal.debits.length === 1 && bouchons._armurerie.stockProduits[arme] === 2),
          'debits=' + journal.debits.length + ' stock=' + bouchons._armurerie.stockProduits[arme] + ' charge=' + journal.charges.join(','));
      }

      // 2. Criee : poisson
      raz(); await joueur();
      bouchons._etats = { port: { port: { criee: { stock: { poisson: 30 } } } }, defaut: {} }; bouchons._saisies = { 'achat-criee-poisson': '4' };
      await confirmerAcheterCriee(1, 0);
      verifier('[' + sc + '] criee poisson' + (loi ? ' -> refusee' : ' -> vendue'),
        loi ? (journal.debits.length === 0 && journal.inventaire === 0 && journal.setEtat === 0) : (journal.debits.length >= 1 && journal.inventaire === 4),
        'debits=' + journal.debits.length + ' inventaire=' + journal.inventaire + ' charge=' + journal.charges.join(','));

      // 3. Viandes : matiere viande (entrepot) refusee, boeuf bourguignon (commerce) toujours vendu
      raz(); await joueur();
      bouchons._etats = { 'entrepot-capitale': { entrepot: { stock: { cereales: 50, viande: 50 }, prixManuel: {}, caisse: 0 } }, defaut: {} };
      bouchons._saisies = { 'achat-entrepot-cereales': '2', 'achat-entrepot-viande': '2' };
      await confirmerAchatEntrepot('entrepot-capitale', 1, 0);
      verifier('[' + sc + '] entrepot cereales+viande' + (loi ? ' -> refuse' : ' -> vendu'),
        loi ? (journal.debits.length === 0 && journal.inventaire === 0) : (journal.debits.length >= 1 && journal.inventaire === 4),
        'debits=' + journal.debits.length + ' inventaire=' + journal.inventaire + ' charge=' + journal.charges.join(','));
      raz(); await joueur();
      bouchons._commerce = { proprietaire: 'PNJ', type: 'brasserie', stockProduits: { boeuf_bourguignon: 5 }, stockMatieres: {}, parametres: { prixVente: { boeuf_bourguignon: 25 } }, caisse: 0 };
      const rc = await commanderProduitCommerce('brasserie', 'republic', 'capitale', 'brasserie-x', 'salle', 'boeuf_bourguignon');
      verifier('[' + sc + '] boeuf bourguignon (commerce) -> toujours vendu', rc && rc.ok === true && bouchons._commerce.stockProduits.boeuf_bourguignon === 4,
        'ok=' + (rc && rc.ok) + ' charge=' + journal.charges.join(','));

      // 4. Alcools : vente directe de l'usine
      raz(); await joueur();
      bouchons._etats = { 'pole-tabac-alcools-psm': { usine: { venteDirecte: { alcool: 20, tabac: 20 }, prixManuel: {}, caisse: 0 } }, defaut: {} };
      bouchons._saisies = { 'vente-usine-alcool': '3' };
      await confirmerVenteDirecteUsine('pole-tabac-alcools-psm', 1, 0);
      verifier('[' + sc + '] usine vente directe alcool' + (loi ? ' -> refusee' : ' -> vendue'),
        loi ? (journal.debits.length === 0 && journal.inventaire === 0) : (journal.debits.length === 1 && journal.inventaire === 3),
        'debits=' + journal.debits.length + ' inventaire=' + journal.inventaire + ' charge=' + journal.charges.join(','));

      // 5. Fret : lot contenant de la viande
      raz(); await joueur();
      await acheterLotNonReclameeFret('caisse-1');
      verifier('[' + sc + '] lot de fret avec viande' + (loi ? ' -> refuse avant tout debit' : ' -> vendu'),
        loi ? (journal.sbUpdate === 0 && journal.inventaire === 0) : (journal.sbUpdate >= 1 && journal.inventaire === 3),
        'sbUpdate=' + journal.sbUpdate + ' inventaire=' + journal.inventaire + ' charge=' + journal.charges.join(','));

      // 6. Guichet de rachat : un joueur vend sa viande a un commerce
      raz(); await joueur();
      bouchons._commerce = { proprietaire: 'PNJ', type: 'brasserie', stockProduits: {}, stockMatieres: { viande: 0 }, parametres: { prixVente: {} }, caisse: 1000 };
      const rv = await vendreMatiereCommerce('brasserie', 'republic', 'capitale', 'brasserie-x', 'salle', 'viande', 2);
      const lot = bouchons.state.inventory.find(i => i.stackKey === 'viande');
      verifier('[' + sc + '] joueur -> commerce : viande' + (loi ? ' -> refusee' : ' -> rachetee'),
        loi ? (rv.ok === false && rv.raison === 'vente_interdite' && lot && lot.qty === 5) : (rv.ok === true && lot && lot.qty === 3),
        'ok=' + rv.ok + ' raison=' + (rv.raison || '') + ' lot=' + (lot ? lot.qty : 0));

      // 7. Cron : achat automatique usine -> usine (alcool)
      raz();
      bouchons._etats = { 'pole-tabac-alcools-psm': { usine: { venteDirecte: { alcool: 50 }, caisse: 1000 } }, 'usine-pharmaceutique-luthecia': { usine: { stockMatieres: {}, caisse: 1000 } }, defaut: {} };
      const ra = await traiterAchatsInterUsinesQuotidien({ alcool: 16 });
      verifier('[' + sc + '] cron usine -> usine alcool' + (loi ? ' -> bloque' : ' -> execute'),
        loi ? (ra[0].qte === 0 && ra[0].raison === 'interdit_par_la_loi' && journal.setEtat === 0) : (ra[0].qte > 0 && journal.setEtat === 2),
        'qte=' + ra[0].qte + ' raison=' + ra[0].raison + ' rpc=' + journal.rpc.join(','));

      // 8. Cron : exportations sous contrat (viande interdite, cereales non)
      raz();
      bouchons._etats = { 'entrepot-capitale': { entrepot: { stock: { cereales: 400, viande: 400 } } }, port: { port: { exportations: {} } }, defaut: {} };
      const re = await traiterExportationsPortQuotidien();
      verifier('[' + sc + '] cron exportation viande' + (loi ? ' -> bloquee, cereales exportees' : ' -> exportee'),
        loi ? (re.exportations.viande.raison === 'interdit_par_la_loi' && re.exportations.cereales.envoye > 0)
            : (re.exportations.viande.envoye > 0 && re.exportations.cereales.envoye > 0),
        JSON.stringify(re.exportations));
    }

    // 9. Circuit ILLEGAL preexistant : marche noir, couteau interdit -> vente conservee, UNE seule
    //    procedure (celle du marche noir), jamais de seconde qualification par la loi.
    for (const mode of ['achat_illegal_detecte', 'achat_illegal_non_detecte']) {
      SCENARIO = 'avec_lois'; MODE_ILLEGAL = mode; raz(); await joueur();
      bouchons._armurerie = { id: 'armurerie-republic-capitale', stockProduits: { couteau: 3 }, parametres: { prixVente: {} }, caisse: 0, historique: [] };
      const rnd = Math.random; Math.random = () => 0.1;   // l'armurier accepte la vente clandestine
      try { await confirmerAchatArmeIllegal('couteau'); } finally { Math.random = rnd; }
      const s = bouchons.state;
      const actes = JSON.stringify(s.historiqueCrimes.map(h => h.acte));
      verifier('[marche noir, ' + mode + '] vente conservee, une seule trace, aucune seconde procedure',
        bouchons._armurerie.stockProduits.couteau === 2 && s.inventory.some(i => i.type === 'arme' && i.legal === false)
        && journal.signaux.length === 0 && actes === '["achat_arme_illegal"]' && s.convocations.length === 0,
        'stock=' + bouchons._armurerie.stockProduits.couteau + ' traces=' + actes + ' convocations=' + s.convocations.length + ' signal=' + journal.signaux.length);
    }
  }
}

scenarios().then(() => {
  resultats.forEach(r => print(r[0] + ' ' + r[1] + '   ' + r[2]));
  print('\n' + resultats.length + ' test(s), ' + resultats.filter(r => r[0] !== 'OK  ').length + ' echec(s)');
}).catch(e => print('ERREUR ' + e + '\n' + (e.stack || '')));
"""
# Dans jsc, une DECLARATION de fonction placee dans un bloc `with` ne capture pas la portee du
# `with` : on la transforme en EXPRESSION de fonction (corps strictement inchange).
def en_expression(m):
    return re.sub(r'^(async )?function (\w+)\(', lambda x: 'var ' + x.group(2) + ' = ' + (x.group(1) or '') + 'function ' + x.group(2) + '(', m, count=1, flags=re.M)
morceaux = [en_expression(m) for m in morceaux]
banc = banc.replace('%CAPTURE%', json.dumps(capture)).replace('%SOURCES%', '\n'.join(morceaux))
with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
    fh.write(banc)
    chemin = fh.name
sortie = subprocess.run([JSC, chemin], capture_output=True, text=True)
print(sortie.stdout + sortie.stderr)
