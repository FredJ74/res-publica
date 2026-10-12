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
# 292 -> 296 le 12 octobre 2026 au soir : LES QUATRE TABLES DU CODE PENAL. `infractions` est le
# catalogue canonique des 39 infractions -- un MIROIR de PEINES / PEINES_ACTES / ACTES_ILLEGAUX de
# plateau-core.js, ou chaque peine de reference est exactement ce que getPeineParActe rend cote
# navigateur ; `infractions_categories` porte les quatre categories generiques, qui sont la peine
# HERITEE des 23 actes sans bareme propre ; `infractions_alias` est le mecanisme de resolution des
# nomenclatures historiques, VOLONTAIREMENT VIDE parce que les trois paires de doublons relevees
# portent des durees differentes de part et d'autre et qu'en resoudre une changerait une peine ;
# `infractions_empreinte` est la sentinelle du miroir, meme patron que villes_empreinte.
# LES QUATRE SONT CLASSEES A : le code penal fait partie du socle d'un monde neuf, et sans lui la
# porte du jugement refuse tout. Les deux catalogues sont en RECONSTRUCTION EXPLICITE -- leur seed
# doit etre ecrit par generer_infractions.py depuis plateau-core.js, pas copie depuis la base, car
# copier un miroir fige sa derive au lieu de la detecter.
# LES DEUX VALEURS CI-DESSOUS SONT RELEVEES EN BASE le 12 octobre 2026 par la requete citee.
# 296 -> 298 le 12 octobre 2026, nuit : LES DEUX TABLES DE LA CHRONOLOGIE JUDICIAIRE.
# `dossiers_judiciaires_actes` porte les faits dates d'un dossier -- plainte, enquete, non-lieu,
# poursuites, saisine, abandon, requalification, relaxe, condamnation -- et elle est APPEND-ONLY
# a trois verrous : aucun GRANT client, aucune policy, et un declencheur qui refuse UPDATE et
# DELETE meme a service_role. `dossiers_judiciaires_actes_types` est sa liste blanche, et c'est
# une TABLE et non une contrainte CHECK pour que les couches futures (temoins, audience, appel,
# execution de peine) s'y ajoutent par une ligne.
# LA PREMIERE EST CLASSEE C, LA SECONDE A. Semer un acte judiciaire fabriquerait un fait de
# procedure que personne n'a pose, et la table etant append-only il serait ineffacable ; mais
# sans le registre des TYPES, chaque acte fait LEVER la transaction qui le pose -- donc plus
# aucun jugement possible dans un monde neuf.
# LES DEUX VALEURS CI-DESSOUS SONT RELEVEES EN BASE le 12 octobre 2026 par la requete citee.
# 298 -> 299 le 12 octobre 2026, nuit : `dossiers_auditions`, LES PROCES-VERBAUX D'AUDITION.
# Un fait par dossier et par personne : ce qu'elle a declare, verbatim, ou son refus explicite de
# repondre. CLASSEE C, et c'est le meme raisonnement que pour la chronologie : semer un PV
# fabriquerait une declaration que personne n'a faite, et la table etant append-only elle serait
# ineffacable.
# 299 -> 301 le 12 octobre 2026 : `justice_indemnites` et `signalements_police`.
# La premiere porte les creances d'indemnisation pour detention executee a tort -- 1 000 FR par
# jour REELLEMENT purge au-dela de la peine definitive -- et sa file est FIFO stricte. La seconde
# porte les appels a la police : un citoyen de Republia signale un recherche present dans sa
# piece, et le serveur revalide dix secondes plus tard que la cible y est ENCORE.
# LES DEUX SONT CLASSEES C. Un monde neuf ne doit rien a personne, et aucune intervention de
# police n'y est en cours.
# 301 -> 305 le 12 octobre 2026 au soir : `justice_avocats_commis`, `administrateurs`,
# `admin_journal` et `admin_actions_tribunal`.
# LA PREMIERE EST CLASSEE A : elle porte le CHA 16 des trois avocats commis d'office, c'est-a-dire
# une REGLE, pas un etat vivant -- sans ses lignes, la procedure simplifiee est inerte dans tout
# le pays. `admin_actions_tribunal` est A pour la meme raison : ses dix lignes SONT le perimetre
# arbitre de l'incarnation, et l'elargir est une decision de game design.
# LES DEUX AUTRES SONT C, et il n'y a pas d'hesitation : un monde neuf doit naitre avec une
# administration VIDE -- donc fermee -- et un audit VIDE. Semer un compte administrateur
# reviendrait a publier un identifiant d'autorite dans le depot.
#
# 12 OCTOBRE 2026, LE SOIR -- SIX TABLES DE PLUS, 305 -> 311 : `administrateurs_invitations`,
# `justice_barreau_qualifications`, `avocats_barreau`, `defenses_demandes`, `temoins_citations` et
# `audience_paroles`.
# UNE SEULE EST CLASSEE A : `justice_barreau_qualifications`, la liste blanche des qualifications
# qui ouvrent la profession d'avocat -- un registre d'autorite, du meme genre que
# `actes_nocturnes_mecanismes`. Elle est pourtant en `structure_seule` et non en `seed_complet`,
# parce qu'elle est VIDE EN BASE : le cursus universitaire de l'avocat n'est pas arbitre, et la
# consigne interdit d'inventer un diplome. Le jour ou elle portera une ligne, elle passera en
# `seed_complet`.
# `administrateurs_invitations` EST C malgre sa ligne : une invitation NOMME UNE PERSONNE REELLE
# et appartient a ce deploiement-ci, pas au socle d'un monde. Meme raison que `administrateurs`,
# dont elle est la porte d'entree.
# LES QUATRE AUTRES SONT C sans hesitation : un monde neuf nait sans affaire, donc sans barreau
# publie, sans demande de defense, sans temoin cite et sans parole accordee.
# 12 OCTOBRE 2026, LA NUIT -- SIX TABLES DE PLUS EN NET, 311 -> 317. SEPT NAISSENT et UNE MEURT.
# LES QUATRE REGISTRES DE CARRIERE SONT CLASSES A ET SEEDES : `carrieres` (les dix familles,
# miroir de CAREERS), `habilitations`, `habilitations_carrieres` et `habilitations_postes`. Sans
# eux, `habilitation_ouverte` rend false partout -- fail closed -- et aucune fonction specialisee
# n'est accessible dans un monde neuf. `justice_faits_publics` est A pour la meme raison : sans
# ses douze lignes, aucun fait judiciaire n'atteint le Journal.
# `carrieres_acquises` est C : la seconde carriere d'un personnage est un etat vivant, et sa cle
# primaire -- le PERSONNAGE -- est ce qui borne les carrieres a deux pour toute une existence.
# `audience_messages` est C : un monde neuf nait sans proces, donc sans debats.
# ET `justice_barreau_qualifications` A DISPARU : l'abstraction d'attente du barreau, posee vide
# le 12 octobre au soir faute d'arbitrage, est SUPPRIMEE -- la carriere JUSTICE qualifie desormais.
TABLES_ATTENDUES = 317
EMPREINTE_LISTE = "75f5f86ab69bb8ab641b2073cff28c3c"   # md5(string_agg(relname,',' order by relname collate "C"))

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
