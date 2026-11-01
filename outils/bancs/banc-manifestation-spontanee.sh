#!/usr/bin/env bash
# Banc local jetable de la manifestation spontanee (migration 20261101121000).
# Monte un PostgreSQL temporaire, pose des doublures minimales du socle (fiche, paiement, trace,
# annonce, groupes #219), applique la migration et joue les scenarios. Aucune base reelle touchee.
# Usage : bash outils/bancs/banc-manifestation-spontanee.sh
set -euo pipefail
ICI="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)"
TMP="$(mktemp -d)"; trap 'su postgres -c "$BIN/pg_ctl -D $TMP/d -m immediate stop" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT
chown postgres "$TMP" 2>/dev/null || true
su postgres -c "$BIN/initdb -D $TMP/d -A trust >/dev/null && $BIN/pg_ctl -D $TMP/d -o '-k $TMP -p 55439 -c listen_addresses=' -l $TMP/log start >/dev/null"
cp "$ICI/migrations/20261101121000_manifestation_spontanee.sql" "$TMP/m.sql"; chmod 644 "$TMP/m.sql"
PSQL="psql -X -q -v ON_ERROR_STOP=1 -h $TMP -p 55439 -U postgres -d postgres"

$PSQL <<'SQL'
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text,
  current_room text, current_street text, resources jsonb DEFAULT '{}', recherche jsonb DEFAULT '[]',
  historique_crimes jsonb DEFAULT '[]', day int DEFAULT 3, pa int DEFAULT 5);
CREATE TABLE actes_illegaux (fn text PRIMARY KEY, type text, detect_rate int, peine_jours int, amende int,
  decouvrable boolean, maj_le timestamptz DEFAULT now());
CREATE TABLE ordres_couts (fn text PRIMARY KEY, pa int, cost int);
CREATE TABLE annonces (pays text, texte text);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION payer_ordre(p text, f text, pa int, c int) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN IF NOT EXISTS (SELECT 1 FROM ordres_couts WHERE fn = f AND ordres_couts.pa = payer_ordre.pa) THEN
  RETURN '{"ok":false,"raison":"cout_inconnu"}'; END IF;
  UPDATE personnages_donnees SET pa = personnages_donnees.pa - payer_ordre.pa WHERE name = p; RETURN '{"ok":true}'; END $$;
CREATE FUNCTION crime_tracer_interne(n text, a text, c text) RETURNS void LANGUAGE sql AS $$
  UPDATE personnages_donnees SET historique_crimes = historique_crimes || jsonb_build_array(jsonb_build_object('acte', a, 'cible', c, 'origine', 'serveur')) WHERE name = n $$;
CREATE FUNCTION annonce_publique_interne(p text, t text) RETURNS void LANGUAGE sql AS $$ INSERT INTO annonces VALUES (p, t) $$;
-- Doublure #219 (meme forme que 20261031115739)
CREATE TABLE groupes_pj_adhesions (membre text PRIMARY KEY, chef text NOT NULL, cree_le timestamptz DEFAULT now());
INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, resources)
  SELECT 'pj' || g, 'republic', 'ville_b', 'place-du-rail-montrouge', 'place', '{"pop":50}' FROM generate_series(1, 11) g;
INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, resources)
  VALUES ('cible', 'republic', 'capitale', 'mairie', 'hall', '{"pop":95}');
INSERT INTO groupes_pj_adhesions (membre, chef) SELECT 'pj' || g, 'pj1' FROM generate_series(2, 9) g;
SQL
$PSQL -f "$TMP/m.sql"
$PSQL -f "$TMP/m.sql"   # idempotence

$PSQL <<'SQL'
CREATE FUNCTION ok(c boolean, l text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF NOT c THEN RAISE EXCEPTION 'ECHEC : %', l; END IF; RAISE NOTICE 'ok — %', l; END $$;
SET client_min_messages = notice;
SELECT set_config('banc.moi', 'pj1', false);
-- 9 presents : refus nomme, rien de paye
SELECT ok((manif_spontanee_organiser('pour', 'cible') ->> 'raison') = 'groupe_insuffisant', '9 PJ : groupe insuffisant');
SELECT ok((SELECT pa FROM personnages_donnees WHERE name = 'pj1') = 5, 'refus : aucun PA preleve');
-- un membre ne peut pas lancer
INSERT INTO groupes_pj_adhesions (membre, chef) VALUES ('pj10', 'pj1');
SELECT set_config('banc.moi', 'pj2', false);
SELECT ok((manif_spontanee_organiser('pour', 'cible') ->> 'raison') = 'pas_chef', 'membre : pas chef');
SELECT set_config('banc.moi', 'pj1', false);
SELECT ok((manif_spontanee_organiser('peut-etre', 'cible') ->> 'raison') = 'sens_invalide', 'sens invalide');
SELECT ok((manif_spontanee_organiser('pour', 'personne') ->> 'raison') = 'cible_invalide', 'cible inconnue');
-- 10 presents : en faveur, +10 POP plafonne a 100
CREATE TEMP TABLE r AS SELECT manif_spontanee_organiser('pour', 'cible') AS v;
SELECT ok((SELECT (v ->> 'ok')::boolean FROM r), '10 PJ : manifestation lancee');
SELECT ok((SELECT pop FROM (SELECT (resources ->> 'pop')::numeric pop FROM personnages_donnees WHERE name = 'cible') x) = 100, 'POP cible 95 + 10 plafonnee a 100');
SELECT ok((SELECT jsonb_array_length(v -> 'manif' -> 'participants') FROM r) = 10, '10 participants (pj11 hors groupe exclu)');
SELECT ok((SELECT count(*) FROM personnages_donnees WHERE recherche @> '[{"acte":"manifestation_spontanee"}]') = 10, '10 hors-la-loi');
SELECT ok((SELECT recherche = '[]' FROM personnages_donnees WHERE name = 'pj11'), 'pj11 non recherche');
SELECT ok((SELECT count(*) FROM personnages_donnees WHERE historique_crimes @> '[{"acte":"manifestation_spontanee"}]') = 10, '10 traces pour les rumeurs');
SELECT ok((SELECT pa FROM personnages_donnees WHERE name = 'pj1') = 4, '1 PA preleve au chef');
SELECT ok((SELECT count(*) FROM annonces) = 1, 'annonce publique');
-- une par jour et par ville
SELECT ok((manif_spontanee_organiser('contre', 'cible') ->> 'raison') = 'deja_aujourdhui', 'deuxieme du jour refusee');
-- lecture : participe
SELECT ok((manif_spontanee_lire() ->> 'participe')::boolean, 'lecture : participe');
-- un membre quitte : la manif continue
DELETE FROM groupes_pj_adhesions WHERE membre = 'pj10';
SELECT ok((SELECT fin_reelle IS NULL FROM manifestations_spontanees), 'depart d''un membre : manif continue');
-- le chef quitte son groupe (groupe_pj_quitter supprime ses adhesions) : fin immediate
DELETE FROM groupes_pj_adhesions WHERE chef = 'pj1';
SELECT ok((SELECT motif_fin = 'chef_parti' FROM manifestations_spontanees), 'chef parti : fin immediate');
SELECT ok((SELECT count(*) FROM personnages_donnees WHERE recherche @> '[{"acte":"manifestation_spontanee"}]') = 0, 'fin : plus aucun hors-la-loi');
SELECT ok((SELECT count(*) FROM personnages_donnees WHERE historique_crimes @> '[{"acte":"manifestation_spontanee"}]') = 10, 'fin : traces conservees');
SELECT ok((SELECT (resources ->> 'pop')::numeric FROM personnages_donnees WHERE name = 'cible') = 100, 'fin : POP acquise conservee');
-- autre motif de recherche preserve, duree ecoulee, sens hostile
DELETE FROM manifestations_spontanees;
INSERT INTO groupes_pj_adhesions (membre, chef) SELECT 'pj' || g, 'pj1' FROM generate_series(2, 10) g;
SELECT set_config('rp.recherche_interne', 'on', false);
UPDATE personnages_donnees SET recherche = '[{"acte":"vol","type":"delit_mineur"}]' WHERE name = 'pj3';
SELECT set_config('rp.recherche_interne', '', false);
SELECT ok((manif_spontanee_organiser('contre', 'cible') ->> 'ok')::boolean, 'hostile lancee');
SELECT ok((SELECT (resources ->> 'pop')::numeric FROM personnages_donnees WHERE name = 'cible') = 90, 'hostile : -10 POP');
UPDATE manifestations_spontanees SET fin_max = now() - interval '1 second';
SELECT ok((manif_spontanee_lire() ->> 'participe')::boolean IS FALSE, 'apres 1 h : lecture clot');
SELECT ok((SELECT motif_fin = 'duree_ecoulee' FROM manifestations_spontanees), 'motif duree ecoulee');
SELECT ok((SELECT recherche = '[{"acte":"vol","type":"delit_mineur"}]' FROM personnages_donnees WHERE name = 'pj3'), 'autre motif de recherche preserve');
SELECT ok((SELECT peine_jours = 1 AND amende = 500 FROM actes_illegaux WHERE fn = 'manifestation_spontanee'), 'peine 1 jour 500 FR');
-- hors place
UPDATE personnages_donnees SET current_building = 'gare' WHERE name = 'pj1';
DELETE FROM manifestations_spontanees;
SELECT ok((manif_spontanee_organiser('pour', 'cible') ->> 'raison') = 'hors_place', 'hors place refuse');
SQL
echo "BANC MANIFESTATION SPONTANEE : TOUT PASSE"
