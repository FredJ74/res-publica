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

Sortie : les triples (fn, pa, cost) DISTINCTS. On garde tous les couples declares
pour un meme ordre, parce que dix ordres coutent legitimement des prix differents
selon le lieu (acheter_terrain va de 3 500 a 36 000 FR).

Usage :  python3 .scratch/generer_ordres_couts.py          -> resume
         python3 .scratch/generer_ordres_couts.py --sql    -> VALUES SQL
         python3 .scratch/generer_ordres_couts.py --json   -> JSON
"""
import json, os, subprocess, sys, tempfile

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


def triples(brut):
    return sorted({(o["fn"], int(o["pa"]), int(o["cost"])) for o in brut})


def main():
    brut = extraire()
    t = triples(brut)
    if "--sql" in sys.argv:
        print(",\n  ".join("('%s',%d,%d)" % (fn.replace("'", "''"), pa, c) for fn, pa, c in t))
        return 0
    if "--json" in sys.argv:
        print(json.dumps([{"fn": fn, "pa": pa, "cost": c} for fn, pa, c in t]))
        return 0
    fns = {x[0] for x in t}
    variables = {fn for fn in fns if len([1 for x in t if x[0] == fn]) > 1}
    print("declarations lues : %d" % len(brut))
    print("ordres distincts  : %d" % len(fns))
    print("triples distincts : %d" % len(t))
    print("ordres a cout variable selon le lieu : %d  (%s)"
          % (len(variables), ', '.join(sorted(variables))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
