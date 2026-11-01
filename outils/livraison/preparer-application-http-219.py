#!/usr/bin/env python3
"""Rend le bloc SQL d'application atomique du lot #219 en production (sans le contenu des migrations).

Pourquoi : les 97 migrations (≈ 500 Ko) ne peuvent pas transiter par le canal MCP. Le bloc rendu
fait lire chaque fichier par la base elle-même (extension `http`, le temps de l'opération), au SHA
Git épinglé du dépôt public, vérifie son SHA-256 contre le manifeste versionné, l'exécute et
l'inscrit au registre `supabase_migrations.schema_migrations` sous `<sujet>_<version du fichier>`.
Tout se passe dans UNE transaction : une seule erreur (garde d'empreinte, SHA, registre déjà
présent) annule l'ensemble. `--essai` termine par une exception : rien n'est conservé.

Usage :
  python3 outils/livraison/preparer-application-http-219.py --sha <commit> [--essai] > /tmp/bloc.sql
Aucune connexion ; le bloc est hors Git (règle des trois maisons).
"""
import argparse, hashlib, json, re, sys
from pathlib import Path

R = Path(__file__).resolve().parents[2]
PLAN = R / 'outils/audits/PLAN-97-EDITOR-219-20261101.json'
# Après le lot : dépendances validées dont la règle est décidée, dans l'ordre.
SUITE = ['migrations/20261101121000_manifestation_spontanee.sql',
         'migrations/20261101220000_referentiels_images_webp_sentinelle_ressources.sql']


def entrees():
    plan = json.loads(PLAN.read_text())
    es = [(m['fichier'], m['sha256']) for m in plan['migrations']]
    if len(es) != 97:
        raise SystemExit('plan 97 attendu')
    for f in SUITE:
        es.append((f, hashlib.sha256((R / f).read_bytes()).hexdigest()))
    for f, sha in es:
        if hashlib.sha256((R / f).read_bytes()).hexdigest() != sha:
            raise SystemExit('source modifiée sans révision du manifeste : ' + f)
    return es


def main():
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument('--sha', required=True)
    a.add_argument('--essai', action='store_true')
    o = a.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', o.sha):
        raise SystemExit('SHA Git complet requis')
    es = entrees()
    suite = ",\n".join("(%d,'%s','%s')" % (97 + i, f, sha) for i, (f, sha) in enumerate(es[97:], 1))
    fin = ("RAISE EXCEPTION 'ESSAI_ANNULE : % migrations exécutées sans erreur, rien conservé', n;"
           if o.essai else "RAISE NOTICE 'LOT_219_APPLIQUE : % migrations', n;")
    print("""SET statement_timeout = '15min';
SET lock_timeout = '20s';
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;
DO $lot219$
DECLARE r record; reponse record; texte text; plan jsonb; n integer := 0;
 depot text := 'https://raw.githubusercontent.com/FredJ74/res-publica/%s/';
 base timestamp := date_trunc('second', clock_timestamp() AT TIME ZONE 'UTC');
BEGIN
 -- Verrou pris d'emblée : un ALTER TABLE tardif sur la fiche après des écritures du lot a provoqué
 -- un interblocage avec une sauvegarde de joueur lors du premier essai (01/11).
 LOCK TABLE public.personnages_donnees IN ACCESS EXCLUSIVE MODE;
 SELECT * INTO reponse FROM extensions.http_get(depot || 'outils/audits/PLAN-97-EDITOR-219-20261101.json');
 IF reponse.status <> 200 THEN RAISE EXCEPTION 'plan_illisible : %%', reponse.status; END IF;
 plan := reponse.content::jsonb;
 IF jsonb_array_length(plan->'migrations') <> 97 THEN RAISE EXCEPTION 'plan_97_attendu'; END IF;
 FOR r IN
  SELECT rang::int, fichier, sha, substr(s, 16) || '_' || substr(s, 1, 14) AS nom FROM (
   SELECT o AS rang, e->>'fichier' AS fichier, e->>'sha256' AS sha FROM jsonb_array_elements(plan->'migrations') WITH ORDINALITY x(e, o)
   UNION ALL SELECT * FROM (VALUES
%s) v(rang, fichier, sha)) t, LATERAL (SELECT regexp_replace(fichier, '^migrations/(.*)[.]sql$', '\\1') AS s) u
  ORDER BY rang
 LOOP
  IF EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE name = r.nom) THEN
   RAISE EXCEPTION 'deja_au_registre : %%', r.nom;
  END IF;
  SELECT * INTO reponse FROM extensions.http_get(depot || r.fichier);
  IF reponse.status <> 200 THEN RAISE EXCEPTION 'lecture_impossible %% : %%', r.fichier, reponse.status; END IF;
  texte := reponse.content;
  IF encode(extensions.digest(convert_to(texte, 'UTF8'), 'sha256'), 'hex') <> r.sha THEN
   RAISE EXCEPTION 'sha_different : %%', r.fichier;
  END IF;
  -- Enveloppes BEGIN;/COMMIT; propres à cinq fichiers : la transaction englobante les remplace.
  texte := regexp_replace(texte, '^\\s*(BEGIN|COMMIT)\\s*;\\s*$', '', 'gn');
  EXECUTE texte;
  INSERT INTO supabase_migrations.schema_migrations(version, name)
   VALUES (to_char(base + make_interval(secs => r.rang), 'YYYYMMDDHH24MISS'), r.nom);
  n := n + 1;
 END LOOP;
 IF n <> 99 THEN RAISE EXCEPTION 'compte_inattendu : %%', n; END IF;
 %s
END $lot219$;""" % (o.sha, suite, fin))


if __name__ == '__main__':
    main()
