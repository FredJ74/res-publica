#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle des REFERENTIELS RECOPIES (chantier 4C, 6 octobre 2026).

LA QUESTION POSEE : le serveur dit-il la meme chose que le jeu ?

Le serveur en detient deux copies, par deux chemins distincts, et ce controle
surveille les DEUX -- une copie surveillee et une copie libre, ce serait une
copie libre.

PREMIER AXE : data.js  ->  api/
  api/*.js ne PEUT PAS importer data.js : celui-ci n'a ni export ni
  module.exports, et il n'y a pas de package.json. Chaque constante dont le
  serveur a besoin est donc ressaisie a la main, et le depot le dit a chaque
  fois : « ce module serverless ne peut pas importer les fichiers client ».
  Rien ne surveillait cet axe avant ce controle.

SECOND AXE : data.js  ->  BASE, par empreinte
  Les tables miroir, elles, sont surveillees par des empreintes... quand elles
  le sont. Au 6 octobre 2026 la surveillance est CROISEE : sept generateurs
  savent calculer une empreinte, quatre tables <miroir>_empreinte existent, et
  les deux ensembles ne coincident pas. Deux miroirs n'avaient meme aucune
  fonction pour rehacher leur contenu : leur sentinelle n'etait confrontee a
  rien, et l'une d'elles etait fausse depuis toujours sans que rien ne
  s'allume. Cet axe rend cet etat visible au lieu de le supposer sain.

  Il reste HORS LIGNE. La base y est representee par une mesure DATEE consignee
  dans referentiels.json -- meme principe que baseline/, qui represente le
  schema par un releve. Ce qui est recalcule a chaque passage, c'est le cote
  data.js : les generateurs sont rejoues pour de vrai.

Ce n'est pas une precaution theorique. Le 28 aout 2026, un correctif d'identite
n'a atteint le module du Journal que le 5 septembre : il a publie une semaine
entiere de noms de villes perimes. L'audit 4A a trouve treize divergences du
meme genre, dont une qui fait publier des prix de moitie.

COMMENT IL LIT, ET POURQUOI AINSI

On ne lit pas les valeurs a l'expression reguliere : on CHARGE le vrai code.
data.js est charge dans JavaScriptCore, exactement comme le font les sept
generateurs du depot. Les constantes de api/ sont extraites par equilibrage
d'accolades puis EVALUEES, jamais devinees -- un fichier ESM n'est pas chargeable
tel quel (ses `import` echouent), mais un litteral objet, lui, s'evalue.

Consequence : une virgule deplacee, un commentaire, un calcul (100/3) ne
trompent pas ce controle. Ce qui est compare est ce que le moteur JavaScript
voit, des deux cotes.

SI JSC EST ABSENT, le controle le DIT et s'abstient -- il ne se declare pas vert.
Un controle qui mentirait faute d'outil serait pire qu'un controle manquant.

LES DIVERGENCES DEJA CONNUES sont declarees dans referentiels.json avec le lot
qui les ferme. Elles sont rapportees sans faire echouer -- sinon ce controle
serait rouge le jour de sa naissance. Il echoue en revanche sur :
  . une divergence NON declaree                      -> regression
  . une divergence declaree mais DISPARUE             -> declaration perimee
  . une constante introuvable d'un cote ou de l'autre -> le controle est aveugle
  . un generateur muet, absent, ou qui derive         -> le controle est aveugle
  . une declaration qui ne designe plus aucun miroir  -> declaration perimee

Les six refus ont ete PROUVES en perturbant la declaration un cas a la fois, le
6 octobre 2026 : chacun rend 1. Un garde-fou qu'on n'a jamais vu rouge ne
prouve rien.

Le second refus est le plus important : c'est le meme mecanisme qui, au chantier
3, a trouve un GRANT a PUBLIC que la migration croyait avoir retire.

Usage :
    python3 outils/baseline/verifier-referentiels.py
    python3 outils/baseline/verifier-referentiels.py --detail
Code de sortie 0 si les referentiels concordent, 1 sinon.

Cet outil n'accede pas a la base, n'ecrit rien, et ne charge aucun module du
serveur : il lit des fichiers du depot et evalue des litteraux.
"""

import json
import os
import re
import subprocess
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
DECLARATION = os.path.join(ICI, "referentiels.json")

JSC_CANDIDATS = [
    "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc",
    "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc",
]


def jsc():
    for c in JSC_CANDIDATS:
        if os.path.exists(c):
            return c
    return None


def evaluer(script, moteur):
    """Joue un script JavaScript et rend son unique ligne de sortie, decodee."""
    f = tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8")
    f.write(script)
    f.close()
    try:
        p = subprocess.run([moteur, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0 or not p.stdout.strip():
        return None, ((p.stdout or "") + (p.stderr or "")).strip()[-400:]
    try:
        return json.loads(p.stdout.strip().splitlines()[-1]), None
    except Exception as e:
        return None, "sortie illisible : %s" % e


def litteral_de(chemin, constante):
    """Extrait le TEXTE du litteral affecte a `constante`, par equilibrage de
    delimiteurs. On ne devine pas les valeurs : on isole l'expression, et c'est
    le moteur JavaScript qui l'interprete ensuite.

    Les chaines et les commentaires sont traverses sans compter leurs
    delimiteurs -- sans cela, une accolade dans un libelle (« Journee 4 {...} »)
    ou dans un commentaire fermerait le litteral trop tot."""
    src = open(chemin, encoding="utf-8", errors="replace").read()
    m = re.search(r"(?:^|\n)\s*(?:const|let|var)\s+%s\s*=\s*" % re.escape(constante), src)
    if not m:
        return None
    i = m.end()
    while i < len(src) and src[i] in " \t\n":
        i += 1
    if i >= len(src) or src[i] not in "{[":
        return None
    ouvrant, fermant = src[i], {"{": "}", "[": "]"}[src[i]]
    prof, j = 0, i
    chaine = None
    while j < len(src):
        c = src[j]
        if chaine:
            if c == "\\":
                j += 2
                continue
            if c == chaine:
                chaine = None
            j += 1
            continue
        if c in "'\"`":
            chaine = c
            j += 1
            continue
        if c == "/" and j + 1 < len(src) and src[j + 1] == "/":
            j = src.find("\n", j)
            if j < 0:
                break
            continue
        if c == "/" and j + 1 < len(src) and src[j + 1] == "*":
            j = src.find("*/", j)
            if j < 0:
                break
            j += 2
            continue
        if c == ouvrant:
            prof += 1
        elif c == fermant:
            prof -= 1
            if prof == 0:
                return src[i:j + 1]
        j += 1
    return None


def charger_canon(spec, moteur):
    """Charge le vrai fichier du navigateur et imprime l'expression demandee.
    data.js se charge seul ; les modules du plateau ont besoin d'un decor minimal
    (document, window, localStorage) -- meme decor que generer_pa_bonus_differes.py."""
    chemin = os.path.join(RACINE, spec["fichier"])
    if not os.path.exists(chemin):
        return None, "fichier absent : " + spec["fichier"]
    if "expression" in spec:
        script = ("load(%s);\nprint(JSON.stringify(%s));\n"
                  % (json.dumps(chemin), spec["expression"]))
        return evaluer(script, moteur)
    texte = litteral_de(chemin, spec["constante"])
    if texte is None:
        return None, "constante %s introuvable dans %s" % (spec["constante"], spec["fichier"])
    return evaluer("print(JSON.stringify(%s));\n" % texte, moteur)


def charger_copie(spec, moteur):
    chemin = os.path.join(RACINE, spec["fichier"])
    if not os.path.exists(chemin):
        return None, "fichier absent : " + spec["fichier"]
    texte = litteral_de(chemin, spec["constante"])
    if texte is None:
        return None, "constante %s introuvable dans %s" % (spec["constante"], spec["fichier"])
    return evaluer("print(JSON.stringify(%s));\n" % texte, moteur)


def normaliser(valeur, forme, cle):
    """Rend {identifiant: {champ: valeur}}, quelle que soit la forme d'origine.

    Trois formes existent dans le depot et il faut les trois : une LISTE d'objets
    portant un id (les clubs), un OBJET dont la cle est l'identifiant (les
    ressources, les postes), et un OBJET de valeurs simples (une cle de
    repartition). La derniere est ramenee a un champ unique `_valeur` pour que
    la comparaison soit la meme partout."""
    if forme == "liste":
        if not isinstance(valeur, list):
            return None
        if cle is None:
            return {str(v): {"_valeur": v} for v in valeur}
        # UNE CLE DECLAREE QUI N'EXISTE PAS EST UN AVEUGLEMENT, PAS UN DETAIL.
        # Sans ce refus, toutes les entrees tombaient dans le meme seau « None »
        # et le controle annoncait « 1 entree, 0 ecart » sur cinq paliers
        # differents. Il se serait declare vert en ne comparant rien -- defaut
        # constate sur GREVE_PALIERS le jour meme ou cet outil est ne.
        sortie = {}
        for e in valeur:
            if not isinstance(e, dict) or e.get(cle) is None:
                return None
            k = str(e[cle])
            if k in sortie:
                return None
            sortie[k] = e
        return sortie
    if not isinstance(valeur, dict):
        return None
    sortie = {}
    for k, v in valeur.items():
        if isinstance(v, dict):
            d = dict(v)
            d["_cle"] = k
            sortie[str(k)] = d
        else:
            sortie[str(k)] = {"_cle": k, "_valeur": v}
    return sortie


def comparer(canon, copie, champs):
    """Rend la liste des ecarts, en trois familles nommees."""
    ecarts = []
    for k in sorted(set(canon) - set(copie)):
        ecarts.append("absent du serveur : %s" % k)
    for k in sorted(set(copie) - set(canon)):
        ecarts.append("present au serveur mais pas dans le canon : %s" % k)
    for k in sorted(set(canon) & set(copie)):
        for ch in (champs or ["_valeur"]):
            a, b = canon[k].get(ch), copie[k].get(ch)
            if a is None and b is None:
                continue
            if a != b:
                ecarts.append("%s.%s : canon=%s serveur=%s" % (k, ch, json.dumps(a), json.dumps(b)))
    return ecarts


def empreinte_du_generateur(chemin_relatif):
    """Rejoue un generateur et rend l'empreinte qu'il calcule AUJOURD'HUI.

    C'est la partie vivante du second axe : le reste de la comparaison repose
    sur une mesure datee de la base, mais celle-ci est recalculee a chaque
    passage. Si data.js bouge, elle bouge, et le controle rougit en disant quel
    miroir est devenu perime."""
    chemin = os.path.join(RACINE, chemin_relatif)
    if not os.path.exists(chemin):
        return None, "generateur absent : " + chemin_relatif
    p = subprocess.run([sys.executable, chemin, "--empreinte"],
                       capture_output=True, text=True, timeout=600)
    sortie = (p.stdout or "").strip().splitlines()
    if p.returncode != 0 or not sortie:
        return None, "generateur en echec : " + ((p.stdout or "") + (p.stderr or "")).strip()[-300:]
    valeur = sortie[-1].strip()
    if not re.fullmatch(r"[0-9a-f]{16}", valeur):
        return None, "sortie inattendue du generateur : %r" % valeur[:60]
    return valeur, None


def axe_empreintes(decl, echecs):
    """SECOND AXE : data.js contre la BASE, par empreinte, et hors ligne.

    Trois valeurs par miroir, et chacune repond a une question differente :
      data_js  ce que le generateur calcule depuis la source canonique
      reelle   ce que la table contient vraiment (rehache par une fonction SQL)
      posee    ce qui est inscrit dans <miroir>_empreinte, la sentinelle

    data_js != reelle  ->  le miroir est perime : le serveur ne dit plus ce que
                           dit le jeu.
    posee   != reelle  ->  la sentinelle est fausse : elle ne protege plus rien,
                           et c'est ainsi qu'une derive vit des mois sans bruit.

    Le controle ne se connecte pas. `reelle` et `posee` viennent d'une mesure
    datee consignee dans referentiels.json -- meme principe que baseline/, qui
    represente le schema par un releve. Ce qui est RECALCULE a chaque passage,
    c'est data_js : le generateur est rejoue pour de vrai."""
    bloc = decl.get("empreintes")
    if not bloc:
        return
    mesure = bloc.get("_mesure", {})
    miroirs = bloc.get("miroirs", {})
    declarees = decl.get("divergences_empreintes", {})
    vues = set()

    print("\n" + "-" * 74)
    print("SECOND AXE : data.js  ->  BASE, par empreinte")
    print("  mesure de la base datee du %s (lecture seule, non rejouee ici)"
          % mesure.get("le", "?"))

    for nom in sorted(miroirs):
        m = miroirs[nom]
        attendue, reelle, posee = m.get("data_js"), m.get("reelle"), m.get("posee")

        # 1. Le generateur dit-il toujours la meme chose ? (seule partie vivante)
        gen = m.get("generateur")
        if gen:
            calculee, err = empreinte_du_generateur(gen)
            if calculee is None:
                echecs.append("empreintes/%s : %s" % (nom, err))
                print("  %-22s GENERATEUR MUET : %s" % (nom, err))
                continue
            if calculee != attendue:
                echecs.append(
                    "empreintes/%s : le generateur rend %s, la declaration annonce %s. "
                    "data.js a bouge depuis la mesure : le miroir est a regenerer, "
                    "et la declaration a reprendre." % (nom, calculee, attendue))
                print("  %-22s DERIVE DE data.js : %s != %s" % (nom, calculee, attendue))
                continue
            marque = "recalculee"
        else:
            marque = "NON RECALCULABLE (aucun generateur)"

        # 2. Les deux axes de comparaison, chacun avec sa cle de declaration.
        lignes = []
        for suffixe, gauche, droite, phrase in (
                ("base", attendue, reelle, "le miroir ne dit plus ce que dit le jeu"),
                ("posee", posee, reelle, "la sentinelle ne correspond pas au contenu")):
            if gauche is None or droite is None:
                continue
            cle = "%s/%s" % (nom, suffixe)
            vues.add(cle)
            ecart = gauche != droite
            if ecart and cle in declarees:
                lignes.append("    %-8s ATTENDU (%s) : %s"
                              % (suffixe, declarees[cle].get("ferme_par", "?"), phrase))
            elif ecart:
                echecs.append("empreintes/%s : %s (%s != %s), et ce n'est pas declare"
                              % (cle, phrase, gauche, droite))
                lignes.append("    %-8s NON DECLARE : %s != %s" % (suffixe, gauche, droite))
            elif cle in declarees:
                echecs.append("empreintes/%s : divergence declaree mais DISPARUE -- "
                              "retire-la de divergences_empreintes" % cle)
                lignes.append("    %-8s DEJA FERMEE -- a retirer de la declaration" % suffixe)

        print("  %-22s %5d lignes  %s  %s"
              % (nom, m.get("lignes", 0), attendue or "?", marque))
        for l in lignes:
            print(l)

    # Une declaration qui ne designe plus rien est un mensonge qui dort.
    for cle in sorted(set(declarees) - vues):
        echecs.append("divergences_empreintes/%s ne correspond a aucun miroir declare" % cle)

    # 3. Les miroirs generes que RIEN ne surveille en base.
    orphelins = bloc.get("generes_sans_surveillance", {})
    noms = sorted(k for k in orphelins if not k.startswith("_"))
    if noms:
        print("\n  generes mais surveilles par aucune table <miroir>_empreinte :")
        for nom in noms:
            calculee, err = empreinte_du_generateur(
                "outils/generateurs/generer_%s.py" % nom)
            if calculee is None:
                echecs.append("empreintes/%s : %s" % (nom, err))
                print("    %-22s GENERATEUR MUET : %s" % (nom, err))
            elif calculee != orphelins[nom]:
                echecs.append("empreintes/%s : le generateur rend %s, la declaration "
                              "annonce %s" % (nom, calculee, orphelins[nom]))
                print("    %-22s DERIVE : %s != %s" % (nom, calculee, orphelins[nom]))
            else:
                print("    %-22s %s  (rien ne la confronte en base)" % (nom, calculee))


def main():
    detail = "--detail" in sys.argv
    decl = json.load(open(DECLARATION, encoding="utf-8"))
    refs = decl["referentiels"]
    connues = decl.get("divergences_connues", {})

    print("CONTROLE DES REFERENTIELS RECOPIES  (axe data.js / navigateur  ->  api/)")
    moteur = jsc()
    if not moteur:
        print("\n  JavaScriptCore est introuvable sur cette machine.")
        print("  Ce controle CHARGE le vrai code plutot que de deviner ses valeurs ;")
        print("  sans moteur il ne peut rien affirmer. Il s'abstient, et ne se")
        print("  declare pas vert : un controle qui mentirait faute d'outil serait")
        print("  pire qu'un controle manquant.")
        return 1
    print("  moteur : %s" % moteur)
    print("  %d referentiels declares, %d divergence(s) connue(s)"
          % (len(refs), len(connues)))

    aveugles, regressions, perimees, attendues = [], [], [], []

    for nom in sorted(refs):
        r = refs[nom]
        canon_brut, err = charger_canon(r["canon"], moteur)
        if canon_brut is None:
            aveugles.append("%s : canon illisible -- %s" % (nom, err))
            print("\n  %-26s CANON ILLISIBLE" % nom)
            continue
        canon = normaliser(canon_brut, r["forme"], r.get("cle"))
        if canon is None:
            aveugles.append("%s : forme declaree '%s' incompatible avec le canon" % (nom, r["forme"]))
            continue
        print("\n  %-26s canon : %d entree(s)" % (nom, len(canon)))

        for c in r["copies"]:
            etiquette = "%s/%s" % (nom, c["fichier"])
            copie_brut, err = charger_copie(c, moteur)
            if copie_brut is None:
                aveugles.append("%s : %s" % (etiquette, err))
                print("      %-44s ILLISIBLE : %s" % (c["fichier"], err))
                continue
            copie = normaliser(copie_brut, r["forme"], r.get("cle"))
            if copie is None:
                aveugles.append("%s : forme incompatible" % etiquette)
                continue
            ecarts = comparer(canon, copie, r.get("champs"))
            declaree = etiquette in connues
            if ecarts and declaree:
                attendues.append((etiquette, ecarts))
                etat = "ATTENDU (%s)" % connues[etiquette].get("ferme_par", "?")
            elif ecarts:
                regressions.append((etiquette, ecarts))
                etat = "REGRESSION"
            elif declaree:
                perimees.append(etiquette)
                etat = "DEJA FERMEE -- a retirer de la declaration"
            else:
                etat = "OK"
            print("      %-44s %3d entree(s)  %2d ecart(s)  %s"
                  % (c["fichier"], len(copie), len(ecarts), etat))
            garde = ecarts if detail else ecarts[:4]
            for e in garde:
                print("          - " + e)
            if not detail and len(ecarts) > len(garde):
                print("          ... et %d autre(s)" % (len(ecarts) - len(garde)))

    echecs_empreintes = []
    axe_empreintes(decl, echecs_empreintes)

    print("\n" + "=" * 74)
    if echecs_empreintes:
        print("ECHEC : %d probleme(s) sur l'axe des empreintes" % len(echecs_empreintes))
        for e in echecs_empreintes:
            print("  - " + e)
    if aveugles:
        print("ECHEC : %d referentiel(s) illisible(s) -- le controle serait aveugle" % len(aveugles))
        for a in aveugles:
            print("  - " + a)
    if regressions:
        print("ECHEC : %d divergence(s) NON declaree(s)" % len(regressions))
        for e, ec in regressions:
            print("  - %s : %d ecart(s)" % (e, len(ec)))
    if perimees:
        print("ECHEC : %d divergence(s) declaree(s) mais DISPARUE(S)." % len(perimees))
        print("        Retire-les de divergences_connues dans referentiels.json :")
        for p in perimees:
            print("  - " + p)
    if aveugles or regressions or perimees or echecs_empreintes:
        return 1
    attendues_empreintes = decl.get("divergences_empreintes", {})
    if attendues or attendues_empreintes:
        print("CONFORME, DIVERGENCES CONNUES.")
        print("Aucune divergence nouvelle sur aucun des deux axes. Les ecarts")
        print("restants sont ceux que l'audit 4A a deja nommes :")
        for e, ec in attendues:
            print("  . %-44s %3d ecart(s)  ->  %s"
                  % (e, len(ec), connues[e].get("ferme_par", "?")))
        for e in sorted(attendues_empreintes):
            print("  . %-44s empreinte    ->  %s"
                  % (e, attendues_empreintes[e].get("ferme_par", "?")))
        return 0
    print("CONFORME : le serveur dit exactement ce que dit le jeu.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
