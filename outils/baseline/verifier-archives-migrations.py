#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VERIFICATEUR DES ARCHIVES DE MIGRATION -- l'empreinte, pas la bonne volonte.

POURQUOI CE SCRIPT EXISTE. `historique/migrations-appliquees/` garde une copie du corps de chaque
migration appliquee. Cette copie n'a de valeur que si elle est EXACTE : une archive qui diverge du
registre Supabase est pire qu'une archive absente, parce qu'elle se lit comme une verite.

Jusqu'au 10 octobre 2026 l'empreinte etait recopiee a la main dans l'en-tete de chaque fichier, et
rien ne la verifiait. Ce script la verifie, pour tous les fichiers d'un coup :

  1. il lit l'en-tete d'archive, qui DECLARE le md5 et la longueur du corps ;
  2. il isole le corps -- tout ce qui suit la ligne de fermeture de l'en-tete ;
  3. il recalcule md5 et longueur, et refuse le moindre ecart.

L'en-tete lui-meme n'entre jamais dans l'empreinte : c'est un commentaire d'archivage, ajoute
APRES l'application, et il n'a jamais ete envoye a la base.

CE QU'IL NE PEUT PAS FAIRE SEUL : comparer au registre Supabase. Le md5 declare dans l'en-tete
vient du registre -- c'est de la que l'archiviste le recopie -- et ce script verifie que le CORPS
du fichier correspond bien a cette empreinte. Pour verifier que l'empreinte declaree est bien
celle du registre, la requete est dans le README du repertoire ; elle ne tient pas dans un script
sans identifiants de base.

Usage :
    python3 outils/baseline/verifier-archives-migrations.py
    python3 outils/baseline/verifier-archives-migrations.py 20261010      -> un prefixe de version
"""
import hashlib
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARCHIVES = os.path.join(RACINE, "historique", "migrations-appliquees")
FERMETURE = "-- =============================================================================\n"
# LE MARQUEUR DE DEBUT DU CORPS, pose par la convention du 10 octobre 2026. Il est plus fiable que
# la ligne de fermeture de l'en-tete : certaines migrations commencent elles-memes par une ligne de
# tirets, et compter les separateurs faisait deriver l'empreinte de 79 caracteres -- exactement la
# longueur de ce marqueur, ce qui est la facon la plus claire de se tromper.
MARQUEUR = "-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<\n"
RE_EMPREINTE = re.compile(
    r"^--\s*CORPS EXACT ENREGISTRE\s*:\s*md5\s+([0-9a-f]{32})\s*,\s*(\d+)\s+caracteres", re.M)
RE_VERSION = re.compile(r"^--\s*Registre Supabase\s*:\s*version\s+(\d{14})", re.M)


def verifier(chemin):
    """Rend (etat, detail). etat vaut 'ok', 'sans-entete' ou 'ecart'."""
    s = open(chemin, encoding="utf-8").read()
    m = RE_EMPREINTE.search(s)
    if not m:
        return "sans-entete", "aucune ligne « CORPS EXACT ENREGISTRE »"
    md5_declare, n_declare = m.group(1), int(m.group(2))

    # Le corps commence apres le MARQUEUR. A defaut -- archives anterieures a la convention --
    # on retombe sur la deuxieme ligne de fermeture de l'en-tete.
    k = s.find(MARQUEUR)
    if k >= 0:
        corps = s[k + len(MARQUEUR):]
    else:
        i = s.find(FERMETURE)
        j = s.find(FERMETURE, i + len(FERMETURE)) if i >= 0 else -1
        if j < 0:
            return "sans-entete", "en-tete d'archive non ferme"
        corps = s[j + len(FERMETURE):]
    corps = corps.lstrip("\n").rstrip("\n")

    h = hashlib.md5(corps.encode()).hexdigest()
    if h != md5_declare or len(corps) != n_declare:
        return "ecart", ("md5 calcule %s (declare %s), longueur %d (declaree %d)"
                         % (h, md5_declare, len(corps), n_declare))
    v = RE_VERSION.search(s)
    nom = os.path.basename(chemin)
    if v and not nom.startswith(v.group(1)):
        return "ecart", "la version declaree (%s) ne correspond pas au nom du fichier" % v.group(1)
    return "ok", "md5 %s, %d caracteres" % (h, len(corps))


def main():
    prefixe = sys.argv[1] if len(sys.argv) > 1 else ""
    fichiers = sorted(f for f in os.listdir(ARCHIVES)
                      if f.endswith(".sql") and f.startswith(prefixe))
    if not fichiers:
        print("Aucune archive ne correspond au prefixe %r." % prefixe)
        return 1
    ok = ecarts = sans = 0
    for f in fichiers:
        etat, detail = verifier(os.path.join(ARCHIVES, f))
        if etat == "ok":
            ok += 1
        elif etat == "ecart":
            ecarts += 1
            print("  ***  %-78s %s" % (f, detail))
        else:
            sans += 1
    print("")
    print("%d archive(s) verifiee(s) par empreinte, %d ecart(s), %d sans en-tete d'empreinte."
          % (ok, ecarts, sans))
    if ecarts:
        print("ECHEC : une archive diverge du corps qu'elle declare.")
        return 1
    print("LES %d ARCHIVES A EMPREINTE SONT CONFORMES." % ok)
    return 0


if __name__ == "__main__":
    sys.exit(main())
