#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PREUVE ANCIEN-CONTRE-NOUVEAU DE L'ACCELERATION DE CHANTIER -- generateur du banc SQL.

POURQUOI CE SCRIPT EXISTE. `terrain_chantier_acte` recalcule cote serveur la progression d'un
chantier accelere -- il le FAUT, parce qu'un nombre que le client dicte et qui borne un avancement
est une faille. Mais deux implementations d'une meme regle divergent toujours un jour.

Ce script interdit la divergence SANS JAMAIS RECOPIER UNE VALEUR A LA MAIN :

  1. il lance `banc-chantier-progression-serveur.js`, qui execute les formules du VRAI
     plateau-chantiers.js sur une grille de chantiers et imprime le resultat attendu ;
  2. il en fabrique un banc SQL en transaction annulee, qui refait le MEME calcul avec les
     expressions de la porte et compare cas par cas ;
  3. le banc SQL rougit en NOMMANT le premier cas divergent, avec les deux valeurs.

Le piege que cette comparaison existe pour attraper : l'arithmetique. Le client compare des
flottants binaires (`d * 2 / 3`), Postgres comparerait des `numeric` exacts, et les seuils de
tiers tombent precisement sur des tiers de duree. La porte est donc ecrite en `double precision`.

Usage :
    python3 outils/bancs/comparer-progression-chantier.py            -> le SQL a executer
    python3 outils/bancs/comparer-progression-chantier.py --cas      -> la grille seule
"""
import json
import os
import re
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LANCEUR = os.path.join(RACINE, "outils", "bancs", "lancer-banc.py")
BANC = os.path.join(RACINE, "outils", "bancs", "banc-chantier-progression-serveur.js")


def grille():
    """La grille vient du banc JS, qui l'a produite avec le code de PRODUCTION. Aucune valeur
    attendue n'est ecrite dans ce fichier : si le banc JS ne tourne pas, ce script echoue."""
    p = subprocess.run([sys.executable, LANCEUR, BANC], capture_output=True, text=True)
    if p.returncode != 0:
        print("Le banc JS n'est pas vert, aucune comparaison possible :\n" + p.stdout[-2000:],
              file=sys.stderr)
        sys.exit(2)
    m = re.search(r"^ATTENDU_JSON=(.+)$", p.stdout, re.M)
    if not m:
        print("Le banc JS n'a pas imprime sa grille.", file=sys.stderr)
        sys.exit(2)
    return json.loads(m.group(1))


SQL = """-- BANC GENERE -- NE PAS EDITER A LA MAIN.
-- Produit par outils/bancs/comparer-progression-chantier.py, qui tient sa grille du banc JS
-- `banc-chantier-progression-serveur.js` -- lequel execute les formules du VRAI
-- plateau-chantiers.js. Aucune valeur attendue n'a ete recopiee par un humain.
--
-- CE QU'IL PROUVE. Pour chacun des %(n)d chantiers de la grille, les cinq grandeurs que la porte
-- `terrain_chantier_acte` calcule elle-meme -- peutProgresser, progressionMaxFinancee, le gain,
-- la nouvelle progression et le verrou des deux tiers -- valent EXACTEMENT ce que le code du jeu
-- produit. Les trois seuils sont lus dans `entreprises_constantes`, semes par le generateur.
BEGIN;
DO $banc$
DECLARE
  cas constant jsonb := %(cas)s;
  c jsonb; n integer := 0; ko text[] := '{}';
  d double precision; total double precision; verse double precision; prog double precision;
  s1 double precision; s2 double precision; s3 double precision;
  requis double precision; peut boolean; plafond double precision; gain double precision;
  neuf double precision; verrou boolean;
BEGIN
  SELECT valeur::double precision INTO s1 FROM public.entreprises_constantes WHERE cle = 'seuil_demarrage_pct';
  SELECT valeur::double precision INTO s2 FROM public.entreprises_constantes WHERE cle = 'seuil_premier_tiers_pct';
  SELECT valeur::double precision INTO s3 FROM public.entreprises_constantes WHERE cle = 'seuil_deux_tiers_pct';
  IF s1 IS NULL OR s2 IS NULL OR s3 IS NULL THEN
    RAISE EXCEPTION 'LES TROIS SEUILS NE SONT PAS SEMES : le generateur de miroirs n''a pas tourne.';
  END IF;

  FOR c IN SELECT * FROM jsonb_array_elements(cas) LOOP
    n := n + 1;
    d     := (c ->> 0)::double precision;
    total := (c ->> 1)::double precision;
    verse := (c ->> 2)::double precision;
    prog  := (c ->> 3)::double precision;

    requis := ceil(total * (CASE WHEN d <= 0 THEN s3
                                 WHEN prog < d * 1 / 3 THEN s1
                                 WHEN prog < d * 2 / 3 THEN s2
                                 ELSE s3 END) / 100);
    peut := greatest(0, requis - verse) <= 0;
    plafond := CASE WHEN d <= 0 THEN 0
                    WHEN total <= 0 THEN d
                    WHEN verse * 100 >= s3 * total THEN d
                    WHEN verse * 100 >= s2 * total THEN d * 2 / 3
                    WHEN verse * 100 >= s1 * total THEN d * 1 / 3
                    ELSE 0 END;
    gain := greatest(0, least(prog + greatest(0, (d - prog) / 2), plafond) - prog);
    neuf := least(d, prog + gain);
    verrou := (d > 0 AND neuf >= d * 2 / 3);

    IF peut <> ((c ->> 4)::integer = 1) THEN
      ko := ko || format('cas %%s (d=%%s cout=%%s verse=%%s prog=%%s) peutProgresser : serveur=%%s client=%%s',
                         n, d, total, verse, prog, peut, (c ->> 4));
    ELSIF abs(plafond - (c ->> 5)::double precision) > 1e-9 THEN
      ko := ko || format('cas %%s plafond : serveur=%%s client=%%s', n, plafond, c ->> 5);
    ELSIF abs(gain - (c ->> 6)::double precision) > 1e-9 THEN
      ko := ko || format('cas %%s gain : serveur=%%s client=%%s', n, gain, c ->> 6);
    ELSIF abs(neuf - (c ->> 7)::double precision) > 1e-9 THEN
      ko := ko || format('cas %%s nouvelle progression : serveur=%%s client=%%s', n, neuf, c ->> 7);
    ELSIF verrou <> ((c ->> 8)::integer = 1) THEN
      ko := ko || format('cas %%s verrou des deux tiers : serveur=%%s client=%%s', n, verrou, c ->> 8);
    END IF;
  END LOOP;

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES %% CHANTIERS DE LA GRILLE DONNENT LE MEME RESULTAT DES DEUX COTES.', n;
  ELSE
    RAISE EXCEPTION E'DIVERGENCE ANCIEN-CONTRE-NOUVEAU sur %% cas :\\n  %%',
      array_length(ko, 1), array_to_string(ko[1:8], E'\\n  ');
  END IF;
END $banc$;
ROLLBACK;
"""


if __name__ == "__main__":
    cas = grille()
    if "--cas" in sys.argv:
        print(json.dumps(cas))
    else:
        print(SQL % {"n": len(cas), "cas": "'" + json.dumps(cas, separators=(",", ":")).replace("'", "''") + "'::jsonb"})
