#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extrait le CORPS d'une migration depuis une sortie `execute_sql` deviee sur disque.

POURQUOI CET OUTIL EXISTE. Une migration est appliquee en COLLANT son SQL dans
`mcp__supabase__apply_migration` ; son archive doit ensuite porter le corps OCTET POUR OCTET.
Recopier a la main 30 000 caracteres une seconde fois est une source de divergence silencieuse :
l'archive declare alors une empreinte que `verifier-archives-migrations.py` refuse, et il faut
tout reprendre. Cet outil lit le corps DEPUIS LE REGISTRE, c'est-a-dire depuis la source qui
fait foi, et l'ecrit sur disque sans qu'il repasse par un clavier.

MODE D'EMPLOI. Faire rendre a `execute_sql` une sortie assez grosse pour etre DEVIEE sur disque
(la convention du 11 octobre : au-dela du plafond de jetons, la sortie part dans
~/.claude/projects/<projet>/<session>/tool-results/) :

    SELECT array_to_string(statements, E'\\n') AS corps, repeat('.', 40000) AS bourrage
      FROM supabase_migrations.schema_migrations WHERE version = '<version>';

puis :

    python3 outils/baseline/extraire-corps-migration.py <fichier_devie> <destination.sql>

Le format de la sortie deviee est celui que `rendre.py` sait deja lire : un JSON dont la cle
`result` contient un bloc <untrusted-data-...> encadrant le tableau JSON des lignes. Le meme
parseur est donc reutilise, et non reinvente.
"""

import json
import re
import sys


def enveloppe(brut):
    """DEUX FORMES EXISTENT SUR DISQUE, et l'outil lit les deux.

    La premiere -- celle que `rendre.py` connait depuis le 11 octobre -- est un objet JSON dont
    la cle `result` porte le bloc <untrusted-data-...>. La seconde, observee le 13 octobre, est
    un TABLEAU de messages {"type": "text", "text": "<le meme objet JSON, en chaine>"}. Le
    deviateur de sortie a change de forme sans prevenir : un outil qui n'en connaitrait qu'une
    echouerait en silence le jour ou l'autre reapparait."""
    donnees = json.loads(brut)
    if isinstance(donnees, dict) and "result" in donnees:
        return donnees["result"]
    if isinstance(donnees, list):
        for message in donnees:
            if isinstance(message, dict) and isinstance(message.get("text"), str):
                try:
                    interne = json.loads(message["text"])
                except Exception:
                    continue
                if isinstance(interne, dict) and "result" in interne:
                    return interne["result"]
    raise SystemExit("ECHEC : forme de sortie deviee non reconnue")


def corps_depuis(chemin):
    brut = open(chemin, encoding="utf-8").read()
    externe = enveloppe(brut)
    m = re.search(r"<untrusted-data-[0-9a-f-]+>\n(.*)\n</untrusted-data-", externe, re.S)
    if not m:
        raise SystemExit("ECHEC : aucun bloc <untrusted-data-...> dans %s" % chemin)
    lignes = json.loads(m.group(1))
    if not lignes or "corps" not in lignes[0]:
        raise SystemExit("ECHEC : la requete ne rend pas de colonne `corps`")
    return lignes[0]["corps"]


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    corps = corps_depuis(sys.argv[1])
    with open(sys.argv[2], "w", encoding="utf-8") as fh:
        fh.write(corps)
    import hashlib
    nu = corps.lstrip("\n").rstrip("\n")
    print("corps ecrit : %s" % sys.argv[2])
    print("  entier : md5 %s, %d caracteres" % (hashlib.md5(corps.encode()).hexdigest(), len(corps)))
    print("  nu     : md5 %s, %d caracteres" % (hashlib.md5(nu.encode()).hexdigest(), len(nu)))


if __name__ == "__main__":
    main()
