#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Garde-fou du WORKFLOW (chantier 2G).

Les autres controles verifient le CONTENU du baseline. Celui-ci verifie le
PROCESSUS : que le dépôt est encore range comme le workflow l'exige, et qu'une
evolution n'a pas repris les mauvaises habitudes.

C'est le controle qui empeche la regression. Un baseline peut etre parfait et le
processus deja reparti de travers -- un .sql pose a la racine, une migration sans
horodatage, un baseline edite a la main. Rien de tout cela ne se voit dans un
controle de fidelite.

HUIT INVARIANTS, qui echouent independamment.

  1. AUCUN .sql A LA RACINE          c'est la dispersion qui a rendu l'histoire
                                     illisible : 184 fichiers sans ordre ni
                                     garantie d'application
  2. ARCHIVE RACINE COMPLETE          les 184 migrations historiques et les 3
                                     fichiers non appliques sont tous la
  3. MIGRATIONS BIEN NOMMEES          <AAAAMMJJHHMMSS>_<nom>.sql, sans doublon
                                     d'horodatage
  4. MIGRATIONS POSTERIEURES AU       une migration anterieure au point de coupe
     POINT DE COUPE                   est deja dans le baseline : la rejouer est
                                     au mieux inutile, au pire destructeur
  5. SQL DANS SES TROIS MAISONS       baseline/, migrations/, historique/ -- et
                                     nulle part ailleurs
  6. LE PROCESSUS EST ECRIT           WORKFLOW-SUPABASE.md existe et les README
                                     y renvoient au lieu de le repeter
  7. AUCUN DOUBLON D'OUTIL            un seul moteur de rendu, un seul
                                     extracteur, un seul verificateur par objet
  8. AUCUN SCRIPT A LA RACINE         ni correctif ponctuel, ni generateur : 342
                                     patch_/fix_ encombraient la racine, et les
                                     8 generateurs dont le projet depend vivaient
                                     dans un repertoire de brouillon

Usage :
    python3 outils/baseline/verifier-workflow.py
Code de sortie 0 si le processus tient, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import glob
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))

ARCHIVE = os.path.join(RACINE, "historique", "sql-racine")
MIGRATIONS = os.path.join(RACINE, "migrations")
BASELINE = os.path.join(RACINE, "baseline")

# Releve au chantier 2G, apres l'archivage. Si l'un de ces comptes bouge, c'est
# soit un ajout a l'archive -- ce qui n'a pas de sens, elle est close -- soit une
# suppression, ce qui serait une perte de trace.
MIGRATIONS_HISTORIQUES = 184
NON_APPLIQUEES = 3
PATCHS_PONCTUELS = 342       # 289 patch_*.py + 53 fix_*.py, archives au 2H
GENERATEURS = 9              # 8 miroirs de data.js (sortis de .scratch/ au 2H)
                             # + generer_referentiels_serveur.py, qui produit
                             # api/_referentiels-generes.js (chantier 4B). Ce
                             # nombre est declare pour qu'un generateur ajoute
                             # ou perdu se voie : c'est ce refus qui a signale
                             # le neuvieme le jour de sa naissance.

MOTIF_MIGRATION = re.compile(r"^(\d{14})_[a-z0-9_]+\.sql$")

# Compose a l'execution, et non ecrit en clair : un detecteur qui porte son
# propre motif se signale lui-meme.
CHEMIN_HISTORIQUE = ".scratch" + "/" + "generer_"

# Les seules maisons ou un .sql a un sens, et pourquoi.
MAISONS = {
    "baseline": "l'etat canonique, genere -- jamais edite a la main",
    "migrations": "les evolutions futures, une par fichier horodate",
    "historique": "l'archive documentaire, non rejouable",
}

# Un seul outil par responsabilite. Si deux fichiers repondent au meme motif,
# c'est qu'une duplication s'est reinstallee -- et le dernier execute gagnerait.
RESPONSABILITES = {
    "rendu du schema": ["rendre.py"],
    "rendu des seeds": ["seeds.py"],
    "requetes d'introspection": ["requetes.py"],
    "controle global": ["verifier-baseline.py"],
    "reconstruction": ["reconstruire.py"],
}


class Rapport:
    def __init__(self):
        self.pbs = {}

    def famille(self, nom):
        self.courante = nom
        self.pbs.setdefault(nom, [])
        print("\n%s" % nom)
        print("  " + "-" * 68)

    def verif(self, libelle, obtenu, attendu):
        ok = obtenu == attendu
        print("  %-46s %8s / %-8s %s" % (libelle, obtenu, attendu, "OK " if ok else "NON"))
        if not ok:
            self.pbs[self.courante].append("%s : %s au lieu de %s" % (libelle, obtenu, attendu))

    def anomalie(self, texte):
        self.pbs[self.courante].append(texte)

    def note(self, texte):
        print("  %s" % texte)


def main():
    r = Rapport()
    print("GARDE-FOU DU WORKFLOW SUPABASE")

    # ------------------------------------------------- 1. rien a la racine
    r.famille("1. AUCUN .sql A LA RACINE")
    a_la_racine = sorted(os.path.basename(f) for f in glob.glob(os.path.join(RACINE, "*.sql")))
    r.verif("fichiers .sql a la racine du depot", len(a_la_racine), 0)
    for f in a_la_racine:
        r.anomalie("fichier .sql a la racine : %s -- il appartient a migrations/ "
                   "s'il doit etre applique, a historique/ sinon" % f)
    if not a_la_racine:
        r.note("c'est la dispersion de 184 fichiers ici qui avait rendu l'histoire illisible")

    # ------------------------------------------- 2. archive racine complete
    r.famille("2. ARCHIVE DES SQL DE LA RACINE")
    hist = sorted(glob.glob(os.path.join(ARCHIVE, "migrations", "*.sql")))
    non = sorted(glob.glob(os.path.join(ARCHIVE, "non-appliquees", "*.sql")))
    r.verif("migrations historiques archivees", len(hist), MIGRATIONS_HISTORIQUES)
    r.verif("fichiers non appliques archives", len(non), NON_APPLIQUEES)
    mal_nommes = [os.path.basename(f) for f in hist
                  if not os.path.basename(f).startswith("migration_")]
    r.verif("archives au nom inattendu", len(mal_nommes), 0)
    for f in mal_nommes:
        r.anomalie("archive au nom inattendu : " + f)
    if not os.path.exists(os.path.join(ARCHIVE, "README.md")):
        r.anomalie("l'archive n'a pas de README : une archive sans explication "
                   "redevient un piege")

    # --------------------------------------------- 3. et 4. les migrations
    r.famille("3. MIGRATIONS FUTURES : NOMMAGE")
    fichiers = sorted(os.path.basename(f) for f in glob.glob(os.path.join(MIGRATIONS, "*.sql")))
    mauvais = [f for f in fichiers if not MOTIF_MIGRATION.match(f)]
    r.verif("migrations au nom non conforme", len(mauvais), 0)
    for f in mauvais:
        r.anomalie("nom non conforme : %s -- attendu <AAAAMMJJHHMMSS>_<nom>.sql" % f)
    horodatages = [MOTIF_MIGRATION.match(f).group(1) for f in fichiers if MOTIF_MIGRATION.match(f)]
    doublons = sorted({h for h in horodatages if horodatages.count(h) > 1})
    r.verif("horodatages en double", len(doublons), 0)
    for h in doublons:
        r.anomalie("deux migrations partagent l'horodatage %s : l'ordre devient "
                   "ambigu" % h)
    r.note("%d migration(s) en attente d'application ou deja appliquee(s)" % len(fichiers))

    r.famille("4. MIGRATIONS POSTERIEURES AU POINT DE COUPE")
    ctl = os.path.join(BASELINE, "CONTROLE-GLOBAL.json")
    coupe = None
    if os.path.exists(ctl):
        releve = json.load(open(ctl, encoding="utf-8")).get("releve_le", "")
        m = re.match(r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})", releve)
        if m:
            coupe = "".join(m.groups())
            r.note("point de coupe du baseline : %s" % releve)
    if coupe is None:
        r.anomalie("point de coupe illisible dans CONTROLE-GLOBAL.json")
    else:
        anterieures = [f for f, h in zip(fichiers, horodatages) if h < coupe]
        r.verif("migrations anterieures au point de coupe", len(anterieures), 0)
        for f in anterieures:
            r.anomalie("%s est anterieure au point de coupe : son effet est deja "
                       "dans le baseline, la rejouer est au mieux inutile" % f)

    # --------------------------------------- 5. le SQL dans ses trois maisons
    r.famille("5. SQL DANS SES TROIS MAISONS")
    egares = []
    for chemin in glob.glob(os.path.join(RACINE, "**", "*.sql"), recursive=True):
        rel = os.path.relpath(chemin, RACINE)
        tete = rel.split(os.sep)[0]
        if tete in MAISONS or tete == ".scratch" or tete.startswith("."):
            continue
        egares.append(rel)
    r.verif("fichiers .sql hors des trois maisons", len(egares), 0)
    for f in egares[:10]:
        r.anomalie("fichier .sql egare : " + f)
    for maison, role in sorted(MAISONS.items()):
        n = len(glob.glob(os.path.join(RACINE, maison, "**", "*.sql"), recursive=True))
        print("  %-14s %4d fichiers  %s" % (maison + "/", n, role))

    # ----------------------------------------------- 6. le processus est ecrit
    r.famille("6. LE PROCESSUS EST ECRIT")
    doc = os.path.join(RACINE, "WORKFLOW-SUPABASE.md")
    r.verif("WORKFLOW-SUPABASE.md present", 1 if os.path.exists(doc) else 0, 1)
    if os.path.exists(doc):
        texte = open(doc, encoding="utf-8").read()
        for attendu in ("migrations/", "baseline/", "historique/",
                        "controler-tout.py", "apply_migration"):
            if attendu not in texte:
                r.anomalie("le processus ne mentionne pas %s" % attendu)
        r.verif("longueur du processus, en lignes", "%d" % len(texte.splitlines()),
                "%d" % len(texte.splitlines()))
    renvois = 0
    for readme in (os.path.join(BASELINE, "README.md"),
                   os.path.join(ICI, "README.md"),
                   os.path.join(MIGRATIONS, "README.md"),
                   os.path.join(ARCHIVE, "README.md")):
        if os.path.exists(readme) and "WORKFLOW-SUPABASE.md" in open(readme, encoding="utf-8").read():
            renvois += 1
    r.verif("README renvoyant au processus", renvois, 4)
    if renvois < 4:
        r.anomalie("un README decrit le processus au lieu d'y renvoyer, ou ne le "
                   "cite pas : c'est ainsi qu'une documentation se met a diverger")

    # ------------------------------------------------- 7. aucun doublon d'outil
    r.famille("7. UN SEUL OUTIL PAR RESPONSABILITE")
    outils = {os.path.basename(f) for f in glob.glob(os.path.join(ICI, "*.py"))}
    for responsabilite, attendus in sorted(RESPONSABILITES.items()):
        presents = [a for a in attendus if a in outils]
        candidats = sorted(o for o in outils
                           if any(o.startswith(a.replace(".py", "")) for a in attendus))
        ok = len(presents) == 1 and len(candidats) == 1
        print("  %-30s %-26s %s" % (responsabilite, ", ".join(candidats) or "ABSENT",
                                    "OK " if ok else "NON"))
        if not ok:
            r.anomalie("%s : %d outil(s) -- %s. Deux outils pour une meme "
                       "responsabilite, et le dernier execute gagne."
                       % (responsabilite, len(candidats), ", ".join(candidats) or "aucun"))

    # ------------------------------------------- 8. aucun script a la racine
    r.famille("8. AUCUN SCRIPT TECHNIQUE A LA RACINE")
    py_racine = sorted(os.path.basename(f) for f in glob.glob(os.path.join(RACINE, "*.py")))
    r.verif("fichiers .py a la racine du depot", len(py_racine), 0)
    for f in py_racine:
        ou = ("historique/patchs-ponctuels/" if f.startswith(("patch_", "fix_"))
              else "outils/ s'il est reutilisable, historique/ sinon")
        r.anomalie("script .py a la racine : %s -- il appartient a %s" % (f, ou))

    arch = os.path.join(RACINE, "historique", "patchs-ponctuels")
    r.verif("correctifs ponctuels archives",
            len(glob.glob(os.path.join(arch, "*.py"))), PATCHS_PONCTUELS)

    gen = os.path.join(RACINE, "outils", "generateurs")
    r.verif("generateurs dans outils/generateurs", len(glob.glob(os.path.join(gen, "*.py"))),
            GENERATEURS)
    restes = sorted(os.path.basename(f)
                    for f in glob.glob(os.path.join(RACINE, ".scratch", "generer_*.py")))
    r.verif("generateurs restes dans .scratch", len(restes), 0)
    for f in restes:
        r.anomalie("generateur dans un repertoire de brouillon : %s -- le projet en "
                   "depend, il appartient a outils/generateurs/" % f)

    # Un chemin historique encore cite serait une rupture silencieuse : le script
    # existe, mais plus la ou son appelant le cherche.
    morts = []
    for motif in ("**/*.py", "**/*.json", "**/*.md"):
        for chemin in glob.glob(os.path.join(RACINE, motif), recursive=True):
            rel = os.path.relpath(chemin, RACINE)
            if rel.startswith("historique" + os.sep) or rel.startswith("node_modules"):
                continue
            try:
                texte = open(chemin, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            if CHEMIN_HISTORIQUE in texte:
                morts.append(rel)
    r.verif("fichiers citant encore l'ancien chemin", len(sorted(set(morts))), 0)
    for f in sorted(set(morts))[:6]:
        r.anomalie("chemin historique encore cite dans %s" % f)

    # ----------------------------------------------------------------- verdict
    print("\n" + "=" * 72)
    total = sum(len(v) for v in r.pbs.values())
    for fam in r.pbs:
        n = len(r.pbs[fam])
        print("  %-52s %s" % (fam, "CONFORME" if not n else "ECHEC (%d)" % n))
    if total:
        print("\nECHEC : %d regression(s) du workflow" % total)
        for fam, liste in r.pbs.items():
            for p in liste:
                print("  - [%s] %s" % (fam.split(".")[0], p))
        return 1
    print("\nCONFORME : le processus tient. Aucun .sql a la racine, l'archive est")
    print("           complete, les migrations sont nommees et posterieures au")
    print("           point de coupe, et chaque responsabilite a un seul outil.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
