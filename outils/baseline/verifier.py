#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle de fidelite d'un domaine du baseline.

Trois sources sont confrontees, et les trois doivent concorder :

  CONTROLE.json   ce que la BASE dit     (releve par introspection)
  MANIFESTE.json  ce qui a ete RENDU     (produit par rendre.py)
  les .sql        ce qui est SUR DISQUE  (ce qu'on rejouera un jour)

Un controle de structure seul ne suffit pas : une reconstruction peut etre
structurellement parfaite et fonctionnellement ouverte. Les controles de
securite (SECURITY DEFINER, RLS, fermeture au client) sont donc separes et
echouent independamment.

Usage :
    python3 outils/baseline/verifier.py <domaine>
Code de sortie 0 si tout concorde, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import hashlib
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))


def definition_depuis_le_fichier(bloc):
    """Retrouve la definition telle que pg_get_functiondef l'a rendue.

    Le fichier ajoute un point-virgule final que la base ne donne pas : il faut
    le retirer avant de comparer l'empreinte, sinon le controle rougirait sur
    une difference que le rendu a introduite expres. Verifie sur les 641
    definitions du schema : aucune ne se termine par un point-virgule.
    """
    defi = bloc.rstrip("\n")
    if defi.endswith(";"):
        defi = defi[:-1]
    return defi + "\n"


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    domaine = sys.argv[1]
    rep = os.path.join(RACINE, "baseline", "domaines", domaine)
    if not os.path.isdir(rep):
        print("ECHEC : domaine introuvable : " + rep)
        return 1

    man = json.load(open(os.path.join(rep, "MANIFESTE.json"), encoding="utf-8"))
    ctl = json.load(open(os.path.join(rep, "CONTROLE.json"), encoding="utf-8"))
    att = ctl["attendu"]
    pbs = []

    def verif(libelle, obtenu, attendu):
        drapeau = "OK " if obtenu == attendu else "NON"
        print("  %-34s %6s / %-6s  %s" % (libelle, obtenu, attendu, drapeau))
        if obtenu != attendu:
            pbs.append("%s : rendu %s, base %s" % (libelle, obtenu, attendu))

    print("STRUCTURE                            rendu / base")
    verif("tables", len(man["tables"]), att["tables"])
    verif("colonnes", sum(t["colonnes"] for t in man["tables"]), att["colonnes"])
    verif("contraintes", len(man["contraintes"]), att["contraintes"])
    verif("index autonomes", len(man["index_autonomes"]), att["index_autonomes"])
    verif("fonctions", len(man["fonctions"]), att["fonctions"])
    verif("triggers", len(man["triggers"]), att["triggers"])
    verif("policies", len(man["policies"]), att["policies"])
    verif("tables avec RLS active", sum(1 for r in man["rls"] if r["active"]), att["rls_actives"])
    verif("lignes de droits", len(man["droits"]), att["lignes_droits"])
    verif("droits au niveau colonne", len(man["droits_colonnes"]), att["droits_colonnes"])

    print("\nSECURITE")
    secdef = sum(1 for f in man["fonctions"] if f["security_definer"])
    verif("fonctions SECURITY DEFINER", secdef, ctl["securite_attendue"]["fonctions_security_definer"])
    verif("fonctions SECURITY INVOKER", len(man["fonctions"]) - secdef,
          ctl["securite_attendue"]["fonctions_security_invoker"])
    avec_policy = {p["tbl"] for p in man["policies"]}
    fermees = sorted({r["tbl"] for r in man["rls"] if r["active"]} - avec_policy)
    verif("tables RLS active sans policy", len(fermees),
          ctl["securite_attendue"]["tables_rls_active_sans_policy"])
    if fermees != sorted(ctl["securite_attendue"]["tables_rls_active_sans_policy_liste"]):
        pbs.append("liste des tables fermees differente : " + ", ".join(fermees))

    print("\nFIDELITE DES DEFINITIONS")
    # Empreinte globale des fonctions : recalculee depuis les empreintes que la
    # base a elle-meme calculees, puis confrontee a celle relevee en direct.
    emp = hashlib.md5("|".join(sorted(
        f["signature"] + ":" + f["empreinte"] for f in man["fonctions"])).encode("utf-8")).hexdigest()
    ok = emp == ctl["empreinte_fonctions"]
    print("  empreinte globale des fonctions    %s  %s" % (emp, "OK " if ok else "NON"))
    if not ok:
        pbs.append("empreinte globale des fonctions non conforme")

    # Chaque definition ecrite dans le .sql doit retrouver l'empreinte que la
    # base a calculee sur pg_get_functiondef. C'est ce controle qui attrape une
    # alteration du fichier ou une erreur de transcription.
    chemin = os.path.join(rep, "20_fonctions.sql")
    texte = open(chemin, encoding="utf-8", newline="").read()
    blocs = re.split(r"(?m)^-- (\S+\(.*?\)) -> ", texte)
    trouves, faux = 0, []
    for i in range(1, len(blocs), 2):
        signature = blocs[i]
        corps = blocs[i + 1]
        # le corps commence par la fin de la ligne de commentaire, puis la definition
        defi = corps.split("\n", 1)[1]
        attendue = next((f["empreinte"] for f in man["fonctions"] if f["signature"] == signature), None)
        if attendue is None:
            faux.append(signature + " : absente du manifeste")
            continue
        reel = hashlib.md5(definition_depuis_le_fichier(defi).encode("utf-8")).hexdigest()
        if reel == attendue:
            trouves += 1
        else:
            faux.append("%s : fichier %s, base %s" % (signature, reel, attendue))
    print("  definitions de fonctions conformes %6d / %-6d %s"
          % (trouves, len(man["fonctions"]), "OK " if trouves == len(man["fonctions"]) else "NON"))
    for f in faux:
        pbs.append("definition non conforme -- " + f)

    print("\nINTEGRITE DES FICHIERS")
    for nom, empreinte in sorted(man["fichiers"].items()):
        c = open(os.path.join(rep, nom), encoding="utf-8", newline="").read()
        reel = hashlib.md5(c.encode("utf-8")).hexdigest()
        etat = "OK " if reel == empreinte else "ALTERE"
        print("  %-24s %s %s" % (nom, reel, etat))
        if reel != empreinte:
            pbs.append("fichier altere depuis le rendu : " + nom)

    print()
    if pbs:
        print("ECHEC : %d anomalie(s)" % len(pbs))
        for p in pbs:
            print("  - " + p)
        return 1
    print("CONFORME : le domaine %s est fidele au catalogue." % domaine)
    return 0


if __name__ == "__main__":
    sys.exit(main())
