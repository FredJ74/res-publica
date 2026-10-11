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

# Mesure du 9 octobre 2026, apres la migration 20261009093112 de la brique d'idempotence
# 262 -> 264 le 10 octobre 2026, avec la purge des chantiers 5 et 6 : offres_emploi_bne -- le
# MIROIR des offres du Bureau national de l'emploi, dont la colonne `places` BORNE une
# autorisation et ne pouvait donc plus venir du navigateur -- et purges_residus_bancs, l'archive
# qui rend une purge reversible (la ligne entiere y est copiee dans la MEME transaction que sa
# suppression).
#
# nocturne, qui porte le catalogue de 260 a 262 tables : actes_nocturnes -- le verrou ET le
# journal des taches de minuit, dont la cle primaire (pays, mecanisme, sujet, jour) porte
# l'idempotence -- et actes_nocturnes_mecanismes, sa liste blanche.
# (Pour memoire : 259 -> 260 le 8 octobre avec recettes_municipales, le COMPTEUR des recettes du
# jour ; et 255 -> 259 le 7 octobre avec villes, villes_empreinte, repartitions_budgetaires et
# repartitions_versements aux chantiers 4E et 4F.)
#
# LES DEUX VALEURS VIENNENT DE LA BASE, pas du CSV, et c'est tout le point de ce controle : elles
# sont relevees par la requete citee en commentaire, puis comparees a ce que le CSV recalcule. Les
# poser depuis le CSV rendrait la verification circulaire -- elle ne dirait plus rien.
# 265 -> 268 le 11 octobre 2026, avec la Garde republicaine : garde_republicaine_postes -- la
# DECLARATION des trois lieux ou la Garde tient faction, qui est ce qui la rend generique plutot
# que codee batiment par batiment --, garde_republicaine_renfort -- le facteur national et son
# UNIQUE echeance par pays, celle qui empeche de prolonger la Garde en la tuant -- et
# garde_republicaine_effectifs, qui dit seulement lequel des gardes est le permanent de son poste.
# L'etat vivant des gardes eux-memes reste au socle PNJ : aucune de ces trois tables ne duplique
# pnj_membres.
# LES DEUX VALEURS CI-DESSOUS SONT RELEVEES EN BASE le 11 octobre 2026 par la requete citee, et
# non recopiees du CSV.
# 268 -> 273 le 11 octobre 2026, a la cloture du Palais presidentiel et a la visite du Palais du
# Gouvernement : les quatre tables de la MEMOIRE DES MANDATS -- presidence_memoire (l etat vivant,
# qui nait vide), et ses trois registres fermes : les sources admises, les sources pas encore
# raccordables, et les actes presidentiels memorables -- plus communications_salles, le registre
# qui dit quelle piece est une tribune et quels postes y sont admis.
# 273 -> 275 le 11 octobre 2026 au soir : les DEUX TABLES DE LA CONFERENCE DE PRESSE --
# conferences_presse (l en-tete : qui a parle, en quelle qualite, depuis quelle tribune, et comment
# la conference s est terminee) et conferences_presse_echanges (la matiere brute : question posee,
# reponse EXACTE, ou refus). Les deux sont classees C, etat vivant pur : un monde neuf nait sans
# aucune conference, et y semer une ligne serait fabriquer une prise de parole qui n a pas eu lieu.
# 275 -> 281 le 11 octobre 2026, deuxieme passe de l Assemblee : les SIX TABLES DE LA SEANCE --
# assemblee_paroles (la file chronologique des demandes de parole et l orateur en cours),
# assemblee_debats (les interventions prononcees, autorisees ou non), assemblee_disciplines (les
# rappels au reglement et les sanctions, avec leur motif verbatim), assemblee_protestations (les
# deputes sortis, et si leur sortie est qualifiee), assemblee_suspensions (les episodes de boycott
# et les suspensions presidentielles) et assemblee_reports (les reports de vote decides par le
# President). LES SIX SONT CLASSEES C, etat vivant pur, et c est plus qu une convention ici : cinq
# protestataires qualifies semes suspendraient la seance d un monde qui vient de naitre, et un
# rappel seme rendrait une sanction immediatement possible sans que personne l ait prononcee.
# 281 -> 285 le 11 octobre 2026, troisieme passe de l Assemblee : les QUATRE TABLES DE
# L ELECTION PRESIDENTIELLE -- assemblee_presidence_scrutins (le scrutin, ses neuf eligibles
# figes, et le vainqueur tire par le serveur), assemblee_presidence_bulletins (une voix par
# depute JOUEUR ; les neuf PNJ s abstiennent toujours), assemblee_presidence_tirage_vu (ce que
# chaque joueur a deja vu du tirage -- un etat SERVEUR, sans quoi il reverrait l annonce a chaque
# visite) et assemblee_presidence_dues (les elections exceptionnelles en attente, inscrites par
# un deuxieme episode de boycott distinct). LES QUATRE SONT CLASSEES C, etat vivant pur : un
# scrutin seme donnerait un President que personne n a elu.
# 286 -> 292 le 12 octobre 2026 : LES SIX TABLES DU SOCLE UNIVERSITAIRE. `qualifications` (le
# catalogue des qualifications REELLES -- des entites qu un code peut exiger, distinctes des
# chaines decoratives CAREERS[].comp), `personnages_qualifications` (celles d un personnage, avec
# leur SOURCE : c est elle qui porte le slot a vie), `universite_cursus` et
# `universite_cursus_jalons` (le catalogue et le modele des jalons), `universite_inscriptions` (un
# seul cursus actif, dates figees a l inscription) et `universite_jalons_accomplis`. LES TROIS
# CATALOGUES SONT CLASSES A, LES TROIS AUTRES C, et les six sont rendues en STRUCTURE SEULE : les
# catalogues naissent VIDES parce que les cursus, leurs noms, leurs durees, leurs jalons et leurs
# prerequis metier sont des arbitrages de game design qu une migration n a pas le droit de rendre
# -- il n y a donc rien a semer aujourd hui. Et semer une inscription ou une qualification
# consommerait le slot universitaire A VIE d un personnage qui n a jamais etudie.
# LES DEUX VALEURS CI-DESSOUS SONT RELEVEES EN BASE le 12 octobre 2026 par la requete citee.
TABLES_ATTENDUES = 292    # 286 -> 292 le 12 octobre 2026 : les six tables du socle universitaire
EMPREINTE_LISTE = "b6a231cb8e5ad003956af113b5d4f379"   # md5(string_agg(relname,',' order by relname collate "C"))

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
