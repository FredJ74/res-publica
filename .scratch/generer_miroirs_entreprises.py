#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DES MIROIRS D'ENTREPRISE (chantier C, phase 3, 13 septembre 2026).

Meme doctrine que generer_ordres_couts.py : le serveur doit connaitre le catalogue REEL
(types de commerce, dotations de depart, recettes, plafonds), sinon le navigateur reste
libre de se fabriquer une entreprise avec la caisse qu'il veut -- c'est exactement ce que
permet aujourd'hui chargerEntreprise(), qui cree une armurerie a 20 000 FR sur simple
demande d'un client.

Le catalogue n'est pas recopie a la main : il est CHARGE dans JavaScriptCore depuis les
vrais fichiers du jeu (data.js + plateau-actions-illegales-rumeurs.js), puis serialise.
Les dotations pilotes sont des FONCTIONS : on les execute sur un defautCommerce() vierge
et on capture leur effet reel, plutot que de relire ce qu'elles sont censees faire.

Sorties :
  python3 .scratch/generer_miroirs_entreprises.py             -> resume lisible
  python3 .scratch/generer_miroirs_entreprises.py --sql       -> les INSERT des 4 miroirs
  python3 .scratch/generer_miroirs_entreprises.py --json      -> JSON brut
  python3 .scratch/generer_miroirs_entreprises.py --empreinte -> empreinte stable

REJOUER apres toute modification de RECETTES_PRODUCTION, RECETTES_ALIMENTAIRES,
DOTATIONS_COMMERCE_PILOTE ou BUILDING_COMMERCE_TYPE : sinon le serveur refusera un
commerce legitime (miroir fail-closed).
"""
import hashlib, json, os, subprocess, sys

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXTRACTEUR = r"""
// Le fichier des commerces reference des symboles de data.js : on charge les deux dans le
// MEME contexte, exactement comme le navigateur le fait avec ses balises <script>.
var src = readFile('data.js') + "\n" + readFile('plateau-actions-illegales-rumeurs.js');
var g = (new Function(src + "\n; return {"
  + " RP: typeof RECETTES_PRODUCTION!=='undefined'?RECETTES_PRODUCTION:null,"
  + " RA: typeof RECETTES_ALIMENTAIRES!=='undefined'?RECETTES_ALIMENTAIRES:null,"
  + " PM: typeof PRODUITS_MARCHE!=='undefined'?PRODUITS_MARCHE:null,"
  + " BCT: typeof BUILDING_COMMERCE_TYPE!=='undefined'?BUILDING_COMMERCE_TYPE:null,"
  + " DOT: typeof DOTATIONS_COMMERCE_PILOTE!=='undefined'?DOTATIONS_COMMERCE_PILOTE:null,"
  + " defC: typeof defautCommerce!=='undefined'?defautCommerce:null,"
  + " defA: typeof defautArmurerie!=='undefined'?defautArmurerie:null,"
  + " SPA: typeof SALAIRE_PRODUCTION_ARMURERIE!=='undefined'?SALAIRE_PRODUCTION_ARMURERIE:null,"
  + " PPA: typeof PA_PRODUCTION_ARMURERIE!=='undefined'?PA_PRODUCTION_ARMURERIE:null,"
  + " CMO: typeof COUT_MAIN_OEUVRE_PA_ALIMENTAIRE!=='undefined'?COUT_MAIN_OEUVRE_PA_ALIMENTAIRE:null,"
  + " SMC: typeof STOCK_MAX_COMMERCE!=='undefined'?STOCK_MAX_COMMERCE:null"
  + "};"))();

var out = { recettes_production: [], recettes_commerce: [], types_commerce: [],
            dotations: [], armureries: [], constantes: {} };

Object.keys(g.RP || {}).sort().forEach(function (id) {
  var r = g.RP[id];
  out.recettes_production.push({ id: id, ut: r.ut, label: r.label || '', pays: r.pays || '',
                                 materiaux: r.materiaux || {} });
});

// resoudreProduitCommerce() lit DEUX catalogues : RECETTES_ALIMENTAIRES puis PRODUITS_MARCHE.
// Les miroiter separement inviterait a en oublier un ; on les fusionne ici comme le jeu le fait,
// en conservant la source et les restrictions de lieu (elles decident ce qu'un commerce donne
// a le droit de produire).
function pousserRecette(id, r, source) {
  out.recettes_commerce.push({
    id: id, source: source, label: r.label || '',
    pa: (typeof r.pa === 'number') ? r.pa : 0,
    portions: (typeof r.portions === 'number') ? r.portions : 1,
    materiaux: r.materiaux || {},
    prix_fixe: (typeof r.prixFixe === 'number') ? r.prixFixe : null,
    categorie: r.categorie || null,
    types_autorises: r.typesAutorises || null,
    pays_autorises: r.paysAutorises || null,
    villes_autorisees: r.villesAutorisees || null,
    buildings_autorises: r.buildingsAutorises || null });
}
Object.keys(g.RA || {}).sort().forEach(function (id) { pousserRecette(id, g.RA[id], 'alimentaire'); });
Object.keys(g.PM || {}).sort().forEach(function (id) {
  if (g.RA && g.RA[id]) { return; }  // RECETTES_ALIMENTAIRES gagne, comme resoudreProduitCommerce
  pousserRecette(id, g.PM[id], 'marche');
});

Object.keys(g.BCT || {}).sort().forEach(function (cle) {
  out.types_commerce.push({ cle: cle, type: g.BCT[cle] });
});

// Les dotations sont des fonctions : on capture leur EFFET sur un defaut vierge, jamais
// leur texte. Le type passe est celui que BUILDING_COMMERCE_TYPE associe a la cle, pour
// que le blob capture soit exactement celui que le jeu produirait.
Object.keys(g.DOT || {}).sort().forEach(function (cle) {
  var parts = cle.split('|');
  var batiment = parts[0], room = (parts.length > 1) ? parts[1] : null;
  var type = g.BCT[cle] || g.BCT[batiment] || 'cafe';
  var d = g.defC(type, 'republic', 'capitale', batiment, room);
  g.DOT[cle](d);
  out.dotations.push({ cle: cle, type: type, caisse: d.caisse || 0,
                       stock_matieres: d.stockMatieres || {},
                       cout_moyen_matieres: d.coutMoyenMatieres || {},
                       carte: d.carte || [],
                       parametres: d.parametres || {} });
});

// Armurerie : le defaut depend du pays (getRecettesPays). On capture les trois.
['republic', 'narco', 'soviet'].forEach(function (pays) {
  var d = g.defA(pays, 'capitale');
  out.armureries.push({ pays: pays, caisse: d.caisse || 0,
                        stock_matieres: d.stockMatieres || {},
                        parametres: d.parametres || {} });
});

out.constantes = { salaire_production_armurerie: g.SPA, pa_production_armurerie: g.PPA,
                   cout_main_oeuvre_pa_alimentaire: g.CMO, stock_max_commerce: g.SMC };
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
    """Litteral SQL d'une chaine, d'un nombre ou d'un jsonb."""
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
    L = []
    L.append("DELETE FROM public.recettes_production;")
    L.append("INSERT INTO public.recettes_production (id, ut, label, pays, materiaux) VALUES")
    L.append(",\n".join("  (%s, %s, %s, %s, %s)" % (litteral(r["id"]), litteral(r["ut"]),
             litteral(r["label"]), litteral(r["pays"]), litteral(r["materiaux"]))
             for r in d["recettes_production"]) + ";")

    L.append("\nDELETE FROM public.recettes_commerce;")
    L.append("INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux,"
             " prix_fixe, categorie, types_autorises, pays_autorises, villes_autorisees,"
             " buildings_autorises) VALUES")
    L.append(",\n".join("  (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" % (
             litteral(r["id"]), litteral(r["source"]), litteral(r["label"]), litteral(r["pa"]),
             litteral(r["portions"]), litteral(r["materiaux"]), litteral(r["prix_fixe"]),
             litteral(r["categorie"]), litteral(r["types_autorises"]), litteral(r["pays_autorises"]),
             litteral(r["villes_autorisees"]), litteral(r["buildings_autorises"]))
             for r in d["recettes_commerce"]) + ";")

    L.append("\nDELETE FROM public.commerces_types;")
    L.append("INSERT INTO public.commerces_types (cle, type) VALUES")
    L.append(",\n".join("  (%s, %s)" % (litteral(r["cle"]), litteral(r["type"]))
             for r in d["types_commerce"]) + ";")

    L.append("\nDELETE FROM public.commerces_dotations;")
    L.append("INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES")
    L.append(",\n".join("  (%s, %s, %s, %s, %s, %s, %s)" % (litteral(r["cle"]), litteral(r["type"]),
             litteral(r["caisse"]), litteral(r["stock_matieres"]), litteral(r["cout_moyen_matieres"]),
             litteral(r["carte"]), litteral(r["parametres"]))
             for r in d["dotations"]) + ";")

    L.append("\nDELETE FROM public.armureries_dotations;")
    L.append("INSERT INTO public.armureries_dotations (pays, caisse, stock_matieres, parametres) VALUES")
    L.append(",\n".join("  (%s, %s, %s, %s)" % (litteral(r["pays"]), litteral(r["caisse"]),
             litteral(r["stock_matieres"]), litteral(r["parametres"]))
             for r in d["armureries"]) + ";")

    c = d["constantes"]
    L.append("\nDELETE FROM public.entreprises_constantes;")
    L.append("INSERT INTO public.entreprises_constantes (cle, valeur) VALUES")
    L.append(",\n".join("  (%s, %s)" % (litteral(k), litteral(v)) for k, v in sorted(c.items())
             if v is not None) + ";")
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
        print("recettes de production (armurerie) : %d" % len(d["recettes_production"]))
        print("recettes de commerce (2 catalogues) : %d" % len(d["recettes_commerce"]))
        print("types de commerce par batiment     : %d" % len(d["types_commerce"]))
        print("dotations pilotes capturees        : %d" % len(d["dotations"]))
        for r in d["dotations"]:
            print("    %-38s type=%-10s caisse=%-6s carte=%d" %
                  (r["cle"], r["type"], r["caisse"], len(r["carte"])))
        print("armureries par pays                : %d" % len(d["armureries"]))
        for r in d["armureries"]:
            print("    %-10s caisse=%s" % (r["pays"], r["caisse"]))
        print("constantes                         : %s" % json.dumps(d["constantes"]))
        print("empreinte                          : %s" % empreinte(d))
    return 0


if __name__ == "__main__":
    sys.exit(main())
