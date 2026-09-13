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

Usage :  python3 .scratch/generer_ordres_couts.py            -> resume
         python3 .scratch/generer_ordres_couts.py --sql      -> VALUES SQL
         python3 .scratch/generer_ordres_couts.py --json     -> JSON
         python3 .scratch/generer_ordres_couts.py --empreinte-> empreinte stable
"""
import hashlib, json, os, re, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
  }); }); }
Object.keys(g.W||{}).forEach(function(p){ var v=g.W[p]||{};
  Object.keys(v).forEach(function(x){ if(v[x]&&v[x].buildingContext) ctx(v[x].buildingContext); });
  if(v.buildingContext) ctx(v.buildingContext); });
Object.keys(g.T||{}).forEach(function(k){
  (Array.isArray((g.T[k]||{}).ordres)?g.T[k].ordres:[]).forEach(function(o){ push(o,'orga'); }); });
print(JSON.stringify(out));
"""


def extraire():
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
        f.write(EXTRACTEUR)
        chemin = f.name
    try:
        r = subprocess.run([JSC, chemin], capture_output=True, text=True, cwd=RACINE, timeout=120)
    finally:
        os.unlink(chemin)
    if r.returncode != 0 or not r.stdout.strip():
        raise SystemExit("extraction impossible :\n" + r.stdout + r.stderr)
    return json.loads(r.stdout.strip().splitlines()[-1])


def ordres_hors_data():
    """Ordres declares en dur dans un module, hors data.js. Ils portent toujours un
    `label` : c'est ce qui les distingue d'une comparaison `fn === '...'` ou d'une
    simple mention. Expression reguliere assumee ici -- ces fichiers ne sont pas
    chargeables isolement, et la forme est stable."""
    trouves = set()
    for f in sorted(os.listdir(RACINE)):
        if not f.endswith(".js") or f == "data.js":
            continue
        chemin = os.path.join(RACINE, f)
        if not os.path.isfile(chemin):
            continue
        src = open(chemin, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r"\{\s*fn\s*:\s*'([a-z0-9_]+)'\s*,([^{}]{0,400}?)\}", src):
            fn, corps = m.group(1), m.group(2)
            if "label" not in corps:
                continue
            pa = re.search(r"\bpa\s*:\s*(-?\d+)", corps)
            co = re.search(r"\bcost\s*:\s*(-?\d+)", corps)
            trouves.add((fn, int(pa.group(1)) if pa else 0, int(co.group(1)) if co else 0))
    return trouves


def triples(brut):
    t = {(o["fn"], int(o["pa"]), int(o["cost"])) for o in brut}
    t |= ordres_hors_data()
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
    fns = {x[0] for x in t}
    variables = {fn for fn in fns if len([1 for x in t if x[0] == fn]) > 1}
    print("declarations lues : %d" % len(brut))
    print("ordres distincts  : %d" % len(fns))
    print("triples distincts : %d  (gratuits compris)" % len(t))
    print("dont declares hors data.js : %d" % len(ordres_hors_data() - {
        (o["fn"], int(o["pa"]), int(o["cost"])) for o in brut}))
    print("empreinte du miroir : %s" % empreinte(t))
    print("ordres a cout variable selon le lieu : %d  (%s)"
          % (len(variables), ', '.join(sorted(variables))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
