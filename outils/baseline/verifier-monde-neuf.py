#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle du MONDE NEUF : aucune donnee de bêta, aucun vestige canonise.

Les autres controles verifient que le baseline est FIDELE au catalogue. Celui-ci
verifie une chose differente, et qui ne se deduit pas de la fidelite : que le
monde qui naitra de ces seeds ne traine ni les artefacts de la bêta, ni les
objets que l'audit a identifies comme des vestiges.

Un baseline peut etre parfaitement fidele ET faire naitre un monde pollue. La
fidelite dit « c'est bien ce que la base contient » ; ce controle-ci dit « c'est
bien ce qu'un monde neuf doit contenir ».

DEUX FAMILLES, qui echouent independamment.

  1. ARTEFACTS DE BETA      marqueurs de test, horodatages engendres en partie,
                            identifiants de la compagnie de bêta, schema de
                            sauvegarde, lots de dotation de bêta
  2. VESTIGES CANONISES     les objets que l'audit du 5 octobre 2026 a declares
                            vestiges ne doivent apparaitre dans AUCUN seed

Les exceptions legitimes sont declarees ici, nommees, avec leur raison. Une
occurrence non declaree fait echouer le controle.

Usage :
    python3 outils/baseline/verifier-monde-neuf.py
Code de sortie 0 si le monde neuf est propre, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import glob
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
SEEDS = os.path.join(RACINE, "baseline", "seeds")

# --------------------------------------------------------------------------
# 1. MARQUEURS D'ARTEFACT DE BETA
# --------------------------------------------------------------------------
ARTEFACTS = [
    (r"(^|[^a-z])zz", "marqueur de test (prefixe zz)"),
    (r"\b17[0-9]{11}\b", "horodatage epoch a 13 chiffres : identifiant engendre en partie"),
    (r"\bsauvegarde_beta_\d+", "schema de sauvegarde de la bêta"),
    (r"dotation-beta-\d{4}-\d{2}-\d{2}", "lot de dotation pose pendant la bêta"),
    (r"\b202609-\d{3}\b", "matricule de soldat engendre pendant la bêta"),
    (r"compagnie-\w+-17\d{11}", "identifiant de la compagnie militaire de bêta"),
]

# --------------------------------------------------------------------------
# 2. VESTIGES IDENTIFIES PAR L'AUDIT DU 5 OCTOBRE 2026
# Aucun ne doit apparaitre comme donnee dans un seed.
# --------------------------------------------------------------------------
VESTIGES = {
    # republic_palais-gouvernement A QUITTE CETTE LISTE le 7 octobre 2026, et c'est le seul
    # verdict de l'audit du 5 octobre qui ait ete RENVERSE.
    #
    # L'audit avait raison A SA DATE : aucune fonction serveur, aucun appel client et aucun cron
    # ne touchait cette caisse, et la repartition nationale ne la connaissait pas. Elle etait
    # bien le residu d'un modele d'avant les caisses par piece.
    #
    # L'arbitrage du 7 octobre la fait exister pour de bon : le Palais du Gouvernement est l'une
    # des DIX caisses nationales, a 9 %, et elle porte les actions gouvernementales communes --
    # distincte de gouvernement-pm, qui reste l'enveloppe propre du Premier ministre. La trouver
    # dans un seed n'est donc plus un defaut : c'est la regle.
    #
    # Un controle qui perd une ligne sans dire pourquoi laisse croire qu'elle n'a jamais existe.
    "republic_stade-buvette":
        "la buvette n'a plus de caisse autonome depuis le 17 aout 2026",
    "republic_mairie_caserne":
        "la caserne n'est pas une ville",
    "republic_juge_national":
        "quatrieme juge generique, d'avant la dimension ville",
    "lois_assemblee":
        "table morte, remplacee par le circuit de depot unique",
}
# Les huit caisses non suffixees par la ville : etat d'avant le 16 aout 2026.
# Cherchees sous la forme republic_<nom> pour ne pas confondre avec la caisse
# suffixee (republic_commissariat_capitale contient bien republic_commissariat,
# d'ou la frontiere de mot en fin de motif).
for _nom in ("commissariat", "commissariat-local", "tribunal", "tribunal-local",
             "dispensaire-public", "dispensaire-public-v", "marche", "stade"):
    VESTIGES["republic_" + _nom] = ("caisse non suffixee par la ville, etat d'avant le "
                                    "correctif du 16 aout 2026")

# --------------------------------------------------------------------------
# EXCEPTIONS DECLAREES. Chacune est nommee et motivee. Sans cette liste, le
# controle crierait sur des faux positifs ; avec elle, il crie sur tout le reste.
# --------------------------------------------------------------------------
EXCEPTIONS = [
    (r"Azzouz", "nom de couverture authored « Nabil Ben Azzouz » : le motif zz y est "
                "un faux positif, consigne au chantier 2E"),
    (r"Puzzle|puzzle", "mot commun contenant zz"),
    (r"jazz", "mot commun contenant zz"),
]


def lignes_de_donnees(chemin):
    """Ne renvoie que les lignes de DONNEES : les commentaires d'en-tete citent
    volontiers les vestiges pour expliquer pourquoi ils sont ecartes, et les
    confondre avec des donnees rendrait le controle inutilisable."""
    with open(chemin, encoding="utf-8", newline="") as fh:
        for n, l in enumerate(fh, 1):
            nu = l.lstrip()
            if nu.startswith("--") or not nu.strip():
                continue
            yield n, l.rstrip("\n")


def excuse(ligne):
    for motif, raison in EXCEPTIONS:
        if re.search(motif, ligne):
            return raison
    return None


def main():
    fichiers = sorted(glob.glob(os.path.join(SEEDS, "*", "*.sql")))
    if not fichiers:
        print("ECHEC : aucun fichier de seed.")
        return 1

    pbs = {"1. ARTEFACTS DE BETA": [], "2. VESTIGES CANONISES": []}
    excusees, lignes_lues = [], 0

    for chemin in fichiers:
        court = os.path.relpath(chemin, SEEDS)
        for n, ligne in lignes_de_donnees(chemin):
            lignes_lues += 1
            raison_excuse = excuse(ligne)
            for motif, quoi in ARTEFACTS:
                if re.search(motif, ligne):
                    if raison_excuse:
                        excusees.append("%s:%d — %s" % (court, n, raison_excuse))
                    else:
                        pbs["1. ARTEFACTS DE BETA"].append(
                            "%s:%d — %s : %s" % (court, n, quoi, ligne[:120]))
            for vestige, pourquoi in sorted(VESTIGES.items()):
                if re.search(r"%s(?![\w-])" % re.escape(vestige), ligne):
                    pbs["2. VESTIGES CANONISES"].append(
                        "%s:%d — %s (%s)" % (court, n, vestige, pourquoi))

    print("CONTROLE DU MONDE NEUF")
    print("  %d fichiers de seed, %d lignes de donnees examinees" % (len(fichiers), lignes_lues))
    print("  %d motifs d'artefact, %d vestiges recherches, %d exceptions declarees"
          % (len(ARTEFACTS), len(VESTIGES), len(EXCEPTIONS)))

    for famille in ("1. ARTEFACTS DE BETA", "2. VESTIGES CANONISES"):
        n = len(pbs[famille])
        print("\n%s" % famille)
        print("  " + "-" * 70)
        print("  occurrences non declarees : %d  %s" % (n, "OK " if not n else "NON"))
        for p in pbs[famille][:30]:
            print("    - " + p)

    if excusees:
        print("\nFAUX POSITIFS, DECLARES ET ADMIS : %d" % len(excusees))
        for e in sorted(set(excusees))[:10]:
            print("    . " + e)

    print("\n" + "=" * 72)
    total = sum(len(v) for v in pbs.values())
    if total:
        print("ECHEC : %d occurrence(s) de bêta ou de vestige dans les seeds" % total)
        return 1
    print("CONFORME : aucune donnee de bêta et aucun vestige dans les seeds.")
    print("           Le monde neuf ne herite ni des artefacts de la bêta, ni des")
    print("           objets que l'audit a declares vestiges.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
