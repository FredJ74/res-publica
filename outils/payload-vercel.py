#!/usr/bin/env python3
"""Ce qui part reellement chez Vercel, et ce que ca pese.

POURQUOI CET OUTIL EXISTE. Le poids d'un depot n'est pas le poids d'un deploiement. Vercel, sur
un projet connecte a Git, envoie les fichiers SUIVIS PAR GIT moins ceux qu'exclut `.vercelignore`
-- donc ni les fichiers non suivis, ni `.git/`, ni ce que le fichier d'exclusion ecarte. Mesurer
`du -sh .` donne donc un chiffre faux dans les deux sens, et c'est ce qui avait masque pendant
des mois 104 Mo d'outillage embarque a chaque deploiement.

CE QU'IL NE FAIT PAS. Il ne contacte pas Vercel, ne lit aucun jeton, n'appelle aucune API. Il
reproduit la REGLE d'inclusion a partir du depot local : `git ls-files` plus l'interpretation de
`.vercelignore`. C'est une simulation, et elle est annoncee comme telle -- le chiffre exact d'un
deploiement reste celui que Vercel affiche.

    python3 outils/payload-vercel.py                 rapport lisible
    python3 outils/payload-vercel.py --json          le meme, en JSON
    python3 outils/payload-vercel.py --garde         controle de non-regression (code de sortie)

LE MODE --garde est le garde-fou du chantier infrastructure : il compare le payload au plafond
declare dans outils/payload-vercel.json et rend un code de sortie non nul s'il est depasse, ou
si un fichier neuf depasse le seuil unitaire. Il est fait pour tourner en local et en CI.
"""

import hashlib
import json
import os
import subprocess
import sys
from collections import defaultdict

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEUILS = os.path.join(RACINE, "outils", "payload-vercel.json")


# ---------------------------------------------------------------------------
# L'INTERPRETATION DE .vercelignore
#
# Vercel documente la meme syntaxe que .gitignore. On n'en implemente que ce que le fichier
# utilise reellement, et on REFUSE de deviner le reste : une forme non geree fait echouer l'outil
# plutot que de produire un chiffre faux. Un simulateur qui ignore en silence une regle qu'il ne
# comprend pas est pire qu'absent -- il rassure.
# ---------------------------------------------------------------------------
def charger_exclusions(chemin):
    motifs = []
    if not os.path.exists(chemin):
        return motifs
    with open(chemin, encoding="utf-8") as fh:
        for brut in fh:
            ligne = brut.strip()
            if not ligne or ligne.startswith("#"):
                continue
            if ligne.startswith("!"):
                raise SystemExit("payload-vercel : la negation « %s » n'est pas geree par ce "
                                 "simulateur. Ajoute-la ici avant de l'utiliser dans "
                                 ".vercelignore." % ligne)
            if ligne.endswith("/"):
                motifs.append(("repertoire", ligne.rstrip("/").lstrip("/")))
            elif ligne.startswith("**/"):
                motifs.append(("nom", ligne[3:]))
            elif "/" in ligne.strip("/"):
                motifs.append(("chemin", ligne.strip("/")))
            elif "*" in ligne or "?" in ligne or "[" in ligne:
                motifs.append(("glob", ligne))
            else:
                # Un motif sans separateur vise le NOM, a n'importe quelle profondeur.
                motifs.append(("nom", ligne))
    return motifs


def exclu(chemin, motifs):
    nom = os.path.basename(chemin)
    morceaux = chemin.split("/")
    for genre, motif in motifs:
        if genre == "repertoire":
            tete = motif.split("/")
            if morceaux[:len(tete)] == tete:
                return motif
        elif genre == "nom":
            if nom == motif:
                return motif
        elif genre == "chemin":
            if chemin == motif or chemin.startswith(motif + "/"):
                return motif
        elif genre == "glob":
            import fnmatch
            if fnmatch.fnmatch(nom, motif):
                return motif
    return None


# ---------------------------------------------------------------------------
# LA MESURE
# ---------------------------------------------------------------------------
def fichiers_suivis():
    sortie = subprocess.run(["git", "-C", RACINE, "ls-files", "-z"],
                            capture_output=True, text=True, check=True).stdout
    return [f for f in sortie.split("\0") if f]


def mesurer():
    motifs = charger_exclusions(os.path.join(RACINE, ".vercelignore"))
    inclus, ecartes = [], defaultdict(lambda: [0, 0])
    for rel in fichiers_suivis():
        plein = os.path.join(RACINE, rel)
        if not os.path.isfile(plein):
            continue                      # lien casse ou fichier retire du disque
        taille = os.path.getsize(plein)
        motif = exclu(rel, motifs)
        if motif:
            ecartes[motif][0] += taille
            ecartes[motif][1] += 1
        else:
            inclus.append((rel, taille))
    return inclus, dict(ecartes), motifs


def fmt(n):
    for unite in ("o", "Ko", "Mo", "Go"):
        if abs(n) < 1024 or unite == "Go":
            return "%.1f %s" % (n, unite) if unite != "o" else "%d o" % n
        n /= 1024.0


def empreinte(plein):
    h = hashlib.md5()
    with open(plein, "rb") as fh:
        for bloc in iter(lambda: fh.read(1 << 20), b""):
            h.update(bloc)
    return h.hexdigest()


def rapport(inclus, ecartes, cherche_doublons=True):
    total = sum(t for _, t in inclus)
    par_dossier, par_ext = defaultdict(lambda: [0, 0]), defaultdict(lambda: [0, 0])
    for rel, taille in inclus:
        racine = rel.split("/")[0] if "/" in rel else "(racine)"
        par_dossier[racine][0] += taille
        par_dossier[racine][1] += 1
        ext = os.path.splitext(rel)[1].lower() or "(sans extension)"
        par_ext[ext][0] += taille
        par_ext[ext][1] += 1

    doublons = {}
    if cherche_doublons:
        # On ne hache QUE les fichiers de meme taille : deux fichiers de tailles differentes ne
        # peuvent pas etre identiques, et hacher 2 400 fichiers pour rien coute cher.
        par_taille = defaultdict(list)
        for rel, taille in inclus:
            par_taille[taille].append(rel)
        for taille, rels in par_taille.items():
            if len(rels) < 2 or taille == 0:
                continue
            par_h = defaultdict(list)
            for rel in rels:
                par_h[empreinte(os.path.join(RACINE, rel))].append(rel)
            for h, groupe in par_h.items():
                if len(groupe) > 1:
                    doublons[h] = {"taille": taille, "chemins": sorted(groupe),
                                   "gaspille": taille * (len(groupe) - 1)}
    return {
        "payload_octets": total,
        "payload_lisible": fmt(total),
        "fichiers": len(inclus),
        "par_dossier": {k: {"octets": v[0], "lisible": fmt(v[0]), "fichiers": v[1]}
                        for k, v in sorted(par_dossier.items(), key=lambda x: -x[1][0])},
        "par_extension": {k: {"octets": v[0], "lisible": fmt(v[0]), "fichiers": v[1]}
                          for k, v in sorted(par_ext.items(), key=lambda x: -x[1][0])},
        "top_fichiers": [{"chemin": r, "octets": t, "lisible": fmt(t)}
                         for r, t in sorted(inclus, key=lambda x: -x[1])[:50]],
        "ecartes_par_motif": {k: {"octets": v[0], "lisible": fmt(v[0]), "fichiers": v[1]}
                              for k, v in sorted(ecartes.items(), key=lambda x: -x[1][0])},
        "doublons_exacts": sorted(doublons.values(), key=lambda d: -d["gaspille"]),
    }


def imprimer(r):
    print("PAYLOAD VERCEL SIMULE -- fichiers suivis par git, moins .vercelignore")
    print("=" * 74)
    print("  %s en %d fichiers" % (r["payload_lisible"], r["fichiers"]))
    ec = sum(v["octets"] for v in r["ecartes_par_motif"].values())
    print("  ecarte par .vercelignore : %s en %d fichiers"
          % (fmt(ec), sum(v["fichiers"] for v in r["ecartes_par_motif"].values())))
    print("\n  PAR DOSSIER DE PREMIER NIVEAU")
    print("  " + "-" * 70)
    for k, v in list(r["par_dossier"].items())[:15]:
        print("    %-22s %12s  %5d fichiers" % (k, v["lisible"], v["fichiers"]))
    print("\n  PAR EXTENSION")
    print("  " + "-" * 70)
    for k, v in list(r["par_extension"].items())[:15]:
        print("    %-22s %12s  %5d fichiers" % (k, v["lisible"], v["fichiers"]))
    print("\n  LES DIX FICHIERS LES PLUS LOURDS")
    print("  " + "-" * 70)
    for f in r["top_fichiers"][:10]:
        print("    %10s  %s" % (f["lisible"], f["chemin"]))
    if r["doublons_exacts"]:
        gaspille = sum(d["gaspille"] for d in r["doublons_exacts"])
        print("\n  DOUBLONS BINAIRES EXACTS : %d groupes, %s gaspilles"
              % (len(r["doublons_exacts"]), fmt(gaspille)))
        print("  " + "-" * 70)
        for d in r["doublons_exacts"][:10]:
            print("    %10s x%d  %s" % (fmt(d["taille"]), len(d["chemins"]), d["chemins"][0]))
            for c in d["chemins"][1:]:
                print("    %10s      = %s" % ("", c))
    else:
        print("\n  DOUBLONS BINAIRES EXACTS : aucun")
    print("\n  ECARTE PAR MOTIF")
    print("  " + "-" * 70)
    for k, v in r["ecartes_par_motif"].items():
        print("    %-22s %12s  %5d fichiers" % (k, v["lisible"], v["fichiers"]))


def garde(r):
    """Non-regression du payload. Rend 0 si tout tient, 1 sinon."""
    if not os.path.exists(SEUILS):
        raise SystemExit("payload-vercel --garde : %s est absent. Le plafond doit etre DECLARE, "
                         "pas deduit de la mesure du jour -- sinon le controle valide toujours "
                         "l'etat present." % SEUILS)
    s = json.load(open(SEUILS, encoding="utf-8"))
    pbs = []
    plafond = s["plafond_payload_octets"]
    if r["payload_octets"] > plafond:
        pbs.append("payload %s > plafond declare %s (+%s)"
                   % (r["payload_lisible"], fmt(plafond), fmt(r["payload_octets"] - plafond)))
    seuil_fichier = s["seuil_fichier_octets"]
    connus = set(s.get("gros_fichiers_connus", []))
    for f in r["top_fichiers"]:
        if f["octets"] > seuil_fichier and f["chemin"] not in connus:
            pbs.append("fichier neuf de %s non declare : %s" % (f["lisible"], f["chemin"]))
    gaspille = sum(d["gaspille"] for d in r["doublons_exacts"])
    if gaspille > s["plafond_doublons_octets"]:
        pbs.append("doublons binaires : %s gaspilles, plafond %s"
                   % (fmt(gaspille), fmt(s["plafond_doublons_octets"])))

    print("GARDE DU PAYLOAD VERCEL")
    print("=" * 74)
    print("  mesure  : %s en %d fichiers" % (r["payload_lisible"], r["fichiers"]))
    print("  plafond : %s" % fmt(plafond))
    print("  marge   : %s" % fmt(plafond - r["payload_octets"]))
    if not pbs:
        print("\n  OK -- le payload tient sous son plafond declare.")
        return 0
    print("\n  ECHEC : %d anomalie(s)" % len(pbs))
    for p in pbs:
        print("    - " + p)
    print("\n  Si l'augmentation est VOULUE, releve le plafond dans")
    print("  outils/payload-vercel.json en disant pourquoi dans sa cle `_pourquoi`.")
    print("  Ne le releve jamais « pour faire passer le controle ».")
    return 1


def main():
    args = sys.argv[1:]
    inclus, ecartes, _ = mesurer()
    r = rapport(inclus, ecartes)
    if "--json" in args:
        print(json.dumps(r, ensure_ascii=False, indent=1))
        return 0
    if "--garde" in args:
        return garde(r)
    imprimer(r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
