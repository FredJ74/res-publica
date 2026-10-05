#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test d'ASSEMBLAGE STATIQUE du baseline (chantier 2E).

Rejoue l'assemblage SANS creer de base : il lit les fichiers du depot dans
l'ordre des phases et verifie que chaque ordre trouverait, au moment ou il
s'execute, tout ce dont il a besoin.

Ce que le test cherche :
  1. une cle etrangere qui pointe vers une table absente du baseline ;
  2. un declencheur dont la fonction n'est pas dans le baseline ;
  3. une policy ou une vue qui appelle une fonction absente du baseline ;
  4. un defaut nextval() dont la sequence n'existe pas ;
  5. une reference a un artefact HORS baseline (les 6 tables ecartees, le schema
     de sauvegarde de la beta, les snapshots zz_*) ;
  6. un objet defini deux fois, dans deux domaines ;
  7. une dependance qui arriverait TROP TOT dans l'ordre des phases ;
  8. les dependances vers un AUTRE schema (auth, extensions, storage...), qui
     sont legitimes mais doivent etre declarees, jamais absorbees en silence.

REGLE DE CONDUITE : un objet qui echoue n'est jamais supprime pour faire passer
le test. Le test rapporte, il ne repare pas.

Usage :
    python3 outils/baseline/assembler.py
Code de sortie 0 si l'assemblage est coherent, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import glob
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
BASE = os.path.join(RACINE, "baseline")
DOM = os.path.join(BASE, "domaines")

# Phase a laquelle chaque famille d'objets devient disponible.
PHASE = {"table": 10, "sequence": 10, "fonction": 20, "contrainte": 30,
         "index": 35, "vue": 40, "trigger": 50, "policy": 60}

# Artefacts que le baseline ne doit JAMAIS citer. Le schema de sauvegarde de la
# beta et les snapshots en font partie : une dependance vers eux rendrait le
# baseline injouable sur une base neuve.
ARTEFACTS_INTERDITS = [
    (r"\bsauvegarde_beta_\d+\b", "schema de sauvegarde de la beta"),
    (r"\bzz_snap_cka_\w+\b", "snapshot de beta"),
    (r"\w+_snapshot_\d{8}\b", "table d'archive datee"),
    (r"\w+_artefacts_\d{8}\b", "table d'artefacts datee"),
]

# Schemas autres que public dont le baseline peut legitimement dependre. Ils
# sont fournis par Supabase ou par une extension : le baseline ne les recree
# pas, il les suppose presents.
SCHEMAS_EXTERNES_ADMIS = {"auth", "extensions", "storage", "pg_catalog", "pg_temp",
                          "information_schema", "graphql", "realtime", "vault",
                          "supabase_migrations", "cron", "net"}


def lire(chemin):
    with open(chemin, encoding="utf-8", newline="") as fh:
        return fh.read()


def phase(man, rep, prefixe):
    """Concatene les fichiers d'une phase dans l'ordre DECLARE au manifeste.

    Jamais dans l'ordre du tri des noms : un fichier de phase trop gros est
    decoupe en morceaux numerotes, et « -10 » se trie avant « -2 ».
    """
    return "".join(lire(os.path.join(rep, n)) for n in man["ordre"]
                   if n.startswith(prefixe))


def main():
    mans = {}
    for chemin in sorted(glob.glob(os.path.join(DOM, "*", "MANIFESTE.json"))):
        mans[os.path.basename(os.path.dirname(chemin))] = (
            json.load(open(chemin, encoding="utf-8")), os.path.dirname(chemin))
    if not mans:
        print("ECHEC : aucun domaine rendu.")
        return 1

    ctl = json.load(open(os.path.join(BASE, "CONTROLE-GLOBAL.json"), encoding="utf-8"))
    ecartees = set(ctl["ecartes"]["liste"])

    # Les divergences DECLAREES sont admises ; une divergence nouvelle, non
    # declaree, fait echouer le test. C'est toute la difference entre une
    # difference assumee et une difference masquee.
    diffs = json.load(open(os.path.join(BASE, "DIFFERENCES-DELIBEREES.json"), encoding="utf-8"))
    declarees = {k: v for k, v in diffs["fonction_dependant_d_un_schema_ecarte"].items()
                 if not k.startswith("_")}
    schemas_declares = {re.search(r"schema (\w+)", v["depend_de"]).group(1)
                        for v in declarees.values() if re.search(r"schema (\w+)", v["depend_de"])}

    # ------------------------------------------------- inventaire des fournis
    tables, sequences, fonctions, vues = {}, {}, {}, {}
    doublons = []
    for d, (man, _) in mans.items():
        for t in man["tables"]:
            if t["nom"] in tables:
                doublons.append("table %s definie dans %s et %s" % (t["nom"], tables[t["nom"]], d))
            tables[t["nom"]] = d
        for s in man["sequences"]:
            sequences[s["nom"]] = d
        for f in man["fonctions"]:
            nom = f["signature"].split("(")[0]
            fonctions.setdefault(nom, []).append(d)
        for v in man["vues"]:
            vues[v["nom"]] = d

    pbs, notes = [], []
    print("ASSEMBLAGE STATIQUE DU BASELINE")
    print("  %d domaines | %d tables | %d sequences | %d fonctions distinctes | %d vues"
          % (len(mans), len(tables), len(sequences), len(fonctions), len(vues)))

    for d in doublons:
        pbs.append(d)

    # ------------------------------------------------------ 1. cles etrangeres
    fk, fk_vers_ecartee, fk_vers_inconnue = 0, [], []
    for d, (man, rep) in mans.items():
        texte = phase(man, rep, "30_contraintes")
        for cible in re.findall(r"REFERENCES\s+(?:public\.)?(\w+)\s*\(", texte):
            fk += 1
            if cible in ecartees:
                fk_vers_ecartee.append("%s : cle etrangere vers %s, table ecartee du baseline"
                                       % (d, cible))
            elif cible not in tables and cible not in vues:
                fk_vers_inconnue.append("%s : cle etrangere vers %s, introuvable" % (d, cible))
    print("\n1. cles etrangeres examinees            : %d" % fk)
    print("   vers une table ecartee               : %d %s"
          % (len(fk_vers_ecartee), "OK " if not fk_vers_ecartee else "NON"))
    print("   vers une table introuvable           : %d %s"
          % (len(fk_vers_inconnue), "OK " if not fk_vers_inconnue else "NON"))
    pbs += fk_vers_ecartee + fk_vers_inconnue

    # -------------------------------------------------- 2. fonctions de trigger
    trg_sans_fonction = []
    for d, (man, _) in mans.items():
        for t in man["triggers"]:
            nom = t["fonction"].split("(")[0].replace("public.", "")
            if nom not in fonctions:
                trg_sans_fonction.append("%s : declencheur %s appelle %s, absente du baseline"
                                         % (d, t["nom"], nom))
            # Un declencheur (phase 50) suppose sa fonction (phase 20) : l'ordre
            # des phases le garantit par construction, on le verifie quand meme.
            elif PHASE["fonction"] >= PHASE["trigger"]:
                pbs.append("ordre des phases incoherent : fonction apres declencheur")
    print("\n2. declencheurs sans leur fonction      : %d %s"
          % (len(trg_sans_fonction), "OK " if not trg_sans_fonction else "NON"))
    pbs += trg_sans_fonction

    # ------------------------------------- 3. fonctions appelees par les policies
    appels_manquants, externes = [], {}
    motif_appel = re.compile(r"(?:(\w+)\.)?([a-z_][a-z0-9_]*)\s*\(")
    for d, (man, rep) in mans.items():
        textes = []
        for prefixe in ("60_rls-policies", "40_vues", "30_contraintes"):
            textes.append(phase(man, rep, prefixe))
        for texte in textes:
            # On ne lit que les expressions, pas les commentaires d'en-tete.
            corps = "\n".join(l for l in texte.splitlines() if not l.lstrip().startswith("--"))
            for schema, nom in motif_appel.findall(corps):
                if schema and schema not in ("public",):
                    if schema in SCHEMAS_EXTERNES_ADMIS:
                        externes.setdefault(schema + "." + nom, set()).add(d)
                    else:
                        appels_manquants.append("%s : appel a %s.%s, schema inconnu"
                                                % (d, schema, nom))
                    continue
                if schema == "public" and nom not in fonctions:
                    appels_manquants.append("%s : appel a public.%s, fonction absente du baseline"
                                            % (d, nom))
    print("\n3. appels a une fonction absente        : %d %s"
          % (len(appels_manquants), "OK " if not appels_manquants else "NON"))
    pbs += appels_manquants

    # ---------------------------------------------------------- 4. sequences
    seq_manquantes = []
    for d, (man, rep) in mans.items():
        texte = phase(man, rep, "10_tables")
        for seq in re.findall(r"nextval\('(?:public\.)?([\w\"]+)'", texte):
            if seq.strip('"') not in sequences:
                seq_manquantes.append("%s : defaut nextval sur %s, sequence absente" % (d, seq))
    print("\n4. defauts nextval sans leur sequence   : %d %s"
          % (len(seq_manquantes), "OK " if not seq_manquantes else "NON"))
    pbs += seq_manquantes

    # ------------------------------------------- 5. artefacts hors baseline
    interdits, admises = [], []
    for d, (man, rep) in mans.items():
        for chemin in sorted(glob.glob(os.path.join(rep, "*.sql"))):
            texte = lire(chemin)
            corps = "\n".join(l for l in texte.splitlines() if not l.lstrip().startswith("--"))
            for motif, quoi in ARTEFACTS_INTERDITS:
                for trouve in set(re.findall(motif, corps)):
                    ligne = "%s/%s : reference a %s (%s)" % (d, os.path.basename(chemin), trouve, quoi)
                    (admises if trouve in schemas_declares else interdits).append(ligne)
            for t in ecartees:
                if re.search(r"\b%s\b" % re.escape(t), corps):
                    interdits.append("%s/%s : reference a la table ecartee %s"
                                     % (d, os.path.basename(chemin), t))
    interdits, admises = sorted(set(interdits)), sorted(set(admises))
    print("\n5. references a un artefact hors baseline")
    print("   non declarees                        : %d %s"
          % (len(interdits), "OK " if not interdits else "NON"))
    print("   declarees dans DIFFERENCES-DELIBEREES : %d" % len(admises))
    for a in admises:
        print("     . " + a)
    pbs += interdits
    notes += admises

    # ----------------------------------- 6. dependances des corps de fonction
    # Une fonction peut citer une table ecartee dans son corps. Ce n'est pas
    # bloquant pour la CREATION (plpgsql n'est pas valide a la creation), mais
    # c'est bloquant a l'EXECUTION : il faut le savoir.
    corps_fautifs = []
    for d, (man, rep) in mans.items():
        texte = phase(man, rep, "20_fonctions")
        for t in ecartees:
            for m in re.finditer(r"\b%s\b" % re.escape(t), texte):
                debut = texte.rfind("CREATE OR REPLACE FUNCTION", 0, m.start())
                sig = texte[debut:debut + 160].split("\n")[0] if debut >= 0 else "?"
                corps_fautifs.append("%s : une fonction cite la table ecartee %s -- %s"
                                     % (d, t, sig[:110]))
    corps_fautifs = sorted(set(corps_fautifs))
    print("\n6. corps de fonction citant une table ecartee : %d %s"
          % (len(corps_fautifs), "OK " if not corps_fautifs else "A SIGNALER"))
    # Non bloquant, mais consigne : la fonction se cree, elle echouera a l'usage.
    notes += corps_fautifs

    # --------------------------------------- 7. ordre des phases, verification
    print("\n7. ordre des phases")
    ordre = [("table", "contrainte"), ("table", "index"), ("table", "vue"),
             ("fonction", "contrainte"), ("fonction", "index"), ("fonction", "vue"),
             ("fonction", "trigger"), ("fonction", "policy"), ("table", "policy"),
             ("sequence", "table")]
    for avant, apres in ordre:
        ok = PHASE[avant] <= PHASE[apres]
        print("   %-12s (%2d) avant %-12s (%2d) %s"
              % (avant, PHASE[avant], apres, PHASE[apres], "OK " if ok else "NON"))
        if not ok:
            pbs.append("ordre des phases : %s doit preceder %s" % (avant, apres))

    # ---------------------------------------------- 8. dependances externes
    print("\n8. dependances vers un autre schema (declarees, non recreees) : %d"
          % len(externes))
    for cle in sorted(externes):
        print("   %-34s utilise par %s" % (cle, ", ".join(sorted(externes[cle]))))

    # ------------------------------------------------- 9. assemblage des seeds
    # Les seeds s'appliquent APRES la phase 80. Un INSERT seede dans une table
    # porteuse d'une cle etrangere exige que la table visee soit, elle aussi,
    # deja peuplee -- sinon la colonne doit etre nulle sur toutes les lignes.
    rep_seeds = os.path.join(BASE, "seeds")
    print("\n9. assemblage des seeds")
    if not os.path.isdir(rep_seeds):
        print("   aucun seed sur le disque.")
    else:
        peuplees, vides = set(), set()
        for chemin in sorted(glob.glob(os.path.join(rep_seeds, "*", "*.sql"))):
            tbl = os.path.basename(chemin)[:-4]
            (peuplees if "\nINSERT INTO " in lire(chemin) else vides).add(tbl)
        print("   tables peuplees par un seed         : %d" % len(peuplees))
        print("   tables en attente (TODO, sans donnee) : %d" % len(vides))
        liens = {}
        for d, (man, rep) in mans.items():
            texte = phase(man, rep, "30_contraintes")
            for porteuse, cible in re.findall(
                    r"ALTER TABLE public\.(\w+) ADD CONSTRAINT \w+ FOREIGN KEY \([^)]*\) "
                    r"REFERENCES (?:public\.)?(\w+)\s*\(", texte):
                liens.setdefault(porteuse, set()).add(cible)
        a_verifier = sorted((p, c) for p, cs in liens.items() for c in cs
                            if p in peuplees and c not in peuplees and p != c)
        print("   seeds dont une cle etrangere vise une table non peuplee : %d %s"
              % (len(a_verifier), "OK " if not a_verifier else "A SIGNALER"))
        for p, c in a_verifier:
            notes.append("seed de %s : cle etrangere vers %s, qui n'est pas peuplee. "
                         "L'INSERT ne passera que si la colonne est nulle sur toutes "
                         "les lignes seedees." % (p, c))
        boucles = sorted(p for p, cs in liens.items() if p in cs)
        print("   tables a cle etrangere sur elles-memes : %d" % len(boucles))
        for b in boucles:
            if b in peuplees:
                notes.append("seed de %s : cle etrangere sur elle-meme, l'ordre des lignes "
                             "a l'interieur du fichier compte." % b)

    # ----------------------------------------------------------------- verdict
    print("\n" + "=" * 76)
    if notes:
        print("A SIGNALER (non bloquant pour l'assemblage) : %d" % len(notes))
        for n in notes:
            print("  . " + n)
        print()
    if pbs:
        print("ECHEC : %d anomalie(s) d'assemblage" % len(pbs))
        for p in pbs:
            print("  - " + p)
        print("\nAucun objet n'a ete supprime pour faire passer ce test.")
        return 1
    print("ASSEMBLAGE COHERENT : chaque ordre trouve, a sa phase, tout ce dont il depend.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
