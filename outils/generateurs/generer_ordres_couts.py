#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES COUTS D'ORDRE (chantier C, 13 septembre 2026).

Le serveur doit savoir ce qu'un ordre coute REELLEMENT, sinon le navigateur peut
annoncer pa:0/cost:0 et tout obtenir gratuitement. Ce miroir n'est pas saisi a la
main : il est EXTRAIT du vrai data.js, en le CHARGEANT dans JavaScriptCore --
jamais par expression reguliere, qui manquerait les declarations imbriquees.

Sources parcourues, dans l'ordre ou le jeu les fusionne :
  * BUILDINGS[b].rooms[r].orders
  * WORLD[pays][ville].buildingContext[b].orders et .roomOverrides[r].orders
  * TYPES_ORGANISATIONS[t].ordres  (le menu dynamique des organisations)
  * les litteraux d'ordre declares DANS LES AUTRES FICHIERS .js de la racine --
    quatre ordres de l'etat civil vivent dans plateau-politique.js et nulle part
    ailleurs. Les oublier, avec un miroir fail-closed, reviendrait a les casser.

Sortie : les triples (fn, pa, cost) DISTINCTS, GRATUITS COMPRIS. Miroiter aussi
les ordres gratuits est ce qui permet au serveur de distinguer « connu et
gratuit » de « inconnu » -- et donc de refuser le second sans refuser le premier.
On garde tous les couples declares pour un meme ordre, parce que dix ordres
coutent legitimement des prix differents selon le lieu (acheter_terrain va de
3 500 a 36 000 FR).

Usage :  python3 outils/generateurs/generer_ordres_couts.py            -> resume
         python3 outils/generateurs/generer_ordres_couts.py --sql      -> VALUES SQL
         python3 outils/generateurs/generer_ordres_couts.py --json     -> JSON
         python3 outils/generateurs/generer_ordres_couts.py --empreinte-> empreinte stable
"""
import hashlib, json, os, re, subprocess, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from moteur_javascript import choisir_moteur, commande_moteur
JSC = choisir_moteur(['/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc'])
if not JSC:
    raise SystemExit('Aucun moteur JavaScript réel disponible (JavaScriptCore ou Node).')
def _racine():
    """La racine du depot, trouvee en REMONTANT jusqu'a data.js, et non en
    comptant des niveaux de repertoire. Le comptage a casse les HUIT generateurs
    au chantier 2H : ils vivaient dans .scratch/, ou deux dirname suffisaient ;
    passes dans outils/generateurs/, les deux memes dirname rendaient outils/, et
    chacun cherchait outils/data.js. Aucun ne pouvait plus charger le jeu --
    c'est pour cela que onze miroirs ont ete semes par copie de la base au
    chantier 2E au lieu d'etre regeneres. Un repere ne se decale pas."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()

EXTRACTEUR_RESSOURCES = r"""
var g = (new Function(readFile('data.js') + "\n; return { R: RESSOURCES_ECONOMIE };"))();
var out = [];
Object.keys(g.R).sort().forEach(function (k) {
  var r = g.R[k];
  out.push({ cle: k, prix_base: r.prixBase,
             prix_achat_fournisseur: (r.prixAchatFournisseur === undefined) ? null : r.prixAchatFournisseur,
             plafond: (r.plafond === undefined) ? null : r.plafond,
             source: r.source || '' });
});
print(JSON.stringify(out));
"""

EXTRACTEUR = r"""
var src = readFile('data.js');
var g = (new Function(src + "\n; return { B: typeof BUILDINGS!=='undefined'?BUILDINGS:null,"
  + " W: typeof WORLD!=='undefined'?WORLD:null,"
  + " T: typeof TYPES_ORGANISATIONS!=='undefined'?TYPES_ORGANISATIONS:null };"))();
var out = [];
function push(o, s) { if (o && o.fn) out.push({ fn:o.fn, pa:(typeof o.pa==='number')?o.pa:0,
                                                cost:(typeof o.cost==='number')?o.cost:0, s:s }); }
Object.keys(g.B||{}).forEach(function (bid) {
  var rooms = (g.B[bid]&&g.B[bid].rooms)||{};
  Object.keys(rooms).forEach(function (rid) {
    (Array.isArray(rooms[rid].orders)?rooms[rid].orders:[]).forEach(function(o){ push(o,'room'); });
  });
});
function ctx(cs){ Object.keys(cs||{}).forEach(function(bid){ var c=cs[bid]||{};
  (Array.isArray(c.orders)?c.orders:[]).forEach(function(o){ push(o,'ctx'); });
  Object.keys(c.roomOverrides||{}).forEach(function(rid){
    (Array.isArray((c.roomOverrides[rid]||{}).orders)?c.roomOverrides[rid].orders:[]).forEach(function(o){ push(o,'override'); });
  });
  // roomsExtra : ANGLE MORT CORRIGE LE 5 OCTOBRE 2026. Une piece qui n'existe
  // que dans une ville -- l'agence Grobras du centre d'affaires de Luthecia --
  // est declaree ici et nulle part ailleurs. Le generateur ne la lisait pas :
  // ses ordres etaient donc absents du miroir, et payer_ordre les aurait
  // refuses avec `cout_non_declare`.
  // Le trou est reste invisible deux semaines parce que les 17 autres fns
  // vivant dans roomsExtra sont aussi declarees dans BUILDINGS[].rooms avec le
  // MEME triplet : elles entraient dans le miroir par l'autre porte. Les deux
  // ordres d'embauche de Grobras sont les premiers a n'exister qu'ici.
  Object.keys(c.roomsExtra||{}).forEach(function(rid){
    (Array.isArray((c.roomsExtra[rid]||{}).orders)?c.roomsExtra[rid].orders:[]).forEach(function(o){ push(o,'roomsExtra'); });
  }); }); }
Object.keys(g.W||{}).forEach(function(p){ var v=g.W[p]||{};
  Object.keys(v).forEach(function(x){ if(v[x]&&v[x].buildingContext) ctx(v[x].buildingContext); });
  if(v.buildingContext) ctx(v.buildingContext); });
Object.keys(g.T||{}).forEach(function(k){
  (Array.isArray((g.T[k]||{}).ordres)?g.T[k].ordres:[]).forEach(function(o){ push(o,'orga'); }); });
print(JSON.stringify(out));
"""


def executer_jsc(script):
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
        f.write(script)
        chemin = f.name
    try:
        r = subprocess.run(commande_moteur(JSC, chemin), capture_output=True, text=True, cwd=RACINE, timeout=120)
    finally:
        os.unlink(chemin)
    if r.returncode != 0 or not r.stdout.strip():
        raise SystemExit("extraction impossible :\n" + r.stdout + r.stderr)
    return json.loads(r.stdout.strip().splitlines()[-1])


def extraire():
    return executer_jsc(EXTRACTEUR)


def ressources():
    """Prix des ressources, extraits de RESSOURCES_ECONOMIE. Meme doctrine que les
    couts d'ordre : le serveur ne doit jamais porter un tarif perime."""
    return executer_jsc(EXTRACTEUR_RESSOURCES)


def nombre(x):
    """Representation stable d'un nombre : 3 et 3.0 doivent donner la meme
    empreinte des deux cotes, sinon un prix entier cote JS et numeric cote
    Postgres feraient diverger deux miroirs pourtant identiques."""
    if x is None:
        return ""
    f = float(x)
    return str(int(f)) if f == int(f) else repr(f)


def empreinte_ressources(rs):
    brut = "\n".join("%s|%s|%s|%s|%s" % (r["cle"], nombre(r["prix_base"]),
                                         nombre(r["prix_achat_fournisseur"]),
                                         nombre(r["plafond"]), r["source"] or "")
                     for r in sorted(rs, key=lambda r: r["cle"]))
    return hashlib.md5(brut.encode("utf-8")).hexdigest()[:16]


DECLARATIONS_SERVEUR = (
    '20261027110100_crimes_actes_serveur.sql',
    '20261027120000_vol_empoisonnement_serveur.sql',
    '20261027150000_informateurs_serveur.sql',
    '20261027160000_marche_noir_serveur.sql',
    '20261025060000_bne_annonces.sql',
    '20261025120100_indice_diplomatique_actions_nationales.sql',
    '20261027180000_inventaire_achats_serveur.sql',
)

def diagnostic_modules():
    return json.loads(subprocess.check_output(['node',os.path.join(RACINE,'outils/generateurs/extraire-ordres-modules.cjs')],cwd=RACINE,text=True))

def ordres_hors_data():
    """Déclarations réelles des modules et tarifs authored désormais serveur.

    Un paramètre dynamique n'est jamais transformé implicitement en zéro.
    Les entrées SQL proviennent de déclarations appliquées identifiées ; pas
    d'un export de table ni d'un parcours indistinct de toutes les migrations.
    """
    trouves={(x['fn'],x['pa'],x['cost']) for x in diagnostic_modules()['litteraux']}
    for nom in DECLARATIONS_SERVEUR:
        texte=open(os.path.join(RACINE,'historique/migrations-appliquees',nom),encoding='utf-8').read()
        blocs=re.findall(r'INSERT INTO public\.ordres_couts \(fn, pa, cost\) VALUES(.*?)ON CONFLICT DO NOTHING;',texte,re.S)
        if len(blocs)!=1:raise ValueError('Déclaration coûts serveur absente ou ambiguë : '+nom)
        motif=r"\('([a-z0-9_#]+)',\s*(\d+),\s*(\d+)\)"
        valeurs=re.findall(motif,blocs[0])
        if not valeurs or re.sub(motif,'',blocs[0]).strip(' ,\n\r\t'):
            raise ValueError('Déclaration de coûts non littérale : '+nom)
        trouves.update((fn,int(pa),int(cout)) for fn,pa,cout in valeurs)
    return trouves

def ordres_fractionnes(t):
    """Même projection que la migration de corruption : PA puis coût au succès."""
    nom='20261027130000_crimes_ordres_detection.sql'
    texte=open(os.path.join(RACINE,'historique/migrations-appliquees',nom),encoding='utf-8').read()
    morceaux=[]
    for suffixe,colonnes in [('tentative','pa, 0'),('reussite','0, cost')]:
        motif=r"SELECT DISTINCT fn \|\| '#"+suffixe+"', "+colonnes+r" FROM public\.ordres_couts\s+WHERE fn IN \(([^)]*)\)"
        m=re.findall(motif,texte)
        if len(m)!=1:raise ValueError('Projection de coûts absente ou ambiguë : '+suffixe)
        noms=re.findall(r"'([a-z0-9_]+)'",m[0]);reste=re.sub(r"'([a-z0-9_]+)'",'',m[0]).strip(' ,')
        if not noms or reste:raise ValueError('Liste des ordres fractionnés non littérale')
        morceaux.extend((fn+'#'+suffixe,pa if suffixe=='tentative' else 0,cost if suffixe=='reussite' else 0) for fn,pa,cost in t if fn in noms)
    return set(morceaux)


def triples(brut):
    t = {(o["fn"], int(o["pa"]), int(o["cost"])) for o in brut}
    t |= ordres_hors_data()
    t |= ordres_fractionnes(t)
    return sorted(t)


def empreinte(t):
    """Empreinte stable du miroir attendu. Le banc la compare a celle calculee sur
    le contenu REEL de la table : toute declaration ajoutee dans data.js sans
    regeneration du miroir fait diverger les deux et sort en echec."""
    # md5 et non sha256 : Postgres l'a en natif, sans extension a installer,
    # ce qui permet a la base de recalculer la MEME empreinte sans dependance.
    brut = "\n".join("%s|%d|%d" % x for x in t)
    return hashlib.md5(brut.encode("utf-8")).hexdigest()[:16]


def main():
    brut = extraire()
    t = triples(brut)
    if "--sql" in sys.argv:
        print(",\n  ".join("('%s',%d,%d)" % (fn.replace("'", "''"), pa, c) for fn, pa, c in t))
        return 0
    if "--json" in sys.argv:
        print(json.dumps([{"fn": fn, "pa": pa, "cost": c} for fn, pa, c in t]))
        return 0
    if "--empreinte" in sys.argv:
        print(empreinte(t))
        return 0
    if "--ressources-sql" in sys.argv:
        print(",".join("('%s',%s,%s,%s,'%s')" % (
            r["cle"], nombre(r["prix_base"]),
            nombre(r["prix_achat_fournisseur"]) or "null",
            nombre(r["plafond"]) or "null", r["source"] or "")
            for r in ressources()))
        return 0
    if "--ressources-empreinte" in sys.argv:
        print(empreinte_ressources(ressources()))
        return 0
    fns = {x[0] for x in t}
    variables = {fn for fn in fns if len([1 for x in t if x[0] == fn]) > 1}
    print("declarations lues : %d" % len(brut))
    print("ordres distincts  : %d" % len(fns))
    print("triples distincts : %d  (gratuits compris)" % len(t))
    print("dont declares hors data.js : %d" % len(ordres_hors_data() - {
        (o["fn"], int(o["pa"]), int(o["cost"])) for o in brut}))
    print("empreinte du miroir : %s" % empreinte(t))
    rs = ressources()
    print("ressources economiques : %d  | empreinte : %s" % (len(rs), empreinte_ressources(rs)))
    print("ordres a cout variable selon le lieu : %d  (%s)"
          % (len(variables), ', '.join(sorted(variables))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
