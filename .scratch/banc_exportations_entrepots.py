#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DES EXPORTATIONS D'ENTREPOT (14 septembre 2026).

Les exportations vers Al-Khalija retiraient chaque nuit 225 cereales et 125 viande des trois
entrepots SANS rien crediter : c'est ce qui les a menes a la faillite et maintenait ces deux
ressources a zero. L'arbitrage retenu : vente au prix_base, recette creditee a la caisse de
l'entrepot FOURNISSEUR, au prorata exact de ce qu'il a reellement fourni.

Ce banc execute la VRAIE fonction traiterExportationsPortQuotidien dans JavaScriptCore, avec une
base bouchonnee en memoire. Aucun appel reseau, aucune ecriture reelle, et surtout AUCUN appel a
/api/cron-minuit.

Usage : python3 .scratch/banc_exportations_entrepots.py
"""
import json, os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


def extraire(src, nom, genre='function'):
    m = re.search((r'^(async )?function ' if genre == 'function' else r'^const ')
                  + re.escape(nom) + (r'\(' if genre == 'function' else r'\s*='), src, re.M)
    if not m:
        raise SystemExit('introuvable : ' + nom)
    suite = re.compile(r'^(async function |function |const |let |var |// =====|export )', re.M).search(src, m.end())
    return src[m.start(): suite.start() if suite else len(src)].rstrip() + '\n'


def en_expression(code):
    return re.sub(r'^(async )?function (\w+)\(',
                  lambda m: 'var %s = %sfunction %s(' % (m.group(2), m.group(1) or '', m.group(2)),
                  code, flags=re.M)


C = lire('api/cron-minuit.js')
SOURCES = ''.join(en_expression(x) for x in [
    extraire(C, 'RESSOURCES_ECONOMIE_SERVEUR', 'const'),
    extraire(C, 'ENTREPOTS_VILLES', 'const'),
    extraire(C, 'CAPACITE_ENTREPOT_PAR_RESSOURCE', 'const'),
    extraire(C, 'DESIDERATA_PNJ_DEFAUT', 'const'),
    extraire(C, 'desiderataEffectifs'),
    extraire(C, 'EXPORTATIONS_PORT', 'const'),
    extraire(C, 'ORIGINE_IMPORTS_PORT', 'const'),
    extraire(C, 'RESSOURCES_REROUTEES_PORT', 'const'),
    extraire(C, 'USINE_LOCALE_PAR_VILLE', 'const'),
    extraire(C, 'PART_REDIRECTION_USINE', 'const'),
    extraire(C, 'VOLUME_TOTAL_JOUR', 'const'),
    extraire(C, 'NB_LIVRAISONS_JOUR', 'const'),
    extraire(C, 'BOIS_UNITES_PAR_VILLE_JOUR', 'const'),
    extraire(C, 'BOIS_SCIERIE_JOUR', 'const'),
    extraire(C, 'BOIS_SOVARKA_JOUR', 'const'),
    extraire(C, 'NB_ARRIVAGES_CONSERVES', 'const'),
    extraire(C, 'repartirSelonPourcentages'),
    extraire(C, 'traiterExportationsPortQuotidien'),
    extraire(C, 'livrerEntrepotsQuotidien'),
]).replace('const ', 'var ')

BANC = r"""
var resultats = [];
function verifier(nom, ok, detail) {
  resultats.push({ nom: nom, ok: !!ok, detail: String(detail === undefined ? '' : detail).slice(0, 170) });
}

// ---- Base bouchonnee : les trois entrepots et le port, en memoire -------------
var BASE = {};
var VILLE_ID_PORT_PSM = 'ville_a', BUILDING_ID_PORT_PSM = 'port-sainte-marie';
var interditesSimulees = new Set();

function cleBat(pays, ville, bat) { return pays + '_' + ville + '_' + bat; }
async function sbGetBatimentEtat(pays, ville, bat) {
  var k = cleBat(pays, ville, bat);
  return BASE[k] ? JSON.parse(JSON.stringify(BASE[k])) : null;
}
async function sbSetBatimentEtat(pays, ville, bat, etat) {
  BASE[cleBat(pays, ville, bat)] = JSON.parse(JSON.stringify(etat));
  return etat;
}
async function matieresInterditesRepublia() { return interditesSimulees; }
// Le reapprovisionnement lit desormais le transit et les directeurs en poste, et ecrit au
// registre : bouchons neutres, ce banc ne teste pas ces chemins-la.
async function sbGet(table) { return []; }
async function sbInsert(table, lignes) { return lignes; }
var console = { error: function () {}, warn: function () {}, log: function () {} };

%SOURCES%

function poser(stocks, caisses) {
  BASE = {};
  ENTREPOTS_VILLES.forEach(function (e, i) {
    BASE[cleBat('republic', e.city, e.buildingId)] = {
      entrepot: { stock: JSON.parse(JSON.stringify(stocks[i] || {})), caisse: caisses[i] || 0 }
    };
  });
  BASE[cleBat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM)] = { port: { stock: {}, exportations: {} } };
}
function lire(i) {
  var e = ENTREPOTS_VILLES[i];
  return BASE[cleBat('republic', e.city, e.buildingId)].entrepot;
}
function portEtat() { return BASE[cleBat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM)].port; }

var PRIX_CER = RESSOURCES_ECONOMIE_SERVEUR.cereales.prixBase;   // 3
var PRIX_VIA = RESSOURCES_ECONOMIE_SERVEUR.viande.prixBase;     // 5

(async function () {

  // === A. EXPORT CEREALES, UN SEUL FOURNISSEUR ==========================
  poser([{ cereales: 500 }, {}, {}], [0, 0, 0]);
  var r = await traiterExportationsPortQuotidien();
  verifier('A1 le contrat cereales est bien de 225', r.exportations.cereales.contrat === 225,
           r.exportations.cereales.contrat);
  verifier('A2 225 cereales exportees', r.exportations.cereales.envoye === 225,
           r.exportations.cereales.envoye);
  verifier('A3 le stock du fournisseur est debite de 225', lire(0).stock.cereales === 275,
           lire(0).stock.cereales);
  verifier('A4 recette = 225 x prix_base', r.exportations.cereales.recette === 225 * PRIX_CER,
           r.exportations.cereales.recette + ' (attendu ' + (225 * PRIX_CER) + ')');
  verifier('A5 la caisse du FOURNISSEUR est creditee', lire(0).caisse === 225 * PRIX_CER,
           lire(0).caisse);
  verifier('A6 les deux autres entrepots ne recoivent rien',
           lire(1).caisse === 0 && lire(2).caisse === 0,
           lire(1).caisse + ' / ' + lire(2).caisse);
  verifier('A7 le prix unitaire est celui du miroir serveur',
           r.exportations.cereales.prixUnitaire === PRIX_CER, r.exportations.cereales.prixUnitaire);

  // === B. EXPORT VIANDE =================================================
  poser([{ viande: 300 }, {}, {}], [0, 0, 0]);
  r = await traiterExportationsPortQuotidien();
  verifier('B1 le contrat viande est bien de 125', r.exportations.viande.contrat === 125,
           r.exportations.viande.contrat);
  verifier('B2 125 viande exportees, stock debite', lire(0).stock.viande === 175,
           lire(0).stock.viande);
  verifier('B3 recette = 125 x prix_base et caisse creditee',
           r.exportations.viande.recette === 125 * PRIX_VIA && lire(0).caisse === 125 * PRIX_VIA,
           lire(0).caisse + ' (attendu ' + (125 * PRIX_VIA) + ')');

  // === C. REPARTITION ENTRE PLUSIEURS ENTREPOTS =========================
  // Stocks 300/150/50 = 500 au total ; 225 a exporter, au prorata du stock reel.
  poser([{ cereales: 300 }, { cereales: 150 }, { cereales: 50 }], [0, 0, 0]);
  r = await traiterExportationsPortQuotidien();
  var pris = [300 - lire(0).stock.cereales, 150 - lire(1).stock.cereales, 50 - lire(2).stock.cereales];
  verifier('C1 le total preleve vaut exactement le contrat',
           pris[0] + pris[1] + pris[2] === 225, pris.join(' + '));
  verifier('C2 la repartition suit le prorata des stocks (135/67/23 au plus fort reste)',
           pris[0] === 135 && pris[1] === 68 && pris[2] === 22 ||
           pris[0] === 135 && pris[1] === 67 && pris[2] === 23, pris.join(' / '));
  var caisses = [lire(0).caisse, lire(1).caisse, lire(2).caisse];
  verifier('C3 CHAQUE caisse recoit exactement le produit de SA fourniture',
           caisses[0] === pris[0] * PRIX_CER && caisses[1] === pris[1] * PRIX_CER
           && caisses[2] === pris[2] * PRIX_CER,
           caisses.join(' / ') + ' pour ' + pris.join(' / '));
  verifier('C4 la somme des recettes vaut quantite exportee x prix_base',
           caisses[0] + caisses[1] + caisses[2] === 225 * PRIX_CER,
           (caisses[0] + caisses[1] + caisses[2]) + ' (attendu ' + (225 * PRIX_CER) + ')');
  verifier('C5 aucun entrepot n\'est prelevede plus qu\'il ne detient',
           lire(0).stock.cereales >= 0 && lire(1).stock.cereales >= 0 && lire(2).stock.cereales >= 0,
           [lire(0).stock.cereales, lire(1).stock.cereales, lire(2).stock.cereales].join(' / '));

  // === D. STOCK NATIONAL INSUFFISANT ====================================
  poser([{ cereales: 40 }, { cereales: 10 }, {}], [0, 0, 0]);
  r = await traiterExportationsPortQuotidien();
  verifier('D1 seul le stock reellement disponible part', r.exportations.cereales.envoye === 50,
           r.exportations.cereales.envoye);
  verifier('D2 les deux entrepots sont vides, jamais negatifs',
           lire(0).stock.cereales === 0 && lire(1).stock.cereales === 0,
           lire(0).stock.cereales + ' / ' + lire(1).stock.cereales);
  verifier('D3 la recette correspond a ce qui est REELLEMENT parti',
           lire(0).caisse === 40 * PRIX_CER && lire(1).caisse === 10 * PRIX_CER,
           lire(0).caisse + ' / ' + lire(1).caisse);
  verifier('D4 le taux de satisfaction est trace', r.exportations.cereales.satisfactionPct < 100,
           r.exportations.cereales.satisfactionPct + '%');

  // === E. STOCK NATIONAL NUL (situation actuelle en production) ==========
  poser([{}, {}, {}], [166, 4.5, 0.5]);
  r = await traiterExportationsPortQuotidien();
  verifier('E1 rien a exporter : aucune recette inventee',
           r.exportations.cereales.envoye === 0 && r.exportations.cereales.recette === 0,
           JSON.stringify(r.exportations.cereales));
  verifier('E2 les caisses sont intactes',
           lire(0).caisse === 166 && lire(1).caisse === 4.5 && lire(2).caisse === 0.5,
           [lire(0).caisse, lire(1).caisse, lire(2).caisse].join(' / '));

  // === F. LES DEUX RESSOURCES DANS LA MEME PASSE ========================
  // Les credits des deux exportations doivent s'ADDITIONNER sur la meme caisse.
  poser([{ cereales: 500, viande: 300 }, {}, {}], [100, 0, 0]);
  r = await traiterExportationsPortQuotidien();
  var attendu = 100 + 225 * PRIX_CER + 125 * PRIX_VIA;
  verifier('F1 les recettes des deux exportations s\'additionnent sur la meme caisse',
           lire(0).caisse === attendu, lire(0).caisse + ' (attendu ' + attendu + ')');
  verifier('F2 les deux stocks sont debites',
           lire(0).stock.cereales === 275 && lire(0).stock.viande === 175,
           lire(0).stock.cereales + ' / ' + lire(0).stock.viande);

  // === G. MATIERE INTERDITE PAR UNE LOI =================================
  interditesSimulees = new Set(['cereales']);
  poser([{ cereales: 500, viande: 300 }, {}, {}], [0, 0, 0]);
  r = await traiterExportationsPortQuotidien();
  verifier('G1 une matiere interdite n\'est plus exportee', r.exportations.cereales.envoye === 0,
           JSON.stringify(r.exportations.cereales));
  verifier('G2 son stock reste intact et aucune recette n\'est versee',
           lire(0).stock.cereales === 500, lire(0).stock.cereales);
  verifier('G3 la viande, elle, part normalement et rapporte',
           lire(0).stock.viande === 175 && lire(0).caisse === 125 * PRIX_VIA,
           lire(0).stock.viande + ' / ' + lire(0).caisse);
  interditesSimulees = new Set();

  // === H. QUANTITES INCHANGEES PAR RAPPORT A AVANT LE LOT ===============
  // Le correctif ne devait toucher QUE l'argent : les volumes exportes doivent etre
  // exactement ceux d'avant (225 et 125, ou le stock disponible s'il est moindre).
  poser([{ cereales: 1000, viande: 1000 }, {}, {}], [0, 0, 0]);
  r = await traiterExportationsPortQuotidien();
  verifier('H1 volume cereales inchange (225)', r.exportations.cereales.envoye === 225,
           r.exportations.cereales.envoye);
  verifier('H2 volume viande inchange (125)', r.exportations.viande.envoye === 125,
           r.exportations.viande.envoye);

  // === I. LE PRIX NE VIENT JAMAIS D'UN CLIENT ===========================
  verifier('I1 le prix unitaire publie est celui du miroir serveur, pas un parametre',
           r.exportations.cereales.prixUnitaire === RESSOURCES_ECONOMIE_SERVEUR.cereales.prixBase
           && r.exportations.viande.prixUnitaire === RESSOURCES_ECONOMIE_SERVEUR.viande.prixBase,
           r.exportations.cereales.prixUnitaire + ' / ' + r.exportations.viande.prixUnitaire);
  verifier('I2 la fonction n\'accepte aucun argument de prix',
           traiterExportationsPortQuotidien.length === 0, traiterExportationsPortQuotidien.length);

  // === J. TRACE CONSERVEE DANS LE PORT ==================================
  verifier('J1 le port conserve la trace financiere de l\'export',
           portEtat().exportations.cereales.recette === 225 * PRIX_CER
           && portEtat().exportations.cereales.prixUnitaire === PRIX_CER,
           JSON.stringify(portEtat().exportations.cereales));
  verifier('J2 la caisse du PORT n\'est pas creditee (decision explicite)',
           portEtat().caisse === undefined, JSON.stringify(portEtat().caisse));

  // === J'. DEUXIEME EXECUTION LE MEME JOUR ==============================
  // L'idempotence reelle est assuree par tacheQuotidienne(), qui pose un marqueur par jour et
  // n'est pas touchee par ce lot. On verifie ici la propriete complementaire : meme appelee
  // deux fois de suite, la fonction ne peut pas inventer de recette -- le stock ayant deja
  // ete prelevee, il n'y a plus rien a vendre.
  poser([{ cereales: 225, viande: 125 }, {}, {}], [0, 0, 0]);
  var r1 = await traiterExportationsPortQuotidien();
  var caisseApres1 = lire(0).caisse;
  var r2 = await traiterExportationsPortQuotidien();
  var caisseApres2 = lire(0).caisse;
  verifier('J3 la premiere passe exporte tout et credite',
           r1.exportations.cereales.envoye === 225 && caisseApres1 === 225 * PRIX_CER + 125 * PRIX_VIA,
           caisseApres1);
  verifier('J4 une seconde passe ne credite RIEN de plus (stock deja vide)',
           r2.exportations.cereales.envoye === 0 && r2.exportations.viande.envoye === 0
           && caisseApres2 === caisseApres1,
           caisseApres1 + ' -> ' + caisseApres2);
  verifier('J5 et le stock reste a zero, jamais negatif',
           lire(0).stock.cereales === 0 && lire(0).stock.viande === 0,
           lire(0).stock.cereales + ' / ' + lire(0).stock.viande);

  // === K. COMPTE RENDU NOCTURNE DES LIVRAISONS ==========================
  // Le cron comptait un entrepot comme « traite » meme quand sa caisse vide empechait tout
  // achat. On verifie que les trois issues sont desormais distinguees -- sans qu'une
  // tresorerie insuffisante soit jamais requalifiee en erreur technique.
  //
  // Luthecia riche, PSM sans le sou, Montrouge absente de la base (echec de lecture).
  BASE = {};
  BASE[cleBat('republic', 'capitale', 'entrepot-logistique-luthecia')] =
    { entrepot: { stock: {}, caisse: 50000 } };
  BASE[cleBat('republic', 'ville_a', 'entrepot-logistique-psm')] =
    { entrepot: { stock: {}, caisse: 0 } };
  // 'ville_b' volontairement absente -> sbGetBatimentEtat renvoie null
  BASE[cleBat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM)] = { port: { stock: {}, repartition: {}, arrivages: [] } };

  var L = await livrerEntrepotsQuotidien();
  var parVille = {};
  (L.parEntrepot || []).forEach(function (x) { parVille[x.city] = x; });

  verifier('K1 l\'entrepot solvable est marque approvisionne',
           parVille.capitale && parVille.capitale.issue === 'approvisionne'
           && parVille.capitale.unites > 0,
           JSON.stringify(parVille.capitale));
  verifier('K2 l\'entrepot sans tresorerie est marque comme tel, PAS en erreur',
           parVille.ville_a && parVille.ville_a.issue === 'sans_tresorerie'
           && parVille.ville_a.unites === 0,
           JSON.stringify(parVille.ville_a));
  verifier('K3 l\'entrepot illisible est un echec TECHNIQUE, distinct',
           parVille.ville_b && parVille.ville_b.issue === 'echec_technique',
           JSON.stringify(parVille.ville_b));
  verifier('K4 les trois compteurs refletent la realite',
           L.approvisionnes === 1 && L.sansTresorerie === 1 && L.echecsTechniques === 1,
           'appro=' + L.approvisionnes + ' sansTreso=' + L.sansTresorerie
           + ' echecs=' + L.echecsTechniques);
  verifier('K5 une tresorerie insuffisante compte ses lots refuses',
           parVille.ville_a && parVille.ville_a.lotsRefusesTresorerie > 0,
           parVille.ville_a && parVille.ville_a.lotsRefusesTresorerie);
  verifier('K6 le compteur historique « entrepots » ne compte plus l\'illisible',
           L.entrepots === 2, L.entrepots);
  verifier('K7 aucune regle economique changee : l\'entrepot riche a bien PAYE',
           L.coutTotal > 0 && parVille.capitale.caisseRestante < 50000,
           'cout=' + L.coutTotal + ' caisse restante=' + parVille.capitale.caisseRestante);

  print(JSON.stringify(resultats));
})();
"""


def main():
    if not os.path.exists(JSC):
        print("JavaScriptCore introuvable", file=sys.stderr)
        return 2
    js = BANC.replace('%SOURCES%', SOURCES)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
        fh.write(js)
        chemin = fh.name
    p = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=120)
    os.unlink(chemin)
    if p.returncode != 0 or not p.stdout.strip():
        print("EXECUTION IMPOSSIBLE :\n%s\n%s" % (p.stdout[-3000:], p.stderr[-3000:]))
        return 2
    res = json.loads(p.stdout.strip().split("\n")[-1])
    for x in res:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in res if not x["ok"])
    print("\n%d controles, %d en echec." % (len(res), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
