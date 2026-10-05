#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Enchaine les huit controles du baseline, dans l'ordre utile (chantier 2G).

UNE SEULE COMMANDE, pour une seule raison : un agent qui doit se souvenir de
huit commandes en oubliera une, et ce sera celle qui aurait trouve le defaut.

Ce module NE REFAIT RIEN. Il appelle les outils existants et rend un verdict
d'ensemble. Toute logique de controle vit dans l'outil qui en a la charge.

L'ORDRE N'EST PAS ALPHABETIQUE, il va du plus structurant au plus fin :

  1. le PROCESSUS tient-il            verifier-workflow.py
  2. la CLASSIFICATION est-elle entiere  verifier-classification.py
  3. le BASELINE est-il fidele        verifier-baseline.py
  4. le MONDE NEUF est-il propre      verifier-monde-neuf.py
  5. l'ASSEMBLAGE se tient-il         assembler.py
  6. la RECONSTRUCTION passe-t-elle   reconstruire.py
  7. le domaine pilote 2B             verifier.py communication
  8. l'archive du registre 2D         ../verifier-archive-registre.py

Un echec en 1 rend les suivants peu interessants : si le depot n'est plus range
comme le processus l'exige, la fidelite du baseline n'est pas la question. Mais
tout est joue quand meme, et tout est rapporte : un diagnostic partiel coute
plus cher qu'une sortie complete.

Aucun de ces outils n'accede a la base. L'ensemble est rejouable hors ligne.

Usage :
    python3 outils/baseline/controler-tout.py
    python3 outils/baseline/controler-tout.py --detail   # sortie complete
Code de sortie 0 si les huit passent, 1 sinon.
"""

import os
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
OUTILS = os.path.dirname(ICI)

CONTROLES = [
    ("le processus tient", [os.path.join(ICI, "verifier-workflow.py")]),
    ("la classification est entiere", [os.path.join(ICI, "verifier-classification.py")]),
    ("le baseline est fidele au catalogue", [os.path.join(ICI, "verifier-baseline.py")]),
    ("le monde neuf est propre", [os.path.join(ICI, "verifier-monde-neuf.py")]),
    ("l'assemblage se tient", [os.path.join(ICI, "assembler.py")]),
    ("la reconstruction passe", [os.path.join(ICI, "reconstruire.py")]),
    ("non-regression du pilote 2B", [os.path.join(ICI, "verifier.py"), "communication"]),
    ("non-regression de l'archive 2D",
     [os.path.join(OUTILS, "verifier-archive-registre.py")]),
]


def main():
    detail = "--detail" in sys.argv
    print("CONTROLE D'ENSEMBLE DU BASELINE -- %d controles" % len(CONTROLES))
    print("=" * 72)

    resultats = []
    for libelle, commande in CONTROLES:
        proc = subprocess.run([sys.executable] + commande, capture_output=True, text=True)
        ok = proc.returncode == 0
        resultats.append((libelle, os.path.basename(commande[0]), ok, proc))
        print("  %-38s %-30s %s"
              % (libelle, os.path.basename(commande[0]), "OK " if ok else "ECHEC"))
        if detail or not ok:
            sortie = (proc.stdout or "") + (proc.stderr or "")
            lignes = sortie.rstrip().splitlines()
            garde = lignes if detail else lignes[-24:]
            for l in garde:
                print("      | " + l)
            print()

    echecs = [r for r in resultats if not r[2]]
    print("=" * 72)
    if echecs:
        print("ECHEC : %d controle(s) sur %d" % (len(echecs), len(resultats)))
        for libelle, outil, _, _ in echecs:
            print("  - %s (%s)" % (libelle, outil))
        print("\nLe detail de chaque echec est au-dessus. Rien n'a ete corrige :")
        print("ces outils rapportent, ils ne reparent pas.")
        return 1
    print("LES %d CONTROLES SONT VERTS." % len(resultats))
    print("Le processus tient, le baseline est fidele, le monde neuf est propre,")
    print("et le script de reconstruction passe la grammaire de PostgreSQL 17.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
