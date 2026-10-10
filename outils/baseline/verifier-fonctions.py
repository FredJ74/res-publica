#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle des FONCTIONS RECOPIEES (chantier 7, 10 octobre 2026).

LA QUESTION POSEE : le serveur CALCULE-t-il la meme chose que le jeu ?

Le chantier 4C a ferme l'axe des DONNEES -- les constantes que api/ ressaisit a
la main sont desormais generees depuis leur canon, et `verifier-referentiels.py`
surveille ce qui reste. Mais il n'a traite que les donnees, et le depot le disait
lui-meme a trois endroits de api/cron-minuit.js :

    AUCUN TEST NE LE VERIFIE AUJOURD'HUI -- constate le 6 octobre 2026 : le test
    annonce n'existe nulle part dans le depot. La duplication de FONCTIONS est
    inventoriee et reportee au chantier 7 ; le 4B n'a traite que les donnees.

C'est cet axe-la. Quarante-quatre fonctions de jeu vivent en deux exemplaires :
une au navigateur, qui est le canon, et une dans un module de `api/`, parce
qu'un module serverless ne peut pas charger un script de navigateur. Deux
implementations d'une meme regle divergent toujours un jour -- et quand celle du
cron derive, elle derive la nuit, toute seule, sur de l'argent.

COMMENT IL LIT, ET POURQUOI AINSI

On ne compare pas des textes a l'oeil : on EXECUTE les deux cotes.

  . les fichiers du navigateur sont charges dans JavaScriptCore, tels quels ;
  . chaque module de `api/` est charge LUI AUSSI, tel quel, mais dans une PORTEE
    ISOLEE qui n'expose que les symboles declares. Sans cette portee le chargement
    echoue : les deux cotes declarent `const FUSEAU_ELECTORAL`, `const
    SUPABASE_URL`, `const RESSOURCES_ECONOMIE`... et JavaScript refuse une
    redeclaration de `const`. La portee isolee est donc ce qui permet de mesurer
    au lieu de supposer, et c'est elle qui rend ce controle possible du tout.

Consequence : ce qui est compare est ce que le moteur JavaScript voit des deux
cotes, sur des grilles de cas reels -- jamais une valeur recopiee a la main dans
ce fichier. C'est la doctrine deja employee par `banc-chantier-progression-
serveur.js` au chantier 5, etendue a tout l'inventaire.

QUATRE MECANISMES, PARCE QU'UNE COPIE N'EST PAS TOUJOURS COMPARABLE

  `comparee`              fonction pure : les deux cotes sont appeles sur la
                          grille declaree et doivent rendre EXACTEMENT la meme
                          chose. Une seule case qui differe fait echouer.
  `divergence_declaree`   la copie serveur est volontairement plus etroite ou
                          plus stricte que son canon. La divergence est decrite,
                          et son ETENDUE est declaree : le nombre de cas
                          divergents doit etre exactement celui annonce. Trop,
                          c'est une regression ; moins, c'est une declaration
                          perimee.
  `homonyme`              meme nom de base, mais PAS une copie : signature ou
                          question differente. Seule l'existence des deux
                          symboles est verifiee -- un renommage se voit.
  `epinglee`              la copie fait des entrees-sorties : on ne peut pas
                          l'executer hors base sans mentir. Les deux cotes sont
                          alors EPINGLES par l'empreinte de leur texte
                          normalise. Toute retouche d'un cote ou de l'autre
                          rougit, et un humain rejuge.

ET UN CINQUIEME CONTROLE, QUI EST LE PLUS IMPORTANT : L'EXHAUSTIVITE

Le fichier `api/*.js` est reparcouru a chaque passage, et toute fonction dont le
nom de base existe aussi au navigateur DOIT etre declaree ici. Une copie neuve
non declaree fait echouer le controle le jour de sa naissance. Sans cette regle,
la declaration vieillirait en silence -- exactement le defaut que ce chantier
ferme.

LES HUIT REFUS ONT ETE PROUVES, le 10 octobre 2026, en perturbant une chose a la
fois puis en la defaisant. Un garde-fou qu'on n'a jamais vu rouge ne prouve rien.
Pour les rejouer, chacun doit rendre 1 :

  1. `+ 1` ajoute au corps de seuilDeuxTiersServeur          -> DIVERGE
  2. une fonction copiee neuve ajoutee a api/cron-minuit.js   -> copie non declaree
  3. une ligne changee dans une fonction epinglee             -> TEXTE MODIFIE
  4. FUSEAU_ELECTORAL passe a 'Europe/Lisbon' au serveur      -> constante DIVERGE
  5. une copie declaree renommee dans son module              -> declaree introuvable
  6. cas_divergents_attendus modifie dans fonctions.json      -> ETENDUE CHANGEE
  7. une entree de hors_perimetre qui ne designe plus rien    -> ecartee perimee
  8. un canon renomme dans son fichier de navigateur          -> CANON ABSENT

SI JSC EST ABSENT, le controle le DIT et s'abstient : il ne se declare pas vert.

Usage :
    python3 outils/baseline/verifier-fonctions.py
    python3 outils/baseline/verifier-fonctions.py --detail
    python3 outils/baseline/verifier-fonctions.py --poser    # imprime les empreintes
Code de sortie 0 si les fonctions concordent, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
DECLARATION = os.path.join(ICI, "fonctions.json")

JSC_CANDIDATS = [
    "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc",
    "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc",
]

# CE QUE LE NAVIGATEUR ET NODE DONNENT, ET QUE JSC NE DONNE PAS. Le decor est
# volontairement INERTE : `document` ne rend jamais d'element, `state` porte le
# minimum. Une fonction qui aurait besoin de plus que ca pour calculer n'est pas
# une fonction pure, et sa place est dans `epinglee`.
PREAMBULE = """
var process = { env: {} };
var console = { error: function () {}, warn: function () {}, log: function () {},
                info: function () {} };
var window = undefined;
var document = {
  addEventListener: function () {}, removeEventListener: function () {},
  getElementById: function () { return null; },
  querySelector: function () { return null; },
  querySelectorAll: function () { return []; },
  createElement: function () {
    return { style: {}, appendChild: function () {}, addEventListener: function () {},
             classList: { add: function () {}, remove: function () {} } };
  },
  body: { appendChild: function () {} }
};
var state = { day: 1 };
"""


def jsc():
    for c in JSC_CANDIDATS:
        if os.path.exists(c):
            return c
    return None


# --- lecture du depot -------------------------------------------------------

DECL_FN = re.compile(
    r"^(?:async\s+)?function\s+([A-Za-z0-9_$]+)\s*\(|"
    r"^\s{0,2}(?:const|let|var)\s+([A-Za-z0-9_$]+)\s*=\s*(?:async\s*)?function\s*\(")


def _corps(lignes, idx):
    """Texte d'une fonction, depuis sa ligne de declaration, par equilibrage d'accolades."""
    prof, ouverte, out = 0, False, []
    for i in range(idx, len(lignes)):
        out.append(lignes[i])
        for c in lignes[i]:
            if c == "{":
                prof += 1
                ouverte = True
            elif c == "}":
                prof -= 1
        if ouverte and prof <= 0:
            return "\n".join(out)
    return "\n".join(out)


def fonctions_du_fichier(chemin):
    """{nom: texte} des fonctions declarees au premier niveau d'un fichier."""
    lignes = open(chemin, encoding="utf-8").read().split("\n")
    out = {}
    for i, l in enumerate(lignes):
        m = DECL_FN.match(l)
        if m:
            nom = m.group(1) or m.group(2)
            out.setdefault(nom, _corps(lignes, i))
    return out


def normaliser(texte):
    """Retire commentaires, espaces et suffixes de cote. Deux textes egaux apres
    normalisation portent la meme logique."""
    t = re.sub(r"/\*.*?\*/", "", texte, flags=re.S)
    t = "\n".join(re.sub(r"//.*$", "", l) for l in t.split("\n"))
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"\s*([{}();,=<>+\-*/\[\]:?&|!])\s*", r"\1", t)
    return t


def empreinte(texte):
    return hashlib.md5(normaliser(texte).encode("utf-8")).hexdigest()[:16]


def forme_script(src):
    """Retire les mots-cles de module en PRESERVANT le nombre de lignes -- meme
    transformation que outils/bancs/lancer-banc.py, pour la meme raison : un
    numero de ligne qui mentirait rendrait toute erreur inexploitable."""
    if not re.search(r"^\s*(import|export)\s", src, flags=re.M):
        return src

    def vider(m):
        return "\n" * m.group(0).count("\n")

    out = re.sub(r"^import\s+[^;]*?;", vider, src, flags=re.M | re.S)
    out = re.sub(r"^export\s+default\s+", "var __default_export = ", out, flags=re.M)
    out = re.sub(r"^export\s+(const|let|var|function|async\s+function|class)\s",
                 r"\1 ", out, flags=re.M)
    out = re.sub(r"^export\s*\{[^}]*?\}\s*(from\s*['\"][^'\"]*['\"])?\s*;?", vider,
                 out, flags=re.M | re.S)
    reste = re.findall(r"^\s*(?:import|export)\b.*$", out, flags=re.M)
    if reste:
        raise SystemExit("verifier-fonctions : mot-cle de module survivant : %r" % reste[:3])
    if len(out.split("\n")) != len(src.split("\n")):
        raise SystemExit("verifier-fonctions : le nombre de lignes a change")
    return out


# --- construction du programme de mesure ------------------------------------

PILOTE = r"""
function __fig(x) {
  // L'identite d'un document porte Date.now() et un alea : elle est remplacee par un
  // marqueur, sinon deux appels du MEME cote differeraient. Rien d'autre n'est masque.
  return JSON.stringify(x, function (cle, v) {
    if (cle === 'id' && typeof v === 'string') return '<id>';
    return v;
  });
}
var __res = [];
__COPIES.forEach(function (c) {
  var ligne = { cle: c.cle, mecanisme: c.mecanisme };
  var srv, can;
  try { srv = __PORTEES[c.portee] ? __PORTEES[c.portee][c.symbole_serveur] : undefined; }
  catch (e) { srv = undefined; }
  try { can = eval(c.symbole_canon); } catch (e) { can = undefined; }
  ligne.serveur_present = (typeof srv !== 'undefined');
  ligne.canon_present = (typeof can !== 'undefined');
  if (c.mecanisme === 'homonyme' || c.mecanisme === 'epinglee') { __res.push(ligne); return; }
  if (typeof srv !== 'function' || typeof can !== 'function') { __res.push(ligne); return; }
  var cas;
  try { cas = eval(c.grille); } catch (e) {
    ligne.grille_cassee = String(e); __res.push(ligne); return;
  }
  var n = 0, divergents = 0, exemples = [];
  cas.forEach(function (args) {
    var a, b, ea = null, eb = null;
    var copieA = JSON.parse(JSON.stringify(args));
    var copieB = JSON.parse(JSON.stringify(args));
    try { a = __fig(can.apply(null, copieA)); } catch (e) { ea = String(e); }
    try { b = __fig(srv.apply(null, copieB)); } catch (e) { eb = String(e); }
    n++;
    var differe = (ea || eb) ? (ea !== eb) : (a !== b);
    if (differe) {
      divergents++;
      if (exemples.length < 3) {
        exemples.push({ args: JSON.stringify(args),
                        canon: ea ? ('LEVE ' + ea) : a,
                        serveur: eb ? ('LEVE ' + eb) : b });
      }
    }
  });
  ligne.cas = n; ligne.divergents = divergents; ligne.exemples = exemples;
  __res.push(ligne);
});
var __cst = [];
__CONSTANTES.forEach(function (c) {
  var s, v;
  try { s = __PORTEES[c.portee] ? __PORTEES[c.portee][c.symbole] : undefined; } catch (e) { s = undefined; }
  try { v = eval(c.symbole); } catch (e) { v = undefined; }
  __cst.push({ symbole: c.symbole,
               serveur_present: (typeof s !== 'undefined'),
               canon_present: (typeof v !== 'undefined'),
               egales: JSON.stringify(s) === JSON.stringify(v),
               serveur: JSON.stringify(s), canon: JSON.stringify(v) });
});
print('RESULTAT_JSON=' + JSON.stringify({ copies: __res, constantes: __cst }));
"""


def programme(decl):
    morceaux = [PREAMBULE]
    for s in decl["sources_navigateur"]:
        morceaux.append(forme_script(open(os.path.join(RACINE, s), encoding="utf-8").read()))

    for mod in decl["modules_serveur"]:
        src = forme_script(open(os.path.join(RACINE, mod["fichier"]), encoding="utf-8").read())
        symboles = sorted({c["symbole_serveur"] for c in decl["copies"]
                           if c["portee"] == mod["portee"]} |
                          {c["symbole"] for c in decl["constantes_homonymes"]
                           if c["portee"] == mod["portee"]})
        expo = ", ".join("%s: (typeof %s !== 'undefined') ? %s : undefined" % (n, n, n)
                         for n in symboles)
        morceaux.append("var __PORTEE_%s = (function () {\n%s\nreturn { %s };\n})();"
                        % (mod["portee"], src, expo))
    morceaux.append("var __PORTEES = { %s };"
                    % ", ".join("%s: __PORTEE_%s" % (m["portee"], m["portee"])
                                for m in decl["modules_serveur"]))
    morceaux.append(decl["decor_des_grilles"])
    morceaux.append("var __COPIES = %s;" % json.dumps(decl["copies"]))
    morceaux.append("var __CONSTANTES = %s;" % json.dumps(decl["constantes_homonymes"]))
    morceaux.append(PILOTE)
    return "\n".join(morceaux)


def mesurer(decl, moteur):
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as fh:
        fh.write(programme(decl))
        tmp = fh.name
    try:
        p = subprocess.run([moteur, tmp], capture_output=True, text=True)
        for l in p.stdout.split("\n"):
            if l.startswith("RESULTAT_JSON="):
                return json.loads(l[len("RESULTAT_JSON="):]), None
        return None, (p.stderr or p.stdout)[-3000:]
    finally:
        os.unlink(tmp)


# --- exhaustivite -----------------------------------------------------------

def copies_du_depot(decl):
    """Toute fonction d'un module de `api/` dont le nom de base existe aussi au
    navigateur. C'est la mesure qui decide, pas la declaration."""
    nav = {}
    for f in sorted(os.listdir(RACINE)):
        if f.endswith(".js"):
            for n in fonctions_du_fichier(os.path.join(RACINE, f)):
                nav.setdefault(n, f)
    trouvees = []
    api = os.path.join(RACINE, "api")
    for f in sorted(os.listdir(api)):
        if not f.endswith(".js"):
            continue
        for n in fonctions_du_fichier(os.path.join(api, f)):
            base = re.sub(r"(Serveur|Server)$", "", n)
            canon = nav.get(base) or nav.get(n)
            if canon:
                trouvees.append(("api/" + f, n, canon, base if base in nav else n))
    return trouvees


# --- verdict ----------------------------------------------------------------

def main():
    detail = "--detail" in sys.argv
    poser = "--poser" in sys.argv

    decl = json.load(open(DECLARATION, encoding="utf-8"))
    echecs, notes = [], []

    print("CONCORDANCE DES FONCTIONS RECOPIEES -- chantier 7")
    print("=" * 72)

    moteur = jsc()
    if not moteur:
        print("JavaScriptCore est introuvable : ce controle S'ABSTIENT.")
        print("ECHEC : sans moteur, la concordance n'est pas mesuree.")
        return 1

    # 1. EXHAUSTIVITE -- avant tout le reste : une declaration incomplete rend
    #    tout verdict partiel, et c'est exactement le defaut qu'on ferme.
    declarees = {(c["module"], c["symbole_serveur"]) for c in decl["copies"]}
    ecartees = set(tuple(x) for x in decl.get("hors_perimetre", []))
    dans_depot = copies_du_depot(decl)
    presentes = {(f, n) for f, n, _, _ in dans_depot}
    manquantes = []
    for fichier, nom, canon_fichier, _ in dans_depot:
        if (fichier, nom) in declarees or (fichier, nom) in ecartees:
            continue
        manquantes.append((fichier, nom, canon_fichier))
    print("\nEXHAUSTIVITE")
    print("  " + "-" * 68)
    print("  copies declarees                               %d" % len(declarees))
    print("  copies ecartees, nommees                       %d" % len(ecartees))
    print("  copies trouvees dans le depot et non declarees  %d" % len(manquantes))
    for f, n, c in manquantes:
        echecs.append("copie non declaree : %s:%s (canon apparent %s)" % (f, n, c))
    for cle in sorted(ecartees):
        if cle not in presentes:
            echecs.append("ecartee perimee : %s:%s n'existe plus" % cle)
    # Une copie declaree doit exister pour de vrai. Le test ne passe PAS par la
    # liste des paires detectees : plusieurs copies ont un canon de nom different
    # (capaciteHeuresJourServeur -> capaciteHeuresJourChantier) et ne s'y trouvent
    # donc pas. On interroge le fichier lui-meme.
    for mod in {c["module"] for c in decl["copies"]}:
        presents = fonctions_du_fichier(os.path.join(RACINE, mod))
        for c in decl["copies"]:
            if c["module"] == mod and c["symbole_serveur"] not in presents:
                echecs.append("declaree introuvable : %s:%s n'est plus une fonction du depot"
                              % (mod, c["symbole_serveur"]))

    # 2. EXECUTION DES DEUX COTES
    mesure, erreur = mesurer(decl, moteur)
    if mesure is None:
        print("\nLe programme de mesure n'a pas rendu son resultat :")
        print(erreur)
        print("\nECHEC : les deux cotes n'ont pas pu etre charges ensemble.")
        return 1

    par_cle = {c["cle"]: c for c in decl["copies"]}
    familles = {}
    for r in mesure["copies"]:
        c = par_cle[r["cle"]]
        # Les epinglees sont jugees plus bas, sur leur texte : les lister ici
        # ferait des rubriques vides, et une rubrique vide se lit comme un oubli.
        if c["mecanisme"] == "epinglee":
            continue
        familles.setdefault(c["famille"], []).append((c, r))

    for famille in sorted(familles):
        print("\n%s" % famille.upper())
        print("  " + "-" * 68)
        for c, r in familles[famille]:
            etiquette = "%s -> %s" % (c["symbole_serveur"], c["symbole_canon"])
            if not r["serveur_present"]:
                echecs.append("%s : la copie serveur a disparu" % c["cle"])
                print("  %-56s %s" % (etiquette, "SERVEUR ABSENT"))
                continue
            if not r["canon_present"]:
                echecs.append("%s : le canon a disparu du navigateur" % c["cle"])
                print("  %-56s %s" % (etiquette, "CANON ABSENT"))
                continue
            if r.get("grille_cassee"):
                echecs.append("%s : grille cassee -- %s" % (c["cle"], r["grille_cassee"]))
                print("  %-56s %s" % (etiquette, "GRILLE CASSEE"))
                continue

            if c["mecanisme"] == "comparee":
                if r["divergents"] == 0:
                    print("  %-56s concorde (%d cas)" % (etiquette, r["cas"]))
                else:
                    echecs.append("%s : %d cas divergents sur %d"
                                  % (c["cle"], r["divergents"], r["cas"]))
                    print("  %-56s DIVERGE (%d/%d)"
                          % (etiquette, r["divergents"], r["cas"]))
                    for e in r["exemples"]:
                        print("        args=%s" % e["args"][:120])
                        print("          canon  =%s" % str(e["canon"])[:160])
                        print("          serveur=%s" % str(e["serveur"])[:160])
            elif c["mecanisme"] == "divergence_declaree":
                attendu = c["cas_divergents_attendus"]
                if r["divergents"] == attendu:
                    print("  %-56s divergence declaree tenue (%d/%d cas)"
                          % (etiquette, attendu, r["cas"]))
                else:
                    echecs.append("%s : %d cas divergents, %d declares -- %s"
                                  % (c["cle"], r["divergents"], attendu,
                                     "regression" if r["divergents"] > attendu
                                     else "declaration perimee"))
                    print("  %-56s ETENDUE CHANGEE (%d au lieu de %d)"
                          % (etiquette, r["divergents"], attendu))
                    for e in r["exemples"]:
                        print("        args=%s" % e["args"][:120])
                        print("          canon  =%s" % str(e["canon"])[:160])
                        print("          serveur=%s" % str(e["serveur"])[:160])
            elif c["mecanisme"] == "homonyme":
                print("  %-56s homonyme, les deux symboles existent" % etiquette)
            else:
                echecs.append("%s : mecanisme inconnu %r" % (c["cle"], c["mecanisme"]))

    # 3. LES EPINGLEES -- sur le texte, parce qu'elles font des entrees-sorties
    print("\nEPINGLEES PAR EMPREINTE DE TEXTE")
    print("  " + "-" * 68)
    textes = {}
    for c in decl["copies"]:
        if c["mecanisme"] != "epinglee":
            continue
        fs = fonctions_du_fichier(os.path.join(RACINE, c["module"]))
        fc = fonctions_du_fichier(os.path.join(RACINE, c["canon_fichier"]))
        ts = fs.get(c["symbole_serveur"])
        tc = fc.get(c["symbole_canon"])
        if ts is None or tc is None:
            echecs.append("%s : texte introuvable (%s)" % (
                c["cle"], "serveur" if ts is None else "canon"))
            print("  %-56s TEXTE INTROUVABLE" % c["cle"])
            continue
        es, ec = empreinte(ts), empreinte(tc)
        textes[c["cle"]] = (es, ec)
        if poser:
            print("  %-56s %s / %s" % (c["cle"], es, ec))
            continue
        ok = (es == c["empreinte_serveur"] and ec == c["empreinte_canon"])
        print("  %-56s %s" % (c["cle"], "epinglee" if ok else "TEXTE MODIFIE"))
        if not ok:
            echecs.append("%s : texte modifie depuis la declaration "
                          "(serveur %s attendu %s / canon %s attendu %s)"
                          % (c["cle"], es, c["empreinte_serveur"], ec, c["empreinte_canon"]))

    # 4. LES CONSTANTES HOMONYMES -- invisibles au controle des referentiels,
    #    qui ne regarde que les noms en _SERVEUR.
    print("\nCONSTANTES PORTANT LE MEME NOM DES DEUX COTES")
    print("  " + "-" * 68)
    for r in mesure["constantes"]:
        if not r["serveur_present"] or not r["canon_present"]:
            echecs.append("constante %s : absente d'un cote" % r["symbole"])
            print("  %-56s ABSENTE D'UN COTE" % r["symbole"])
        elif r["egales"]:
            print("  %-56s egales" % r["symbole"])
        else:
            echecs.append("constante %s : %s au serveur, %s au navigateur"
                          % (r["symbole"], r["serveur"][:60], r["canon"][:60]))
            print("  %-56s DIVERGE" % r["symbole"])

    if poser:
        print("\n(--poser : aucun verdict rendu, seules les empreintes sont imprimees)")
        return 0

    print("\n" + "=" * 72)
    if echecs:
        print("ECHEC : %d probleme(s)." % len(echecs))
        for e in echecs:
            print("  . %s" % e)
        return 1
    n_cmp = sum(1 for c in decl["copies"] if c["mecanisme"] == "comparee")
    n_cas = sum(r.get("cas", 0) for r in mesure["copies"])
    print("LES FONCTIONS CONCORDENT.")
    print("%d copies declarees, dont %d comparees sur %d cas executes des deux cotes."
          % (len(decl["copies"]), n_cmp, n_cas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
