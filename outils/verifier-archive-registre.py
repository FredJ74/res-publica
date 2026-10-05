#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifie l'integrite de l'archive documentaire historique/registre-supabase/.

Ce que l'outil prouve, SANS acceder a la base :
  1. le nombre de fichiers archives est celui attendu ;
  2. chaque nom de fichier est <version>_<nom>.sql et concorde avec son en-tete ;
  3. aucune version n'est absente, aucune n'est en double ;
  4. le SQL de chaque fichier correspond exactement a l'empreinte MD5 que son
     en-tete declare -- donc le fichier n'a pas ete modifie depuis l'export ;
  5. l'empreinte globale recalculee sur les 539 (version, md5) est identique a
     celle relevee dans le registre Supabase au moment de l'export.

Le point 5 est la garantie forte : une seule valeur de 32 caracteres atteste que
l'ensemble des versions ET l'integralite des SQL archives sont conformes au
registre. La modifier sans modifier le contenu est impossible en pratique.

Usage :
    python3 outils/verifier-archive-registre.py
Code de sortie 0 si tout est conforme, 1 sinon.

Cet outil ne lit que des fichiers et n'ecrit rien. Il n'execute aucun SQL.
"""

import hashlib
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHIVE = os.path.join(RACINE, "historique", "registre-supabase")
EMPREINTES = os.path.join(ARCHIVE, "empreintes.json")
MARQUEUR = "-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<"

RE_NOM = re.compile(r"^(\d{14})_(.+)\.sql$")
RE_VERSION = re.compile(r"^-- Version Supabase  : (\S+)$", re.M)
RE_NOM_ORIG = re.compile(r"^-- Nom original      : (.+)$", re.M)
RE_CATEGORIE = re.compile(r"^-- Categorie         : (DDL|DML|MIXTE|AUTRE) ", re.M)
RE_MD5 = re.compile(r"^-- MD5 du SQL historique : ([0-9a-f]{32})$", re.M)


def erreur(liste, message):
    liste.append(message)


def main():
    pbs = []

    if not os.path.isdir(ARCHIVE):
        print("ECHEC : dossier d'archive introuvable : " + ARCHIVE)
        return 1
    if not os.path.isfile(EMPREINTES):
        print("ECHEC : empreintes.json introuvable : " + EMPREINTES)
        return 1

    attendu = json.load(open(EMPREINTES, encoding="utf-8"))

    fichiers = sorted(f for f in os.listdir(ARCHIVE) if f.endswith(".sql"))
    print("Fichiers .sql trouves      : %d (attendu %d)" % (len(fichiers), attendu["entrees"]))
    if len(fichiers) != attendu["entrees"]:
        erreur(pbs, "nombre de fichiers incorrect")

    vus = {}
    categories = {}
    couples_md5 = []
    couples_noms = []

    for nom_fichier in fichiers:
        m = RE_NOM.match(nom_fichier)
        if not m:
            erreur(pbs, "nom de fichier non conforme : " + nom_fichier)
            continue
        version, nom = m.group(1), m.group(2)

        contenu = open(os.path.join(ARCHIVE, nom_fichier), encoding="utf-8", newline="").read()
        if contenu.count(MARQUEUR) != 1:
            erreur(pbs, "marqueur de debut absent ou en double : " + nom_fichier)
            continue
        entete, corps = contenu.split(MARQUEUR + "\n", 1)

        mv = RE_VERSION.search(entete)
        mn = RE_NOM_ORIG.search(entete)
        mc = RE_CATEGORIE.search(entete)
        mm = RE_MD5.search(entete)
        if not (mv and mn and mc and mm):
            erreur(pbs, "en-tete documentaire incomplet : " + nom_fichier)
            continue

        if mv.group(1) != version:
            erreur(pbs, "version de l'en-tete != nom de fichier : " + nom_fichier)
        if mn.group(1) != nom:
            erreur(pbs, "nom de l'en-tete != nom de fichier : " + nom_fichier)

        if version in vus:
            erreur(pbs, "version en double : %s (%s et %s)" % (version, vus[version], nom_fichier))
        vus[version] = nom_fichier

        md5_reel = hashlib.md5(corps.encode("utf-8")).hexdigest()
        if md5_reel != mm.group(1):
            erreur(pbs, "SQL ALTERE : %s (en-tete %s, calcule %s)"
                   % (nom_fichier, mm.group(1), md5_reel))

        categories[mc.group(1)] = categories.get(mc.group(1), 0) + 1
        couples_md5.append(version + ":" + md5_reel)
        couples_noms.append(version + "_" + nom)

    print("Versions distinctes        : %d" % len(vus))
    print("Doublons de version        : %d" % (len(fichiers) - len(vus)))

    emp_globale = hashlib.md5(",".join(sorted(couples_md5)).encode("utf-8")).hexdigest()
    emp_noms = hashlib.md5(",".join(sorted(couples_noms)).encode("utf-8")).hexdigest()

    print("Empreinte globale          : %s (attendu %s)" % (emp_globale, attendu["empreinte_globale"]))
    print("Empreinte des noms         : %s (attendu %s)" % (emp_noms, attendu["empreinte_noms"]))
    if emp_globale != attendu["empreinte_globale"]:
        erreur(pbs, "empreinte globale non conforme au registre")
    if emp_noms != attendu["empreinte_noms"]:
        erreur(pbs, "empreinte des noms non conforme au registre")

    print("Repartition par categorie  : " + ", ".join(
        "%s=%d" % (k, categories.get(k, 0)) for k in ("DDL", "DML", "MIXTE", "AUTRE")))
    for k in ("DDL", "DML", "MIXTE", "AUTRE"):
        if categories.get(k, 0) != attendu["categories"].get(k, 0):
            erreur(pbs, "categorie %s : %d fichiers, %d attendus"
                   % (k, categories.get(k, 0), attendu["categories"].get(k, 0)))

    print()
    if pbs:
        print("ECHEC : %d anomalie(s)" % len(pbs))
        for p in pbs:
            print("  - " + p)
        return 1
    print("CONFORME : les %d entrees archivees correspondent exactement au registre." % len(vus))
    return 0


if __name__ == "__main__":
    sys.exit(main())
