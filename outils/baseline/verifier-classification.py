#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controles automatiques de la classification des donnees (chantier 2C).

Verifie, sans acceder a la base :
  1. exactement 259 tables classees ;
  2. aucune table oubliee ni inventee -- l'empreinte de la liste des tables doit
     correspondre a celle relevee dans le catalogue au moment de la classification ;
  3. aucune table classee deux fois ;
  4. toute table D porte une justification de separation ;
  5. toute table prevue en seed porte une justification ;
  6. aucune table d'etat vivant pur n'est prevue en seed complet ;
  7. categories et strategies appartiennent au vocabulaire ferme.

Usage :
    python3 outils/baseline/verifier-classification.py
Code de sortie 0 si tout est conforme, 1 sinon.
"""

import csv
import hashlib
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV = os.path.join(RACINE, "baseline", "classification-donnees.csv")

# Mesure du 8 octobre 2026, apres la migration 20261008071350 du chantier des budgets
# municipaux, qui porte le catalogue de 259 a 260 tables : recettes_municipales, le COMPTEUR des
# recettes du jour -- une mesure, pas une tresorerie. (Pour memoire, 255 -> 259 le 7 octobre :
# villes et villes_empreinte au chantier 4E, repartitions_budgetaires et repartitions_versements
# au 4F.)
#
# LES DEUX VALEURS VIENNENT DE LA BASE, pas du CSV, et c'est tout le point de ce controle : elles
# sont relevees par la requete citee en commentaire, puis comparees a ce que le CSV recalcule. Les
# poser depuis le CSV rendrait la verification circulaire -- elle ne dirait plus rien.
TABLES_ATTENDUES = 260
EMPREINTE_LISTE = "ce03ae70750e119504b02630b4d6cc48"   # md5(string_agg(relname,',' order by relname collate "C"))

CATEGORIES = {"A", "B", "C", "D"}
STRATEGIES = {"seed_complet", "seed_filtre", "reconstruction_explicite",
              "structure_seule", "hors_baseline"}
STRATEGIES_DE_SEED = {"seed_complet", "seed_filtre", "reconstruction_explicite"}


def main():
    pbs = []
    lignes = list(csv.DictReader(open(CSV, encoding="utf-8"), delimiter=";"))
    noms = [l["table"] for l in lignes]

    print("1. nombre de tables classees        : %d / %d  %s"
          % (len(lignes), TABLES_ATTENDUES, "OK" if len(lignes) == TABLES_ATTENDUES else "NON"))
    if len(lignes) != TABLES_ATTENDUES:
        pbs.append("nombre de tables classees incorrect")

    doublons = sorted({n for n in noms if noms.count(n) > 1})
    print("2. tables classees deux fois        : %d  %s"
          % (len(doublons), "OK" if not doublons else "NON"))
    for dbl in doublons:
        pbs.append("table classee deux fois : " + dbl)

    emp = hashlib.md5(",".join(sorted(noms)).encode("utf-8")).hexdigest()
    ok = emp == EMPREINTE_LISTE
    print("3. empreinte de la liste des tables : %s  %s" % (emp, "OK" if ok else "NON"))
    if not ok:
        pbs.append("la liste des tables classees ne correspond pas au catalogue releve")

    sans_sep = [l["table"] for l in lignes
                if l["categorie"] == "D" and not l["arbitrage"].strip() and "vivant" not in l["justification"]]
    nb_d = sum(1 for l in lignes if l["categorie"] == "D")
    print("4. tables D sans justification de separation : %d / %d  %s"
          % (len(sans_sep), nb_d, "OK" if not sans_sep else "NON"))
    for t in sans_sep:
        pbs.append("table D sans justification de separation : " + t)

    seeds = [l for l in lignes if l["strategie"] in STRATEGIES_DE_SEED]
    sans_just = [l["table"] for l in seeds if len(l["justification"].strip()) < 20]
    print("5. tables en seed sans justification : %d / %d  %s"
          % (len(sans_just), len(seeds), "OK" if not sans_just else "NON"))
    for t in sans_just:
        pbs.append("table prevue en seed sans justification : " + t)

    faute = [l["table"] for l in lignes if l["categorie"] == "C" and l["strategie"] == "seed_complet"]
    print("6. tables d'etat vivant en seed complet : %d  %s"
          % (len(faute), "OK" if not faute else "NON"))
    for t in faute:
        pbs.append("table d'etat vivant prevue en seed complet : " + t)

    hors = [l["table"] for l in lignes
            if l["categorie"] not in CATEGORIES or l["strategie"] not in STRATEGIES]
    print("7. categories/strategies hors vocabulaire : %d  %s"
          % (len(hors), "OK" if not hors else "NON"))
    for t in hors:
        pbs.append("vocabulaire inconnu pour : " + t)

    print()
    repartition = {}
    for l in lignes:
        repartition[l["categorie"]] = repartition.get(l["categorie"], 0) + 1
    print("Repartition  " + "  ".join("%s=%d" % (k, repartition.get(k, 0)) for k in "ABCD"))
    print("Tables entrant dans le seed : %d  (%d lignes actuelles cumulees)"
          % (len(seeds), sum(int(l["lignes_actuelles"]) for l in seeds)))

    print()
    if pbs:
        print("ECHEC : %d anomalie(s)" % len(pbs))
        for p in pbs:
            print("  - " + p)
        return 1
    print("CONFORME : la classification couvre exactement le catalogue, sans trou ni doublon.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
