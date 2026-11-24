#!/usr/bin/env python3
"""Listes du soir : décisions de Fred décidées, mises en ligne et encore en attente.

Lit docs/suivi-decisions.md (toutes les tables à six colonnes Date | Décision | État | En ligne le | Commit | Source)
et imprime trois sections pour une date donnée (JJ/MM/AAAA, aujourd'hui par défaut) :
  1. décidé ce jour      (colonne Date = la date) ;
  2. en ligne ce jour    (colonne En ligne le = la date) ;
  3. encore en attente   (état différent de « en ligne », toutes dates).

Usage : python3 outils/suivi/listes-du-soir.py [JJ/MM/AAAA] [--fichier chemin]
Python 3 standard, sans dépendance.
"""
import datetime
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FICHIER_DEFAUT = os.path.join(RACINE, "docs", "suivi-decisions.md")
DATE_RE = re.compile(r"^\d{2}/\d{2}/\d{4}$")


def lire_lignes(chemin):
    """Renvoie la liste des décisions (dictionnaires) de toutes les tables du fichier."""
    lignes = []
    with open(chemin, encoding="utf-8") as f:
        for brute in f:
            brute = brute.strip()
            if not brute.startswith("|"):
                continue
            cellules = [c.strip() for c in brute.strip("|").split("|")]
            if len(cellules) != 6:
                continue
            if cellules[0] == "Date" or set(cellules[0]) <= set("-: "):
                continue
            date, decision, etat, en_ligne_le, commit, source = cellules
            lignes.append({
                "date": date, "decision": decision, "etat": etat,
                "en_ligne_le": en_ligne_le, "commit": commit, "source": source,
            })
    return lignes


def tri_date(texte):
    try:
        return datetime.datetime.strptime(texte, "%d/%m/%Y")
    except ValueError:
        return datetime.datetime.max


def imprimer(titre, lignes, avec_etat=False):
    print(f"## {titre} ({len(lignes)})")
    if not lignes:
        print("- (aucune)")
    for l in lignes:
        suffixe = f" [{l['etat']}]" if avec_etat else ""
        commit = f" — {l['commit']}" if l["commit"] else ""
        print(f"- {l['date']} : {l['decision']}{suffixe}{commit} ({l['source']})")
    print()


def main(argv):
    chemin = FICHIER_DEFAUT
    date = datetime.date.today().strftime("%d/%m/%Y")
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--fichier" and args:
            chemin = args.pop(0)
        elif DATE_RE.match(a):
            date = a
        else:
            print(f"Argument non reconnu : {a} (attendu : JJ/MM/AAAA ou --fichier chemin)", file=sys.stderr)
            return 2
    if not os.path.exists(chemin):
        print(f"Fichier introuvable : {chemin}", file=sys.stderr)
        return 1

    lignes = lire_lignes(chemin)
    decide = [l for l in lignes if l["date"] == date]
    en_ligne = [l for l in lignes if l["en_ligne_le"] == date]
    attente = sorted((l for l in lignes if l["etat"] != "en ligne"), key=lambda l: tri_date(l["date"]))

    print(f"# Listes du soir — {date}")
    print()
    imprimer("Décidé aujourd'hui", decide, avec_etat=True)
    imprimer("En ligne aujourd'hui", en_ligne)
    imprimer("Encore en attente", attente, avec_etat=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
