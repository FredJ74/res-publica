#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle du RACCORD ENTRE LE REGISTRE DES FAITS JUDICIAIRES ET LA PRESSE.

LA QUESTION POSEE : un acte declare PUBLIC atteint-il vraiment le Journal ?

Deux tables se repondent, et rien ne les confrontait.

  . `justice_faits_publics` (en base, seedee dans baseline/seeds/90_socle/) dit QUELS actes de
    procedure sont des faits publics, et avec QUELLE PHRASE EXACTE. C'est elle que le declencheur
    `dossiers_actes_publier_au_journal` lit pour ecrire la ligne de `chronique_nationale`.

  . `TYPES_CHRONIQUE` (api/_journal-collecte.js) dit quels types de chronique la collecte de
    presse accepte, avec leur domaine et leur poids editorial. ELLE EST UNE LISTE BLANCHE : un
    type absent est JETE EN SILENCE, sans erreur et sans trace.

UN TYPE DECLARE D'UN COTE ET ABSENT DE L'AUTRE EST UNE PUBLICATION MUETTE. Le fait entre bien au
journal national, la ligne existe en base, et le Journal ne la voit jamais. Ce defaut s'est
produit DEUX FOIS : le 12 septembre 2026 pour `fuite_journalistique` et `scandale_presse`, qui
deposaient leur ligne depuis leur creation sans qu'aucune edition ne les reprenne ; puis le
13 octobre 2026 pour `justice_enquete_ouverte_par_le_juge`, nee avec la decision du juge qui
passe outre le non-lieu du parquet. Les deux fois, rien ne s'est allume.

CE CONTROLE RESTE HORS LIGNE. Il ne se connecte pas : il lit le SEED du registre, qui est
l'etat initial du monde et la reference du baseline, et le code de la collecte. Si le seed
derive de la base, c'est verifier-baseline.py qui le dit -- chaque outil a son angle.

Usage :
    python3 outils/baseline/verifier-faits-publics.py
"""
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
SEED = os.path.join(RACINE, "baseline", "seeds", "90_socle", "justice_faits_publics.sql")
COLLECTE = os.path.join(RACINE, "api", "_journal-collecte.js")


def types_du_registre():
    """Les `chronique_type` du seed. Le seed est une suite d'INSERT a quatre valeurs, ecrits par
    PostgreSQL via quote_nullable : le second litteral est le type de chronique."""
    types = {}
    for l in open(SEED, encoding="utf-8"):
        if not l.startswith("INSERT INTO public.justice_faits_publics"):
            continue
        m = re.search(r"VALUES \('([^']+)', '([^']+)'", l)
        if m:
            types[m.group(2)] = m.group(1)
    return types


def types_de_la_collecte():
    """Les cles de TYPES_CHRONIQUE. On lit les cles, pas les valeurs : une cle commentee ne
    compte pas, et une cle ecrite sur sa propre ligne (nom long) compte quand meme."""
    src = open(COLLECTE, encoding="utf-8").read()
    i = src.index("const TYPES_CHRONIQUE = {")
    bloc = src[i:src.index("\n};", i)]
    cles = set()
    for l in bloc.split("\n"):
        if re.match(r"^\s*//", l):
            continue
        m = re.match(r"\s*([a-z_]+):\s*\{", l) or re.match(r"\s*([a-z_]+):\s*$", l)
        if m:
            cles.add(m.group(1))
    return cles


def main():
    registre = types_du_registre()
    collecte = types_de_la_collecte()
    print("CONTROLE DU RACCORD REGISTRE DES FAITS PUBLICS -> COLLECTE DE PRESSE")
    print("=" * 72)
    print("  actes declares publics au registre      : %d" % len(registre))
    print("  types acceptes par la collecte          : %d" % len(collecte))

    muets = sorted(t for t in registre if t not in collecte)
    print("  types judiciaires jetes en silence      : %d  %s"
          % (len(muets), "OK" if not muets else "NON"))
    for t in muets:
        print("      - %-42s (acte %s)" % (t, registre[t]))

    # L'INVERSE N'EST PAS UNE ERREUR, et c'est dit pour qu'on ne l'ajoute pas au controle : la
    # collecte accepte legitimement des types qui ne viennent pas du registre judiciaire --
    # nominations, greves, rachats, presse, scrutins. Seul le sens registre -> collecte est un
    # invariant.
    hors = sorted(t for t in collecte if t.startswith("justice_") and t not in registre)
    print("  types `justice_` acceptes hors registre : %d  %s"
          % (len(hors), "OK" if not hors else "NON"))
    for t in hors:
        print("      - %s : la collecte le publierait, le registre ne le produit pas" % t)

    print("=" * 72)
    if muets or hors:
        print("ECHEC : %d type(s) en defaut de raccord." % (len(muets) + len(hors)))
        print("Un fait declare public doit atteindre le Journal, et la collecte ne doit")
        print("pas accepter un type judiciaire que le registre ne produit pas.")
        return 1
    print("CONFORME : les %d faits judiciaires publics ont tous leur ligne de collecte,"
          % len(registre))
    print("et la collecte n'accepte aucun type judiciaire hors registre.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
