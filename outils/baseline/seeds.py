#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extraction et rendu des SEEDS du baseline (chantier 2E).

Le schema dit COMMENT le monde est fait ; les seeds disent AVEC QUOI il naît.
Les deux ne se melangent jamais : les seeds vivent dans baseline/seeds/, pas
dans baseline/domaines/.

CE QUI EST SEEDE, ET SELON QUELLE STRATEGIE, vient de la classification du
chantier 2C (baseline/classification-donnees.csv). Ce module ne reclasse rien :
il applique. Il range les fichiers par CATEGORIE 2C, pas par un decoupage
invente ici :

    90_socle/        categorie A -- socle generique, identique pour tout empire
    91_empire/       categorie B -- contenu initial propre a un empire
    92_mixte/        categorie D -- une part socle, une part empire ; l'en-tete
                                   du fichier dit laquelle est laquelle
    95_a-regenerer/  miroirs de data.js : le seed ne se copie pas depuis la base,
                                   il se regenere depuis sa source canonique
    99_a-construire/ l'etat initial voulu n'existe nulle part : le fichier dit
                                   precisement ce qu'il faut decider et ecrire

DEUX PRINCIPES QUI NE SE NEGOCIENT PAS
  1. Aucune donnee inventee. Un TODO explicite vaut mieux qu'un faux etat
     initial reconstruit depuis la beta.
  2. Aucun artefact de beta. Les lignes de test, les identifiants engendres en
     cours de partie et les horodatages de la beta ne traversent pas.

C'est PostgreSQL qui ecrit les litteraux, via quote_nullable : aucune regle
d'echappement n'est reimplementee ici. Chaque valeur est emise comme un
litteral texte, que PostgreSQL convertit au type de la colonne a l'insertion.

Usage :
    python3 outils/baseline/seeds.py --sql <repertoire_des_exports>
    python3 outils/baseline/seeds.py --rendre <repertoire_des_exports> <resultat.txt>

Ce module n'ecrit jamais dans la base. La requete qu'il imprime ne contient que
des SELECT.
"""

import csv
import glob
import hashlib
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
BASE = os.path.join(RACINE, "baseline")
CIBLE = os.path.join(BASE, "seeds")

def litteral(liste):
    """Rend une liste de chaines sous forme de VALUES SQL, triee pour etre
    stable. Meme regle de citation que requetes.py."""
    return ", ".join("'" + x.replace("'", "''") + "'" for x in sorted(liste))


REPERTOIRES = {"A": "90_socle", "B": "91_empire", "D": "92_mixte"}

# Stock initial d'un entrepot de ville, arbitre le 5 octobre 2026. Les trois
# villes de Republia recoivent la meme dotation.
STOCK_ENTREPOT_INITIAL = {'alcool': 100, 'bois': 750, 'carburant': 17, 'cereales': 75, 'charbon': 400, 'desinfectant': 32, 'fruits_legumes': 150, 'medicaments': 25, 'metal': 200, 'minerai': 500, 'petrole': 200, 'plantes': 300, 'poisson': 125, 'produits_exotiques': 125, 'tabac': 30, 'textile': 125, 'viande': 85}
CAISSE_ENTREPOT_INITIALE = 5000
BLOB_ENTREPOT = __import__("json").dumps(
    {"entrepot": {"caisse": CAISSE_ENTREPOT_INITIALE,
                  "stock": STOCK_ENTREPOT_INITIAL}},
    ensure_ascii=False, sort_keys=True)


# ---------------------------------------------------------------------------
# REGLES PAR TABLE. Rien n'est filtre ni remis a zero sans une raison ecrite
# ici. Un lecteur doit pouvoir contester chaque ligne de ce bloc.
# ---------------------------------------------------------------------------
FILTRES = {
    "batiments_etat": {
        "ou": "country = 'republic' and building_id like 'entrepot-logistique%'",
        "pourquoi": "SEED PARTIEL, ASSUME. Sur les 38 lignes de la table, seules les TROIS "
                    "de Republia dont l'etat initial est arbitre sont ecrites : les "
                    "entrepots logistiques de Luthecia, Port-Sainte-Marie et Montrouge. "
                    "Les 35 autres -- 11 autres batiments de Republia, les batiments des "
                    "trois autres empires, les lignes techniques (cron-minuit, bne, "
                    "candidatures_postes) et les lignes de test -- attendent l'arbitrage "
                    "de leur etat initial, qui se remplit dans "
                    "baseline/arbitrages/etat-initial-republia.csv. Un seed partiel vaut "
                    "mieux qu'un seed faux : ce qui est decide est ecrit, le reste attend.",
        "ecartees": 35,
    },
    "indices_villes": {
        "ou": "id not like '%zzville%'",
        "pourquoi": "ARBITRAGE COMPLET RENDU LE 5 OCTOBRE 2026 pour Republia. Les CINQ "
                    "indices sont decides et communs aux trois villes -- Luthecia, "
                    "Port-Sainte-Marie, Montrouge : IE 50, ISN 30, Moral 50, PIETE 40, "
                    "SOCIAL 45. Ce sont deja les valeurs des trois lignes en base : le seed "
                    "les reproduit sans rien recalculer ni rien deduire de la bêta. La 4e "
                    "ligne, republic_zzville-cmr, est une ligne de TEST et est ecartee. "
                    "Decision valide pour REPUBLIA uniquement : ne pas generaliser aux "
                    "autres empires.",
        "ecartees": 1,
    },
    "titulaires_pnj": {
        "ou": "id <> 'republic_juge_national'",
        "pourquoi": "ARBITRAGE RENDU LE 5 OCTOBRE 2026 : chaque ville de Republia a son "
                    "PROPRE juge PNJ -- Juge Fontaine a Luthecia, Mireille Sedlex a "
                    "Port-Sainte-Marie, Gerard Bretellewood a Montrouge -- et il n'y a PAS "
                    "de quatrieme juge generique a city = NULL. La ligne "
                    "republic_juge_national est un vestige de l'ancien systeme, anterieur a "
                    "la dimension ville : son identifiant dit `national`, son horodatage est "
                    "du 13 septembre quand les trois lignes de ville sont toutes du 20 "
                    "septembre a la meme seconde, et `juge` est le SEUL poste de la table a "
                    "porter une ville -- les quinze autres titulaires sont tous a NULL. Elle "
                    "n'entre donc pas dans l'etat initial canonique. "
                    "ELLE N'EST PAS SUPPRIMEE DE LA BASE DE PRODUCTION : seul le seed "
                    "l'ecarte. Le monde neuf naît avec 15 titulaires PNJ, dont 3 juges "
                    "municipaux distincts.",
        "ecartees": 1,
    },
    "entrepots_par_ville": {
        "ou": "ville not like 'zz%'",
        "pourquoi": "5 lignes en base, dont 2 de TEST : (zzville-a, entrepot-zztest-a) "
                    "et (zzville-b, entrepot-zztest-b). Les 3 entrepots reels sont "
                    "Luthecia, Port-Sainte-Marie et Montrouge. Les lignes de test ne "
                    "traversent pas : c'est une exclusion de fait, pas un arbitrage.",
        "ecartees": 2,
    },
}

REMISES_A_ZERO = {
    "assemblee_sieges": {
        "colonnes": {"endormi": "false", "endormi_ts": "NULL", "endormi_par": "NULL"},
        "pourquoi": "Le commentaire de la table est explicite : la ligne porte l'identite "
                    "PERMANENTE du depute Gamma et n'est jamais videe. Seules endormi / "
                    "endormi_ts / endormi_par decrivent un etat vivant -- un PJ qui a "
                    "neutralise le Gamma. Les 3 seules fonctions qui ecrivent cette table "
                    "(assemblee_neutraliser_depute, assemblee_reveiller_depute, "
                    "assemblee_reveil_minuit) ne touchent que ces colonnes. Aucune fonction "
                    "n'y insere : les 9 lignes doivent donc preexister. Au premier jour, "
                    "aucun depute n'est endormi -- et c'est deja le cas en base aujourd'hui "
                    "(0 ligne endormie).",
    },
}

# ---------------------------------------------------------------------------
# DOTATIONS FINANCIERES ARBITREES.
#
# Ce seed-ci n'est pas une EXTRACTION, c'est une ECRITURE. Les montants ne
# viennent pas de la base -- ils viennent du tableau d'arbitrage, seule source
# de verite des decisions. La base ne fournit que la liste des lignes a ecrire
# et leur identifiant ; les soldes de bêta ne traversent pas.
#
# Lacune trouvee au chantier 2F : les 53 dotations avaient ete arbitrees et
# consignees dans le tableau, mais aucune ne parvenait au baseline. Un monde
# reconstruit naissait donc sans aucune caisse, et les montants decides
# n'etaient jamais appliques. Les 38 caisses qui vivent dans caisses_batiments
# sont desormais seedees ; les 15 autres vivent dans un blob de batiments_etat,
# dont 3 -- les entrepots -- sont deja seedees, et 12 attendent l'arbitrage de
# l'etat complet de leur batiment.
# ---------------------------------------------------------------------------
def dotations_caisses_batiments():
    """Lit les dotations decidees dans le tableau d'arbitrage. Ne retient que
    celles dont la maison est caisses_batiments : un identifiant prefixe du pays,
    sans « # » (qui designe un volet de blob) ni « . » (une cle de budget)."""
    chemin = os.path.join(BASE, "arbitrages", "dotations-financieres-republia.csv")
    if not os.path.exists(chemin):
        return {}
    out = {}
    with open(chemin, encoding="utf-8") as fh:
        for l in csv.DictReader(fh, delimiter=";"):
            ident, montant = l["identifiant_technique"], l["dotation_deja_decidee"]
            if not montant or not ident.startswith("republic_"):
                continue
            if "#" in ident or "." in ident:
                continue
            out[ident] = int(montant)
    return out


# Colonnes dont la valeur n'est PAS copiee de la base mais ECRITE par arbitrage.
# La valeur est une EXPRESSION SQL, emise telle quelle dans l'INSERT : c'est
# PostgreSQL qui la calcule, et le fichier reste lisible par un humain plutot que
# de porter un litteral jsonb echappe.
EXPRESSIONS_ARBITREES = {
    "batiments_etat": {
        "data": ("to_jsonb(%s::text)" % ("$x$" + BLOB_ENTREPOT + "$x$"),
                 "ARBITRAGE DU 5 OCTOBRE 2026. Le blob est ECRIT, pas copie : les 17 "
                 "quantites de matieres premieres sont celles arbitrees, identiques dans "
                 "les trois villes, et la caisse de l'entrepot vaut la dotation "
                 "d'amorcage de 5 000 FR. Aucune valeur ne vient de la bêta. La cle "
                 "`prixManuel` n'est pas reprise : elle n'existe que sur un des trois "
                 "entrepots, ou elle est vide, et un objet vide equivaut a son absence."),
    },
}

def expressions_evaluees():
    """Expressions SQL EVALUEES pendant l'extraction : c'est leur resultat qui
    devient le litteral du seed. A distinguer des EXPRESSIONS_ARBITREES, qui
    partent telles quelles dans l'INSERT -- celles-ci, elles, peuvent parler de
    la ligne courante, donc porter une valeur differente par ligne."""
    dot = dotations_caisses_batiments()
    if not dot:
        return {}
    cas = " ".join("when %s then %d" % (litteral([i]), m)
                   for i, m in sorted(dot.items()))
    return {
        "caisses_batiments": {
            "data": ("jsonb_build_object('solde', (case z.id %s end))" % cas,
                     "ARBITRAGE DU 5 OCTOBRE 2026. Le solde de chaque caisse est ECRIT "
                     "depuis le tableau d'arbitrage, jamais copie de la bêta. Le `case` "
                     "ci-dessous est engendre depuis "
                     "baseline/arbitrages/dotations-financieres-republia.csv, seule source "
                     "de verite des montants decides."),
        },
    }


def filtres_dynamiques():
    """FILTRES complete par ce qui se deduit du tableau d'arbitrage : la liste
    des caisses a seeder n'est pas recopiee a la main, elle en est lue."""
    f = dict(FILTRES)
    dot = dotations_caisses_batiments()
    if dot:
        f["caisses_batiments"] = {
            "ou": "id in (%s)" % ", ".join(litteral([i]) for i in sorted(dot)),
            "pourquoi": "SEED ECRIT, PAS EXTRAIT. Les %d caisses dont la dotation est "
                        "arbitree sont ecrites avec leur montant decide ; les %d autres "
                        "lignes de la table ne sont pas reprises -- soit elles "
                        "appartiennent aux trois autres empires, soit l'audit du circuit "
                        "fiscal les a declarees vestiges, comptes de transit, "
                        "contreparties ou caisses inertes, soit ce sont des lignes de "
                        "test. Aucun solde de bêta ne traverse : la colonne `data` est "
                        "reconstruite depuis le tableau d'arbitrage."
                        % (len(dot), 151 - len(dot)),
            "ecartees": 151 - len(dot),
        }
    return f


# Tables qui sont un MIROIR d'une source canonique du depot. Leur seed ne se
# copie jamais depuis la base : il se regenere depuis la source. Copier la base
# reviendrait a figer une derive de bêta et a perdre le lien avec la source.
A_REGENERER = {
    "ordres_couts": {
        "source": "data.js",
        "generateur": "outils/generateurs/generer_ordres_couts.py (EXISTE)",
        "quoi": "405 couts en PA et en argent, miroir des ordres declares dans data.js. "
                "Aucune fonction serveur ne l'ecrit.",
        "pourquoi_pas_une_copie": "Ce miroir a deja derive : le chantier du 5 octobre 2026 "
            "y a trouve 24 lignes mortes et 19 ordres gratuits non declares. Copier la base "
            "ferait entrer cette derive dans le baseline et dans tous les mondes a venir.",
        "a_faire": "Le generateur a quitte .scratch/ au chantier 2H : il vit desormais dans "
            "outils/generateurs/. Reste a le faire ecrire directement dans "
            "baseline/seeds/95_a-regenerer/.",
    },
    "ressources_economie": {
        "source": "data.js",
        "generateur": "A ECRIRE. Aucun generateur ne cible cette table aujourd'hui : "
                      "seul .scratch/banc_entreprises_chantier_c.py la mentionne, et c'est "
                      "un banc d'essai, pas un generateur.",
        "quoi": "17 ressources et leurs prix, miroir de data.js.",
        "pourquoi_pas_une_copie": "Meme raison qu'ordres_couts : une table miroir se "
            "regenere, elle ne se recopie pas.",
        "a_faire": "Ecrire le generateur, sur le modele de generer_ordres_couts.py, et le "
            "ranger dans outils/generateurs/ avec les autres.",
    },
    "pa_bonus_differes": {
        "source": "data.js",
        "generateur": "outils/generateurs/generer_pa_bonus_differes.py (EXISTE)",
        "quoi": "10 bonus de PA differes declares dans data.js.",
        "pourquoi_pas_une_copie": "Meme raison. La table porte deja une table d'empreinte "
            "jumelle (pa_bonus_differes_empreinte) dont le role est precisement de detecter "
            "la derive entre data.js et la base : preuve que la source est data.js.",
        "a_faire": "Le generateur existe et charge le VRAI data.js dans JavaScriptCore. "
            "Il a quitte .scratch/ au chantier 2H. Reste a le faire ecrire directement "
            "ici, empreinte comprise.",
    },
    "postes_nommes_regles": {
        "source": "data.js",
        "generateur": "outils/generateurs/generer_postes_nommes.py (EXISTE)",
        "quoi": "17 regles de nomination aux postes, miroir de data.js.",
        "pourquoi_pas_une_copie": "Meme raison, et meme preuve : postes_nommes_regles_empreinte "
            "existe pour surveiller la derive.",
        "a_faire": "Le generateur existe et charge le VRAI data.js dans JavaScriptCore. "
            "Il a quitte .scratch/ au chantier 2H. Reste a le faire ecrire directement "
            "ici, empreinte comprise.",
    },
}

# Anomalies de CONTENU reperees dans une table par ailleurs legitimement seedee.
# Elles sont SIGNALEES, pas corrigees : corriger une dette fonctionnelle n'est
# pas du ressort de ce chantier, et un seed doit reproduire ce qui est ecrit.
# Mais un monde neuf heriterait de l'anomalie : il faut donc qu'elle soit visible
# dans le fichier, pas seulement dans un rapport.
# Anomalies de CONTENU reperees dans une table par ailleurs legitimement seedee.
# Elles sont SIGNALEES, pas corrigees : corriger une dette fonctionnelle n'est
# pas du ressort de ce chantier, et un seed doit reproduire ce qui est ecrit.
# Vide aujourd'hui : la seule anomalie connue, le quatrieme juge de
# titulaires_pnj, a ete tranchee par arbitrage le 5 octobre 2026 et est
# desormais traitee par un filtre documente, non par un simple avertissement.
ANOMALIES_SIGNALEES = {}

# Tables seedees COMPLETEMENT selon la classification 2C, mais qui sont en
# realite des MIROIRS de data.js : un generateur existe deja dans le depot. Le
# seed est produit tel que 2C le demande -- on n'improvise pas une reclassification
# -- mais le fichier porte un avertissement, parce qu'un miroir recopie depuis la
# base fige sa derive. Le miroir des couts d'ordre a deja derive : 24 lignes
# mortes et 19 ordres gratuits non declares, trouves le 5 octobre 2026.
MIROIRS_SIGNALES = {
    "armureries_dotations": "outils/generateurs/generer_miroirs_entreprises.py",
    "commerces_dotations": "outils/generateurs/generer_miroirs_entreprises.py",
    "commerces_types": "outils/generateurs/generer_miroirs_entreprises.py",
    "entreprises_constantes": "outils/generateurs/generer_miroirs_entreprises.py et generer_miroirs_chantiers.py",
    "entreprises_prix_rachat": "outils/generateurs/generer_miroirs_entreprises.py",
    "recettes_commerce": "outils/generateurs/generer_miroirs_entreprises.py",
    "recettes_production": "outils/generateurs/generer_miroirs_entreprises.py",
    "chantiers_besoins_jour": "outils/generateurs/generer_miroirs_chantiers.py",
    "chantiers_paliers": "outils/generateurs/generer_miroirs_chantiers.py",
    "postes_electifs_regles": "outils/generateurs/generer_postes_electifs.py",
    "clubs_football": "outils/generateurs/generer_clubs_football.py",
}

# Les tables dont l'etat initial voulu n'existe nulle part. On n'ecrit PAS de
# donnees : on ecrit ce qu'il faudra decider. Le texte est repris du chantier 2C
# quand 2C avait deja pose la question, et complete des faits etablis en 2E.
POINTEUR = (" Les valeurs a fixer sont listees, ligne par ligne, dans "
            "baseline/arbitrages/dotations-initiales-republia.csv -- un tableau prepare pour "
            "etre rempli, qui ne propose aucun montant deduit d'un solde de bêta.")
POINTEUR2 = (" Les champs a decider sont listes, ligne par ligne, dans "
             "baseline/arbitrages/etat-initial-republia.csv.")

A_CONSTRUIRE = {

    # ---------------------------------------------------------------------
    # Les 13 tables classees reconstruction_explicite au chantier 2C. Pour
    # chacune, 2C avait pose la question ; 2E ajoute les faits etablis depuis.
    # ---------------------------------------------------------------------
    "organisations": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "La table est VIDE en base (0 ligne). Elle melange deux natures "
            "d'organisations. (1) Les clubs de supporters de chaque ville et le Syndicat des "
            "Dockers de Port-Sainte-Marie : authored, mais materialises PARESSEUSEMENT par le "
            "moteur a la premiere sollicitation d'un joueur (doRejoindreClubSupporters, "
            "chargerOuCreerSyndicatDockersPSM) -- ils ne se seedent pas, et c'est normal. "
            "(2) Les DEUX LOGES MACONNIQUES de Republia : Luthecia et Montrouge. Leurs deux "
            "locaux existent bien dans data.js (loge-maconnique de capitale et de ville_b) et "
            "des PNJ y sont poses, mais AUCUN n'est rattache a une ligne organisations : le "
            "lien chef-d'organisation n'existe nulle part. Et surtout, aucune auto-creation "
            "n'existe pour les loges : rien, aujourd'hui, ne les fait naitre.",
        "decision_attendue": "ARBITRAGE DEJA RENDU PAR LE GAME DESIGNER, A CONSTRUIRE : "
            "Republia doit naitre avec ses DEUX loges deja constituees, dotees de leur local "
            "et de leur chef PNJ, parce que la mecanique de prise de pouvoir suppose qu'une "
            "organisation a deja un chef. Chefs arbitres : LUTHECIA -> Frere Jacques "
            "D'Equerre ; MONTROUGE -> Venerable Maitre Duval. Ce qui reste a construire est "
            "le MECANISME, pas la decision : il faut (a) une ligne organisations par loge, "
            "(b) le rattachement de son local, (c) le rattachement de son chef PNJ, et (d) la "
            "creation de ces deux lignes au demarrage d'un monde.",
        "ne_pas_faire": "NE PAS fabriquer un seed compatible avec un mecanisme inexistant. "
            "Tant que le rattachement chef-d'organisation n'existe pas, un INSERT dans "
            "organisations produirait deux loges sans chef -- donc une mecanique de prise de "
            "pouvoir cassee, ce qui est pire que l'absence. NE PAS seeder les clubs de "
            "supporters ni le syndicat des dockers : leur materialisation paresseuse est le "
            "comportement voulu. NE PAS inventer un troisieme PNJ pour Luthecia.",
    },
    "rp_transitions": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "2 lignes, et les DEUX sont inactives (actif = false) -- verifie en "
            "base le 5 octobre 2026. La table est lue par la seule fonction "
            "rp_transition_active(cle), qui rend FALSE sur une cle absente. Une table VIDE se "
            "comporte donc EXACTEMENT comme la production d'aujourd'hui. Les deux cles sont "
            "argent_verrou (« a activer une fois les 24 sites de credit routes ») et "
            "mails_expediteurs_tolerance (« fermee le 20/09/2026 »).",
        "decision_attendue": "ARBITRAGE RENDU : ce n'est ni une regle perenne du moteur, ni "
            "du contenu d'empire, mais un mecanisme TRANSITOIRE lie a la securisation "
            "progressive des anciennes ecritures client. Ses drapeaux ne sont donc pas promus "
            "en regle du socle. Le baseline laisse la table VIDE, ce qui reproduit le "
            "comportement actuel a l'identique. L'objectif architectural est de SUPPRIMER "
            "cette tolerance une fois les ecritures legitimes routees cote serveur.",
        "ne_pas_faire": "ARGENT_VERROU NE DOIT SURTOUT PAS ETRE ACTIVE PREMATUREMENT : des "
            "gains legitimes empruntent encore l'ancien chemin client, et les fermer "
            "maintenant les ferait disparaitre en silence.",
    },
    "produits_manufactures": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "FAIT ETABLI EN 2E qui tranche la question posee en 2C. 2C hesitait "
            "entre « catalogue des produits manufacturables » et « stock des produits "
            "fabriques ». La structure repond : la table n'a AUCUNE colonne de quantite. Ses "
            "colonnes sont produit, recette, prix_vente, pa, encombrement, ville, "
            "building_id, generique_id. Un stock sans quantite n'existe pas : c'est donc un "
            "CATALOGUE. L'unique ligne est l'armoire a souvenirs de ville_a (zone-production), "
            "recette bois 2 / minerai 2, prix 390, 3 PA.",
        "decision_attendue": "ARBITRAGE RENDU LE 5 OCTOBRE 2026 : c'est un CATALOGUE, a la "
            "granularite VILLE. Bonne nouvelle structurelle : la table porte DEJA une colonne "
            "ville, donc la granularite voulue est exprimable telle quelle -- il n'y a pas de "
            "dette de dimensionnement ici, contrairement a recettes_production qui ne porte "
            "que pays. Reste a decider QUELS produits manufactures chaque ville de Republia "
            "propose au premier jour. Une seule ligne pour un empire entier est "
            "vraisemblablement un contenu incomplet, pas un choix.",
        "ne_pas_faire": "Ne pas dupliquer la ligne de ville_a vers les autres villes pour "
            "« completer » : ce serait inventer du contenu. NE PAS lire une ligne de catalogue "
            "comme une quantite disponible, et NE PAS inventer de stock initial de produits "
            "manufactures : les quantites initiales ne concernent que les MATIERES PREMIERES, "
            "arbitrees dans baseline/arbitrages/.",
    },
    "terrains_etat": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "5 lignes, dont 1 portant un marqueur zz. Aucune RPC ne cree de terrain : "
            "les lignes doivent donc PREEXISTER. Leur etat (proprietaire, permis) est vivant.",
        "decision_attendue": "Quels terrains, et dans quel etat, au premier jour ? Perimetre "
            "reel pour Republia : 4 terrains, tous a Luthecia, et non 5 -- la cinquieme "
            "ligne est un terrain de test portant un chantier en cours." + POINTEUR2,
        "ne_pas_faire": "Ne pas seeder un proprietaire herite de la bêta.",
    },
    "entreprises": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "20 commerces. L'identite et l'implantation sont du contenu initial, "
            "mais stock, caisse, prix et matieres vivent dans le MEME blob data, mute par 36 "
            "fonctions. Le crible y trouve 5 lignes portant un marqueur zz.",
        "decision_attendue": "L'etat initial voulu d'un commerce -- stock de depart, caisse -- "
            "doit etre decrit. Perimetre reel pour Republia : 14 commerces authored, et non "
            "20 -- les 6 autres lignes sont 3 armureries de test, 1 ligne sans ville ni "
            "batiment, 1 commerce de test et 1 fonds de commerce cree par un joueur. A "
            "noter : commerces_dotations porte deja, en contenu authored, une dotation de "
            "caisse et de stock par TYPE de commerce." + POINTEUR2,
        "ne_pas_faire": "Ne jamais deduire une caisse initiale d'un solde courant.",
    },
    "dotations_amorcage_caisses": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "159 lignes. Les colonnes solde_avant / montant_verse / solde_apres / "
            "applique_ts en font un JOURNAL d'idempotence des dotations DEJA APPLIQUEES, pas "
            "un bareme. Les 4 empires y figurent.",
        "decision_attendue": "ARBITRAGE RENDU : le bareme est defini par empire et sera ecrit "
            "lors de la construction de l'etat initial. Ce journal ne peut pas en tenir lieu : "
            "il dit ce qui A ETE verse, pas ce qui DOIT l'etre.",
        "ne_pas_faire": "Ne pas prendre ce journal pour un bareme.",
    },
    "budgets_nationaux": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "Une ligne par empire. La structure initiale est voulue ; les valeurs "
            "courantes sont derivees du jeu.",
        "decision_attendue": "Quelles valeurs de depart pour reserveJour, tauxNational, les "
            "rations du refectoire, les matieres de la caserne et le stock de l'armurerie "
            "nationale ? A fixer par empire." + POINTEUR,
        "ne_pas_faire": "Ne jamais deduire une dotation initiale d'un solde courant.",
    },
    "budgets_municipaux": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "4 budgets de ville, dont les soldes sont mutes en jeu.",
        "decision_attendue": "Quelle caisse municipale de depart, et quel taux foncier, par "
            "ville ? A noter : la table porte QUATRE lignes pour TROIS villes -- la "
            "quatrieme, republic_caserne, n'est pas une ville." + POINTEUR,
        "ne_pas_faire": "Ne jamais deduire une dotation initiale d'un solde courant.",
    },
    "budgets_clubs": {
        "strategie_2c": "reconstruction_explicite",
        "constat_2e": "12 budgets de club : une caisse a 0 et un bareme de salaires.",
        "decision_attendue": "Le bareme de salaires est identique sur les 12 clubs des 4 "
            "empires : il releve du socle. Seule la caisse de depart des 3 clubs de "
            "Republia reste a arbitrer." + POINTEUR,
        "ne_pas_faire": "Ne pas seeder une caisse de club heritee de la bêta.",
    },
}

ENTETE = """-- SEED -- {tbl}
-- ============================================================================
-- Table      : public.{tbl}
-- Domaine    : {domaine}
-- Categorie  : {categorie} ({libelle_categorie})
-- Strategie  : {strategie} (classification du chantier 2C)
-- Lignes     : {lignes}
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- {justification}
{bloc_arbitrage}{bloc_regles}-- ============================================================================

"""

ENTETE_TODO = """-- ETAT INITIAL A CONSTRUIRE -- {tbl}
-- ============================================================================
-- Table     : public.{tbl}
-- Domaine   : {domaine}
-- Strategie annoncee au chantier 2C : {strategie_2c}
--
-- CE FICHIER NE CONTIENT AUCUNE DONNEE, ET C'EST VOLONTAIRE.
-- Un TODO explicite vaut mieux qu'un faux etat initial reconstruit depuis la
-- beta. Tant que la decision ci-dessous n'est pas prise, un monde neuf naît
-- sans ces lignes.
--
-- CE QUE L'OBSERVATION ETABLIT
-- {constat}
--
-- CE QU'IL FAUT DECIDER
-- {decision}
--
-- CE QU'IL NE FAUT PAS FAIRE
-- {interdit}
{bloc_deja_arbitre}-- ============================================================================

-- Rien a appliquer. Ce fichier deviendra un seed le jour ou la decision sera
-- prise et ou les lignes voulues seront ecrites -- a la main ou par un
-- generateur, jamais par une copie de la base de beta.
"""

ENTETE_REGENERER = """-- SEED A REGENERER -- {tbl}
-- ============================================================================
-- Table   : public.{tbl}
-- Domaine : {domaine}
-- Source canonique : {source}
-- Generateur       : {generateur}
--
-- CE FICHIER NE CONTIENT AUCUNE DONNEE, ET C'EST VOLONTAIRE.
-- Cette table est un MIROIR d'une source qui vit dans le depot. Son seed se
-- REGENERE depuis cette source ; il ne se copie jamais depuis la base.
--
-- CE QUE LA TABLE PORTE
-- {quoi}
--
-- POURQUOI PAS UNE COPIE DE LA BASE
-- {pourquoi}
--
-- CE QU'IL RESTE A FAIRE
-- {a_faire}
-- ============================================================================

-- Rien a appliquer tant que le generateur n'a pas ecrit ici.
"""


def plier(texte, largeur=74, prefixe="-- "):
    """Replie un paragraphe en commentaires SQL lisibles."""
    mots, lignes, cour = texte.split(), [], ""
    for m in mots:
        if cour and len(cour) + 1 + len(m) > largeur:
            lignes.append(prefixe + cour); cour = m
        else:
            cour = (cour + " " + m).strip()
    if cour:
        lignes.append(prefixe + cour)
    return "\n".join(lignes)


def charger_exports(rep):
    exp = {}
    for f in sorted(glob.glob(os.path.join(rep, "*.txt"))):
        try:
            externe = json.loads(open(f, encoding="utf-8").read())["result"]
        except Exception:
            continue
        m = re.search(r"<untrusted-data-[0-9a-f-]+>\n(.*)\n</untrusted-data-", externe, re.S)
        if not m:
            continue
        try:
            lignes = json.loads(m.group(1))
        except Exception:
            continue
        if lignes and isinstance(lignes[0], dict):
            cle = next(iter(lignes[0]))
            if cle.startswith("export_"):
                exp.update(lignes[0][cle] or {})
    return exp


def classification():
    with open(os.path.join(BASE, "classification-donnees.csv"), encoding="utf-8") as fh:
        return {l["table"]: l for l in csv.DictReader(fh, delimiter=";")}


def colonnes_a_seeder(exp, tbl):
    """Colonnes a ecrire dans l'INSERT, dans l'ordre du catalogue.

    REGLE DES HORODATAGES : une colonne de type timestamp dont le defaut est
    now() est OMISE. La date de creation d'une ligne n'est pas du contenu
    authored : c'est le jour ou le monde est ne. L'omettre laisse le defaut
    jouer, ce qui est exactement le comportement voulu. Toutes les colonnes
    d'horodatage des tables seedees ont un defaut now() -- verifie au 5 octobre
    2026 ; si une table arrive sans ce defaut, elle apparaitra ici et il faudra
    trancher explicitement.
    """
    gardees, omises = [], []
    for c in sorted([x for x in exp["colonnes"] if x["tbl"] == tbl], key=lambda x: x["attnum"]):
        defaut = (c.get("defaut") or "")
        if "timestamp" in c["type"] and defaut.startswith("now()"):
            omises.append(c["attname"]); continue
        gardees.append(c)
    return gardees, omises


def cles_primaires(exp, tbl):
    for k in exp["contraintes"]:
        if k["tbl"] == tbl and k["genre"] == "p":
            m = re.match(r"PRIMARY KEY \((.*)\)$", k["definition"])
            if m:
                return [x.strip() for x in m.group(1).split(",")]
    return []


def requete(exp, tables):
    """Produit le SQL d'extraction. Une branche par table, resultat ordonne."""
    branches = []
    for tbl in tables:
        cols, _ = colonnes_a_seeder(exp, tbl)
        noms = [c["attname"] for c in cols]
        remises = REMISES_A_ZERO.get(tbl, {}).get("colonnes", {})
        expressions = EXPRESSIONS_ARBITREES.get(tbl, {})
        evaluees = expressions_evaluees().get(tbl, {})
        valeurs = []
        for n in noms:
            if n in evaluees:
                # Evaluee ICI : son resultat devient le litteral du seed.
                valeurs.append("quote_nullable((%s)::text)" % evaluees[n][0])
            elif n in expressions:
                # L'expression part telle quelle dans l'INSERT : la base ne la
                # calcule pas a l'extraction, elle la calculera a l'application.
                # PIEGE RENCONTRE ET CORRIGE : l'expression porte deja son propre
                # guillemet-dollar autour du JSON. L'envelopper avec la MEME
                # etiquette refermait le premier et faisait sortir le JSON de la
                # chaine -- « syntax error at or near "{" ». Le delimiteur
                # exterieur doit donc etre distinct, et on le verifie.
                expr = expressions[n][0]
                etiquette = next(e for e in ("$e$", "$q$", "$w$") if e not in expr)
                valeurs.append(etiquette + expr + etiquette)
            elif n in remises:
                # Litteral fixe, voulu : la valeur de beta n'est pas recopiee.
                valeurs.append("'%s'" % remises[n])
            else:
                valeurs.append("quote_nullable(z.%s::text)" % n)
        pk = cles_primaires(exp, tbl) or noms
        ou = filtres_dynamiques().get(tbl, {}).get("ou")
        branches.append(
            "select %s as tbl, %s as rang, 'INSERT INTO public.%s (%s) VALUES (' || "
            "array_to_string(array[%s], ', ') || ');' as ligne\nfrom public.%s z%s"
            % ("'" + tbl + "'",
               "row_number() over (order by %s)" % ", ".join("z." + c for c in pk),
               tbl, ", ".join(noms), ", ".join(valeurs), tbl,
               ("\nwhere " + ou) if ou else ""))
    return ("select jsonb_build_object('export_seeds', jsonb_agg(jsonb_build_object("
            "'tbl', tbl, 'rang', rang, 'ligne', ligne) order by tbl, rang)) as export_seeds\n"
            "from (\n" + "\nunion all\n".join(branches) + "\n) tout")


def rendre(exp, resultat):
    cls = classification()
    libelles = {"A": "socle generique", "B": "contenu initial d'empire",
                "C": "etat vivant", "D": "mixte"}
    brut = open(resultat, encoding="utf-8").read()
    try:
        externe = json.loads(brut)["result"]
    except Exception:
        externe = brut
    m = re.search(r"<untrusted-data-[0-9a-f-]+>\n(.*)\n</untrusted-data-", externe, re.S)
    donnees = json.loads(m.group(1) if m else externe)
    # La requete renvoie une colonne nommee export_seeds contenant un objet qui
    # porte lui aussi la cle export_seeds : on deballe jusqu'a trouver la liste.
    while not isinstance(donnees, list) or (donnees and isinstance(donnees[0], dict)
                                            and "export_seeds" in donnees[0]):
        donnees = donnees[0]["export_seeds"] if isinstance(donnees, list) else donnees["export_seeds"]
    lignes = donnees

    par_table = {}
    for x in lignes:
        par_table.setdefault(x["tbl"], []).append(x["ligne"])

    ecrits, inventaire = 0, {"fichiers": {}, "lignes_par_table": {}, "a_construire": {}}
    for tbl, inserts in sorted(par_table.items()):
        l = cls[tbl]
        cat = l["categorie"]
        rep = os.path.join(CIBLE, REPERTOIRES[cat])
        os.makedirs(rep, exist_ok=True)
        _, omises = colonnes_a_seeder(exp, tbl)

        regles = ""
        fdyn = filtres_dynamiques()
        if tbl in fdyn:
            regles += "--\n-- FILTRE APPLIQUE\n" + plier(fdyn[tbl]["pourquoi"]) + "\n"
        if tbl in REMISES_A_ZERO:
            rz = REMISES_A_ZERO[tbl]
            regles += ("--\n-- COLONNES REMISES A L'ETAT INITIAL : "
                       + ", ".join(sorted(rz["colonnes"])) + "\n"
                       + plier(rz["pourquoi"]) + "\n")
        if tbl in ANOMALIES_SIGNALEES:
            regles += ("--\n-- ANOMALIE DE CONTENU, SIGNALEE ET NON CORRIGEE\n"
                       + plier(ANOMALIES_SIGNALEES[tbl]) + "\n")
        if tbl in MIROIRS_SIGNALES:
            regles += ("--\n-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js\n"
                       + plier("Un generateur existe deja : " + MIROIRS_SIGNALES[tbl]
                               + ". Les lignes ci-dessous sont copiees depuis la base, "
                               "conformement a la strategie seed_complet du chantier 2C -- "
                               "mais copier un miroir fige sa derive. Celui des couts "
                               "d'ordre avait derive de 24 lignes mortes et 19 ordres "
                               "gratuits non declares. A terme, ce fichier doit etre ecrit "
                               "par son generateur depuis data.js, et la table doit "
                               "rejoindre 95_a-regenerer.") + "\n")
        for col, (expr, pourquoi) in sorted(
                list(EXPRESSIONS_ARBITREES.get(tbl, {}).items())
                + list(expressions_evaluees().get(tbl, {}).items())):
            regles += ("--\n-- COLONNE ECRITE PAR ARBITRAGE : " + col + "\n"
                       + plier(pourquoi) + "\n")
        if omises:
            regles += ("--\n-- COLONNES OMISES (defaut now()) : " + ", ".join(omises) + "\n"
                       + plier("La date de creation d'une ligne n'est pas du contenu "
                               "authored : c'est le jour ou le monde est ne. Omettre la "
                               "colonne laisse le defaut jouer.") + "\n")
        arb = ""
        if l["arbitrage"].strip():
            arb = "--\n-- ARBITRAGE DE GAME DESIGN\n" + plier(l["arbitrage"]) + "\n"

        tete = ENTETE.format(
            tbl=tbl, domaine=l["domaine"], categorie=cat,
            libelle_categorie=libelles[cat], strategie=l["strategie"],
            lignes=len(inserts), justification=plier(l["justification"])[3:],
            bloc_arbitrage=arb, bloc_regles=regles)

        corps = "\n".join(inserts) + "\n"
        # Une sequence possedee par une colonne seedee doit etre recalee, sinon
        # le premier INSERT applicatif entre en collision avec un id seede.
        for c in sorted([x for x in exp["colonnes"] if x["tbl"] == tbl], key=lambda x: x["attnum"]):
            d = c.get("defaut") or ""
            if d.startswith("nextval("):
                seq = re.search(r"nextval\('([^']+)'", d).group(1)
                corps += ("\n-- Recalage de la sequence : sans lui, le premier INSERT "
                          "applicatif\n-- entrerait en collision avec un identifiant seede.\n"
                          "select setval('%s', (select coalesce(max(%s), 0) + 1 "
                          "from public.%s), false);\n" % (seq, c["attname"], tbl))
        chemin = os.path.join(rep, tbl + ".sql")
        with open(chemin, "w", encoding="utf-8", newline="") as fh:
            fh.write(tete + corps)
        cle = REPERTOIRES[cat] + "/" + tbl + ".sql"
        inventaire["fichiers"][cle] = hashlib.md5((tete + corps).encode("utf-8")).hexdigest()
        inventaire["lignes_par_table"][tbl] = len(inserts)
        ecrits += 1

    # Les fichiers « a construire » : aucune donnee, la decision attendue.
    rep = os.path.join(CIBLE, "99_a-construire")
    os.makedirs(rep, exist_ok=True)
    for tbl, t in sorted(A_CONSTRUIRE.items()):
        l = cls[tbl]
        bloc = ""
        if t.get("deja_arbitre"):
            bloc = ("--\n-- CE QUI EST DEJA ARBITRE\n"
                    + "\n".join(plier(x) if x.strip() else "--"
                                 for x in t["deja_arbitre"].split("\n")) + "\n")
        if t.get("pourquoi_le_seed_n_est_pas_encore_ecrit"):
            bloc += ("--\n-- POURQUOI LE SEED N'EST PAS ENCORE ECRIT\n"
                     + plier(t["pourquoi_le_seed_n_est_pas_encore_ecrit"]) + "\n")
        texte = ENTETE_TODO.format(
            tbl=tbl, domaine=l["domaine"], strategie_2c=t["strategie_2c"],
            constat=plier(t["constat_2e"])[3:], decision=plier(t["decision_attendue"])[3:],
            interdit=plier(t["ne_pas_faire"])[3:], bloc_deja_arbitre=bloc)
        chemin = os.path.join(rep, tbl + ".sql")
        with open(chemin, "w", encoding="utf-8", newline="") as fh:
            fh.write(texte)
        inventaire["fichiers"]["99_a-construire/" + tbl + ".sql"] = \
            hashlib.md5(texte.encode("utf-8")).hexdigest()
        inventaire["a_construire"][tbl] = t["decision_attendue"]

    # Les miroirs d'une source du depot : le fichier dit ou est la source et
    # quel generateur doit l'ecrire.
    rep = os.path.join(CIBLE, "95_a-regenerer")
    os.makedirs(rep, exist_ok=True)
    for tbl, t in sorted(A_REGENERER.items()):
        l = cls[tbl]
        texte = ENTETE_REGENERER.format(
            tbl=tbl, domaine=l["domaine"], source=t["source"], generateur=t["generateur"],
            quoi=plier(t["quoi"])[3:], pourquoi=plier(t["pourquoi_pas_une_copie"])[3:],
            a_faire=plier(t["a_faire"])[3:])
        with open(os.path.join(rep, tbl + ".sql"), "w", encoding="utf-8", newline="") as fh:
            fh.write(texte)
        inventaire["fichiers"]["95_a-regenerer/" + tbl + ".sql"] = \
            hashlib.md5(texte.encode("utf-8")).hexdigest()
        inventaire.setdefault("a_regenerer", {})[tbl] = t["source"]

    with open(os.path.join(CIBLE, "INVENTAIRE.json"), "w", encoding="utf-8") as fh:
        json.dump(inventaire, fh, indent=1, ensure_ascii=False, sort_keys=True)

    print("%d tables seedees, %d lignes d'INSERT" % (ecrits, sum(len(v) for v in par_table.values())))
    print("%d tables a regenerer depuis leur source canonique" % len(A_REGENERER))
    print("%d tables en etat initial a construire" % len(A_CONSTRUIRE))
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    exp = charger_exports(sys.argv[2])
    if "colonnes" not in exp:
        raise SystemExit("exports introuvables ou incomplets dans " + sys.argv[2])
    cls = classification()
    a_seeder = sorted(t for t, l in cls.items()
                      if l["strategie"] in ("seed_complet", "seed_filtre")
                      and t not in A_CONSTRUIRE)
    if sys.argv[1] == "--sql":
        print(requete(exp, a_seeder))
        return 0
    if sys.argv[1] == "--rendre":
        return rendre(exp, sys.argv[3])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
