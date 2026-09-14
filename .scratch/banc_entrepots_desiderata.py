#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DU REAPPROVISIONNEMENT PAR DESIDERATAS (14 septembre 2026).

Execute la VRAIE fonction livrerEntrepotsQuotidien du cron dans JavaScriptCore, base bouchonnee.
Verifie que l'approvisionnement automatique vise bien les stocks cibles, tient compte du transit,
repartit une tresorerie insuffisante au prorata de la VALEUR des besoins, ne paie plus jamais des
unites qui n'entrent pas, et revient aux valeurs PNJ des qu'un directeur n'est plus en poste.

Aucun appel reseau. /api/cron-minuit n'est jamais appele.
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
    extraire(C, 'livrerEntrepotsQuotidien'),
]).replace('const ', 'var ')

BANC = r"""
var resultats = [];
function verifier(nom, ok, detail) {
  resultats.push({ nom: nom, ok: !!ok, detail: String(detail === undefined ? '' : detail).slice(0, 170) });
}

var BASE = {}, TRANSITS = [], DIRECTEURS = [], JOURNAL = [];
var VILLE_ID_PORT_PSM = 'ville_a', BUILDING_ID_PORT_PSM = 'port-sainte-marie';
function cleBat(p, v, b) { return p + '_' + v + '_' + b; }

async function sbGetBatimentEtat(p, v, b) {
  var k = cleBat(p, v, b);
  return BASE[k] ? JSON.parse(JSON.stringify(BASE[k])) : null;
}
async function sbSetBatimentEtat(p, v, b, etat) { BASE[cleBat(p, v, b)] = JSON.parse(JSON.stringify(etat)); return etat; }
async function matieresInterditesRepublia() { return new Set(); }
async function sbGet(table, filtre) {
  if (table === 'entrepot_transits') return TRANSITS;
  if (table === 'personnages') return DIRECTEURS;
  return [];
}
async function sbInsert(table, lignes) { if (table === 'entrepot_journal') JOURNAL = JOURNAL.concat(lignes); return lignes; }
var console = { error: function () {}, warn: function () {}, log: function () {} };

%SOURCES%

function poser(stocks, caisses, desiderata, desiderataPar) {
  BASE = {}; TRANSITS = []; JOURNAL = [];
  ENTREPOTS_VILLES.forEach(function (e, i) {
    var ent = { stock: JSON.parse(JSON.stringify(stocks[i] || {})), caisse: caisses[i] || 0 };
    if (desiderata && desiderata[i]) { ent.desiderata = desiderata[i]; ent.desiderataPar = desiderataPar; }
    BASE[cleBat('republic', e.city, e.buildingId)] = { entrepot: ent };
  });
  BASE[cleBat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM)] = { port: { stock: {}, repartition: {}, arrivages: [] } };
}
function lire(i) { var e = ENTREPOTS_VILLES[i]; return BASE[cleBat('republic', e.city, e.buildingId)].entrepot; }

(async function () {

  // === A. LES VALEURS PNJ SONT LES ANCIENS PLAFONDS ======================
  verifier('A1 le desiderata PNJ des cereales vaut l\'ancien plafond (150)',
           DESIDERATA_PNJ_DEFAUT.cereales === 150, DESIDERATA_PNJ_DEFAUT.cereales);
  verifier('A2 celui du bois vaut 750, celui du metal 200',
           DESIDERATA_PNJ_DEFAUT.bois === 750 && DESIDERATA_PNJ_DEFAUT.metal === 200,
           DESIDERATA_PNJ_DEFAUT.bois + ' / ' + DESIDERATA_PNJ_DEFAUT.metal);
  verifier('A3 la capacite d\'entrepot est bien 5 000, distincte du plafond des ressources',
           CAPACITE_ENTREPOT_PAR_RESSOURCE === 5000 && RESSOURCES_ECONOMIE_SERVEUR.cereales.plafond === 150,
           CAPACITE_ENTREPOT_PAR_RESSOURCE + ' vs ' + RESSOURCES_ECONOMIE_SERVEUR.cereales.plafond);

  // === B. ENTREPOT PNJ : COMPORTEMENT D'AVANT LE LOT =====================
  poser([{}, {}, {}], [100000, 0, 0], null, null);
  DIRECTEURS = [];
  var r = await livrerEntrepotsQuotidien();
  verifier('B1 un entrepot PNJ solvable est approvisionne', lire(0).stock.cereales > 0, JSON.stringify(lire(0).stock).slice(0, 120));
  verifier('B2 il ne depasse jamais son objectif PNJ',
           (lire(0).stock.cereales || 0) <= 150 && (lire(0).stock.viande || 0) <= 125,
           'cereales=' + lire(0).stock.cereales + ' viande=' + lire(0).stock.viande);
  verifier('B3 le rythme quotidien reste borne a 800 unites',
           r.unitesLivrees <= 800 * 3, r.unitesLivrees);

  // === C. DESIDERATAS D'UN DIRECTEUR PJ ==================================
  DIRECTEURS = [{ name: 'zzdir', poste: { id: 'directeur_entrepot', city: 'capitale' } }];
  poser([{}, {}, {}], [100000, 0, 0], [{ cereales: 3000, viande: 0 }], 'zzdir');
  r = await livrerEntrepotsQuotidien();
  verifier('C1 l\'objectif PJ (3 000) remplace la valeur PNJ (150)',
           lire(0).stock.cereales > 150, lire(0).stock.cereales);
  verifier('C2 un objectif a 0 coupe le reapprovisionnement de cette ressource',
           !(lire(0).stock.viande > 0), lire(0).stock.viande);
  verifier('C3 les ressources non citees gardent la valeur PNJ',
           (lire(0).stock.textile || 0) > 0 && (lire(0).stock.textile || 0) <= 125,
           lire(0).stock.textile);

  // === D. UN OBJECTIF A 0 NE DETRUIT NI NE VEND LE STOCK EXISTANT ========
  poser([{ viande: 400 }, {}, {}], [100000, 0, 0], [{ viande: 0 }], 'zzdir');
  r = await livrerEntrepotsQuotidien();
  verifier('D le stock deja present est conserve intact', lire(0).stock.viande === 400, lire(0).stock.viande);

  // === E. LE TRANSIT COMPTE DANS LE BESOIN ==============================
  poser([{ cereales: 2500 }, {}, {}], [100000, 0, 0], [{ cereales: 3000 }], 'zzdir');
  TRANSITS = [{ destination_id: 'republic_capitale_entrepot-logistique-luthecia',
                ressource: 'cereales', quantite: 1000 }];
  r = await livrerEntrepotsQuotidien();
  verifier('E objectif 3 000, stock 2 500, 1 000 en route : aucun achat supplementaire',
           lire(0).stock.cereales === 2500, lire(0).stock.cereales);

  // === F. TRESORERIE INSUFFISANTE : PRORATA DE LA VALEUR ================
  // Deux besoins de 100 unites, l'un a 1,5 FR (cereales) l'autre a 7,5 FR (metal).
  // Budget 450 FR pour 900 FR de besoins : chacun doit etre servi a 50 %.
  poser([{}, {}, {}], [450, 0, 0], [{ cereales: 100, metal: 100 }], 'zzdir');
  TRANSITS = [];
  // On neutralise les autres ressources en mettant leur objectif a 0.
  var d0 = { cereales: 100, metal: 100 };
  Object.keys(RESSOURCES_ECONOMIE_SERVEUR).forEach(function (k) { if (d0[k] === undefined) d0[k] = 0; });
  poser([{}, {}, {}], [450, 0, 0], [d0], 'zzdir');
  r = await livrerEntrepotsQuotidien();
  var cer = lire(0).stock.cereales || 0, met = lire(0).stock.metal || 0;
  verifier('F1 les deux besoins sont servis dans la MEME proportion (50 %)',
           cer === 50 && met === 50, 'cereales=' + cer + ' metal=' + met);
  verifier('F2 la depense ne depasse jamais la tresorerie',
           lire(0).caisse >= 0 && lire(0).caisse <= 450, lire(0).caisse);
  // Seul l'entrepot 0 a de la tresorerie (450 FR) : il est servi partiellement, donc
  // APPROVISIONNE. Les deux autres n'ont pas un franc : sans_tresorerie, jamais une erreur
  // technique. C'est exactement la distinction que le compte rendu doit rendre.
  verifier('F3 servi partiellement = approvisionne ; sans le sou = sans_tresorerie ; aucune erreur',
           r.approvisionnes === 1 && r.sansTresorerie === 2 && r.echecsTechniques === 0,
           JSON.stringify({ appro: r.approvisionnes, sansTreso: r.sansTresorerie, echecs: r.echecsTechniques }));
  var d0Detail = (r.parEntrepot || []).find(function (x) { return x.city === 'capitale'; });
  verifier('F4 le detail par entrepot signale les lots non finances',
           d0Detail && d0Detail.issue === 'approvisionne' && d0Detail.lotsRefusesTresorerie > 0,
           JSON.stringify(d0Detail));

  // === G. ON NE PAIE PLUS CE QUI N'ENTRE PAS ============================
  // Stock a 4 990 sur 5 000 : le besoin doit etre borne a 10 unites, pas davantage.
  var d1 = {}; Object.keys(RESSOURCES_ECONOMIE_SERVEUR).forEach(function (k) { d1[k] = 0; });
  d1.cereales = 5000;
  poser([{ cereales: 4990 }, {}, {}], [100000, 0, 0], [d1], 'zzdir');
  r = await livrerEntrepotsQuotidien();
  verifier('G1 la capacite borne l\'achat : on atteint 5 000, jamais au-dela',
           lire(0).stock.cereales === 5000, lire(0).stock.cereales);
  verifier('G2 on n\'a paye que les 10 unites reellement entrees (10 x 1,5 = 15 FR)',
           Math.round((100000 - lire(0).caisse) * 100) / 100 === 15, 100000 - lire(0).caisse);

  // === H. RETOUR AUX VALEURS PNJ AU DEPART DU DIRECTEUR =================
  poser([{}, {}, {}], [100000, 0, 0], [{ cereales: 3000 }], 'zzdir');
  DIRECTEURS = [];   // le directeur n'est plus en poste
  r = await livrerEntrepotsQuotidien();
  verifier('H les desideratas du PJ sont abandonnes, la valeur PNJ (150) reprend',
           lire(0).stock.cereales <= 150, lire(0).stock.cereales);

  // === I. REGISTRE ======================================================
  poser([{}, {}, {}], [100000, 0, 0], null, null);
  DIRECTEURS = [];
  r = await livrerEntrepotsQuotidien();
  verifier('I1 chaque achat automatique laisse une trace au registre',
           JOURNAL.length > 0 && JOURNAL.every(function (l) { return l.operation === 'approvisionnement_auto'; }),
           JOURNAL.length + ' lignes');
  verifier('I2 la trace porte la ressource, la quantite, le prix et le montant',
           JOURNAL[0].ressource && JOURNAL[0].quantite > 0 && JOURNAL[0].prix_unitaire > 0
           && JOURNAL[0].montant > 0 && JOURNAL[0].statut === 'livre',
           JSON.stringify(JOURNAL[0]).slice(0, 150));

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
