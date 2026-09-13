#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES CHANTIERS (chantier C, 14 septembre 2026).

Meme doctrine que les autres miroirs : le serveur doit connaitre le gabarit REEL d'un chantier
pour pouvoir le creer lui-meme, sinon le navigateur reste libre d'annoncer le cout total qu'il
veut -- et donc l'apport minimal de 35 %, et donc ce qu'il paie.

Le gabarit d'un chantier de construction est entierement determine par son PALIER : duree,
cout total, part materiaux, part travail, heures totales. On ne recopie pas ces formules en SQL,
on les EXECUTE dans JavaScriptCore sur le vrai plateau-chantiers.js et on capture le resultat.

On capture aussi le besoin en materiaux par journee de construction : il ne depend que du
numero de jour (cycle du metal sur 3 jours), il est donc enumerable.

Sorties :
  python3 .scratch/generer_miroirs_chantiers.py             -> resume
  python3 .scratch/generer_miroirs_chantiers.py --sql       -> les INSERT
  python3 .scratch/generer_miroirs_chantiers.py --empreinte -> empreinte stable

REJOUER apres toute modification de DUREES_CONSTRUCTION, des couts, des seuils de financement
ou du panier de materiaux.
"""
import hashlib, json, os, subprocess, sys

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXTRACTEUR = r"""
// NIVEAUX_CONSTRUCTION vit dans plateau-justice-economie.js, les durees et couts dans
// plateau-chantiers.js : les oublier donnerait un miroir vide, pas une erreur.
var src = readFile('data.js') + "\n" + readFile('plateau-chantiers.js')
        + "\n" + readFile('plateau-justice-economie.js');
var g = (new Function(src + "\n; return {"
  + " NIV: typeof NIVEAUX_CONSTRUCTION!=='undefined'?NIVEAUX_CONSTRUCTION:null,"
  + " creer: typeof creerChantierConstruction!=='undefined'?creerChantierConstruction:null,"
  + " mini: typeof montantMinimalLancement!=='undefined'?montantMinimalLancement:null,"
  + " besoin: typeof materiauxDuJourConstruction!=='undefined'?materiauxDuJourConstruction:null,"
  + " taux: typeof CHANTIER_TAUX_HORAIRE!=='undefined'?CHANTIER_TAUX_HORAIRE:null,"
  + " seuils: typeof SEUILS_FINANCEMENT_CONSTRUCTION!=='undefined'?SEUILS_FINANCEMENT_CONSTRUCTION:null,"
  + " seqMetal: typeof SEQUENCE_METAL_CONSTRUCTION!=='undefined'?SEQUENCE_METAL_CONSTRUCTION:null"
  + "};"))();

var out = { paliers: [], besoins_jour: [], constantes: {} };

Object.keys(g.NIV || {}).sort().forEach(function (palier) {
  var c = g.creer(palier, 1);
  if (!c) { return; }
  out.paliers.push({
    palier: palier,
    label: (g.NIV[palier] && g.NIV[palier].label) || palier,
    duree_jours: c.dureeJours,
    cout_total: c.coutTotal,
    cout_materiaux: c.coutMateriaux,
    cout_travail: c.coutTravail,
    heures_totales: c.heuresTotales,
    apport_minimal: g.mini(c.coutTotal),
    gabarit: c
  });
});

// Le besoin en materiaux d'une journee de CONSTRUCTION ne depend que du numero de jour : le
// metal suit un cycle court, bois et minerai sont constants. On enumere un cycle complet.
var cycle = (g.seqMetal && g.seqMetal.length) ? g.seqMetal.length : 3;
for (var j = 1; j <= cycle; j++) {
  var b = g.besoin(j);
  out.besoins_jour.push({ position_cycle: j, bois: b.bois, minerai: b.minerai, metal: b.metal });
}
out.constantes = { chantier_taux_horaire: g.taux, cycle_metal: cycle,
                   seuil_demarrage_pct: (g.seuils && g.seuils.demarrage) || null };
print(JSON.stringify(out));
"""


def extraire():
    if not os.path.exists(JSC):
        print("JavaScriptCore introuvable : %s" % JSC, file=sys.stderr)
        sys.exit(2)
    p = subprocess.run([JSC, "-e", EXTRACTEUR], cwd=RACINE,
                       capture_output=True, text=True, timeout=120)
    if p.returncode != 0 or not p.stdout.strip():
        print("Extraction impossible :\n%s\n%s" % (p.stdout[-3000:], p.stderr[-3000:]),
              file=sys.stderr)
        sys.exit(2)
    return json.loads(p.stdout.strip().split("\n")[-1])


def litteral(x):
    if x is None:
        return "NULL"
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, (int, float)):
        return repr(x)
    if isinstance(x, str):
        return "'" + x.replace("'", "''") + "'"
    return "'" + json.dumps(x, sort_keys=True, ensure_ascii=False).replace("'", "''") + "'::jsonb"


def empreinte(d):
    return hashlib.sha256(json.dumps(d, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":")).encode()).hexdigest()[:16]


def sql(d):
    L = ["DELETE FROM public.chantiers_paliers;",
         "INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total,"
         " cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit) VALUES"]
    L.append(",\n".join("  (%s, %s, %s, %s, %s, %s, %s, %s, %s)" % (
        litteral(p["palier"]), litteral(p["label"]), litteral(p["duree_jours"]),
        litteral(p["cout_total"]), litteral(p["cout_materiaux"]), litteral(p["cout_travail"]),
        litteral(p["heures_totales"]), litteral(p["apport_minimal"]), litteral(p["gabarit"]))
        for p in d["paliers"]) + ";")
    L.append("\nDELETE FROM public.chantiers_besoins_jour;")
    L.append("INSERT INTO public.chantiers_besoins_jour (position_cycle, bois, minerai, metal) VALUES")
    L.append(",\n".join("  (%s, %s, %s, %s)" % (litteral(b["position_cycle"]), litteral(b["bois"]),
             litteral(b["minerai"]), litteral(b["metal"])) for b in d["besoins_jour"]) + ";")
    L.append("\nINSERT INTO public.entreprises_constantes (cle, valeur) VALUES")
    L.append(",\n".join("  (%s, %s)" % (litteral(k), litteral(v))
             for k, v in sorted(d["constantes"].items()) if v is not None)
             + "\nON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;")
    return "\n".join(L)


def main():
    d = extraire()
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg == "--json":
        print(json.dumps(d, indent=2, ensure_ascii=False, sort_keys=True))
    elif arg == "--sql":
        print(sql(d))
    elif arg == "--empreinte":
        print(empreinte(d))
    else:
        print("paliers de construction : %d" % len(d["paliers"]))
        for p in d["paliers"]:
            print("  %-14s %-26s duree=%-4s cout=%-8s apport min=%s"
                  % (p["palier"], p["label"][:26], p["duree_jours"], p["cout_total"],
                     p["apport_minimal"]))
        print("besoins par journee     : %d positions de cycle" % len(d["besoins_jour"]))
        for b in d["besoins_jour"]:
            print("  jour %%%d : bois=%s minerai=%s metal=%s"
                  % (b["position_cycle"], b["bois"], b["minerai"], b["metal"]))
        print("constantes              : %s" % json.dumps(d["constantes"]))
        print("empreinte               : %s" % empreinte(d))
    return 0


if __name__ == "__main__":
    sys.exit(main())
