#!/usr/bin/env bash
# Banc local jetable du loyer murs/fonds (#66, migration 20261101233000).
# Monte un PostgreSQL temporaire, pose des doublures minimales (fiche, comptes, entreprises,
# organisations, recette municipale, courrier) et le VRAI mouvement_titulaire du baseline,
# applique la migration deux fois (idempotence) et joue les scenarios. Aucune base reelle touchee.
# Usage : bash outils/bancs/banc-loyer-murs-fonds.sh
set -euo pipefail
ICI="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)"
TMP="$(mktemp -d)"; trap 'su postgres -c "$BIN/pg_ctl -D $TMP/d -m immediate stop" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT
chown postgres "$TMP" 2>/dev/null || true
su postgres -c "$BIN/initdb -D $TMP/d -A trust >/dev/null && $BIN/pg_ctl -D $TMP/d -o '-k $TMP -p 55441 -c listen_addresses=' -l $TMP/log start >/dev/null"
cp "$ICI/migrations/20261101233000_loyer_murs_fonds.sql" "$TMP/m.sql"
awk '/CREATE OR REPLACE FUNCTION public.mouvement_titulaire\(/,/\$function\$;/' "$ICI/baseline/domaines/socle/20_fonctions.sql" > "$TMP/mt.sql"
chmod 644 "$TMP"/*.sql
PSQL="psql -X -q -v ON_ERROR_STOP=1 -h $TMP -p 55441 -U postgres -d postgres"

$PSQL <<'SQL'
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text DEFAULT 'republic', arg numeric DEFAULT 0,
  liquide numeric DEFAULT 0, updated_at timestamptz);
CREATE TABLE comptes_bancaires (id serial PRIMARY KEY, personnage text, banque text, solde numeric, updated_at timestamptz);
CREATE TABLE organisations (id text PRIMARY KEY, data text);
CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE immobilier_baremes (country text PRIMARY KEY, prix_m2 integer NOT NULL);
INSERT INTO immobilier_baremes VALUES ('republic', 150);
CREATE TABLE murs_titres (id text PRIMARY KEY, country text, ville text, building_id text, type_fonds text,
  room_id text, libelle text, surface integer, proprietaire text NOT NULL DEFAULT 'commune', offre jsonb, updated_at timestamptz);
CREATE TABLE recettes (pays text, ville text, montant numeric, motif text);
CREATE TABLE mails (exp text, dest text, sujet text, corps text);
CREATE FUNCTION recette_municipale(p text, v text, m numeric, motif text) RETURNS jsonb LANGUAGE sql AS
  $$ INSERT INTO recettes VALUES (p, v, m, motif); SELECT '{"ok":true}'::jsonb $$;
CREATE FUNCTION mail_systeme_poser_interne(e text, d text, s text, c text) RETURNS void LANGUAGE sql AS
  $$ INSERT INTO mails VALUES (e, d, s, c) $$;
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION immobilier_titre_etat_interne(p_titre text, p_obs text) RETURNS jsonb LANGUAGE sql AS
  $$ SELECT jsonb_build_object('id', p_titre) $$;

INSERT INTO murs_titres (id, country, ville, building_id, type_fonds, libelle, surface, proprietaire) VALUES
  ('cafe-a',   'republic', 'ville_b', 'cafe-gare', 'cafe', 'Café A', 550, 'commune'),      -- PJ exploitant, murs commune
  ('cafe-b',   'republic', 'ville_b', 'cafe-b', 'cafe', 'Café B', 550, 'Bailleur'),        -- PJ exploitant, murs PJ
  ('cafe-pnj', 'republic', 'ville_b', 'cafe-c', 'cafe', 'Café PNJ', 550, 'commune'),       -- fonds PNJ
  ('cafe-moi', 'republic', 'ville_b', 'cafe-d', 'cafe', 'Café Moi', 550, 'Proprio'),       -- même titulaire
  ('imp-orga', 'republic', 'capitale', 'tribune', 'imprimerie', 'Imprimerie', 700, 'commune'), -- fonds d'organisation
  ('cafe-sans','republic', 'ville_b', 'cafe-e', 'cafe', 'Café sans ligne', 550, 'commune');    -- aucune ligne entreprise
INSERT INTO entreprises VALUES
  ('cafe-a',   '{"proprietaire":"Expl","caisse":300}'),
  ('cafe-b',   '{"proprietaire":"pj:Expl2","caisse":1000}'),
  ('cafe-pnj', '{"proprietaire":"PNJ","caisse":5000}'),
  ('cafe-moi', '{"proprietaire":"Proprio","caisse":5000}'),
  ('imp-orga', '{"proprietaire":"orga:o1","caisse":0}');
INSERT INTO personnages_donnees (name, arg, liquide) VALUES
  ('Expl', 400, 100), ('Expl2', 0, 0), ('Bailleur', 0, 0), ('Proprio', 0, 0), ('Pauvre', 0, 0), ('Tiers', 0, 0);
INSERT INTO comptes_bancaires (personnage, banque, solde) VALUES ('Expl', 'nationale', 300);
INSERT INTO organisations VALUES ('o1', '{"chef":"Chef","caisse":1000}');
SQL
$PSQL -f "$TMP/mt.sql"
$PSQL -f "$TMP/m.sql"
$PSQL -f "$TMP/m.sql"   # idempotence

$PSQL <<'SQL'
CREATE FUNCTION ok(c boolean, l text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF NOT coalesce(c, false) THEN RAISE EXCEPTION 'ECHEC : %', l; END IF; RAISE NOTICE 'ok — %', l; END $$;
CREATE FUNCTION jour_suivant() RETURNS void LANGUAGE sql AS $$ UPDATE murs_loyers SET jour_paiement = '2000-01-01' $$;
SET client_min_messages = notice;

-- Nuit 1
CREATE TEMP TABLE b AS SELECT murs_loyers_nuit() AS v;
SELECT ok((SELECT (v->>'ok')::boolean AND jsonb_array_length(v->'erreurs') = 0 FROM b), 'passe de nuit sans erreur');
-- Café A : caisse 300 puis 250 sur l'exploitant (liquide 100 puis compte 150), commune +550
SELECT ok((SELECT (data->>'caisse')::numeric FROM entreprises WHERE id = 'cafe-a') = 0, 'A : caisse du commerce vidée d''abord');
SELECT ok((SELECT liquide FROM personnages_donnees WHERE name = 'Expl') = 0, 'A : complément pris sur le liquide');
SELECT ok((SELECT solde FROM comptes_bancaires WHERE personnage = 'Expl') = 150, 'A : puis sur le compte national');
SELECT ok((SELECT arg FROM personnages_donnees WHERE name = 'Expl') = 150, 'A : arg diminue de la seule part personnelle');
SELECT ok((SELECT sum(montant) FROM recettes WHERE ville = 'ville_b' AND motif = 'loyer') = 550, 'A : 550 FR à la commune');
-- Café B : caisse seule, PJ bailleur crédité
SELECT ok((SELECT (data->>'caisse')::numeric FROM entreprises WHERE id = 'cafe-b') = 450, 'B : 550 pris sur la caisse');
SELECT ok((SELECT liquide = 550 AND arg = 550 FROM personnages_donnees WHERE name = 'Bailleur'), 'B : bailleur PJ crédité en liquide');
-- Sans loyer
SELECT ok((SELECT (data->>'caisse')::numeric FROM entreprises WHERE id = 'cafe-pnj') = 5000, 'PNJ : aucun loyer');
SELECT ok((SELECT (data->>'caisse')::numeric FROM entreprises WHERE id = 'cafe-moi') = 5000, 'même titulaire : aucun loyer');
SELECT ok((SELECT (v->'verdicts'->>'ignore_fonds_pnj')::int FROM b) = 2, 'fonds PNJ et sans ligne : ignorés');
-- Organisation sans caisse de commerce : caisse de l'organisation
SELECT ok((SELECT (data::jsonb->>'caisse')::numeric FROM organisations WHERE id = 'o1') = 300, 'orga : 700 sur la caisse de l''organisation');
SELECT ok((SELECT sum(montant) FROM recettes WHERE ville = 'capitale') = 700, 'orga : 700 à la commune');

-- Rejeu de la même nuit : aucun effet
CREATE TEMP TABLE b2 AS SELECT murs_loyers_nuit() AS v;
SELECT ok((SELECT (v->'verdicts'->>'deja_preleve')::int FROM b2) = 6, 'rejeu : tout déjà prélevé');
SELECT ok((SELECT sum(montant) FROM recettes) = 1250, 'rejeu : aucune recette en plus');

-- Nuit 2 : Café A, Expl ne peut payer que 150 → avertissement, rien ne bouge
SELECT jour_suivant();
SELECT ok(murs_loyer_prelever('cafe-a') = 'avertissement', 'A nuit 2 : avertissement');
SELECT ok((SELECT solde FROM comptes_bancaires WHERE personnage = 'Expl') = 150, 'avertissement : aucun débit');
SELECT ok((SELECT count(*) FROM mails WHERE dest = 'Expl' AND sujet LIKE 'Loyer impayé%') = 1, 'avertissement : courrier à l''exploitant');
-- Nuit 3 : ardoise ouverte, avis aux deux parties (commune : pas d'avis)
SELECT jour_suivant();
SELECT ok(murs_loyer_prelever('cafe-a') = 'impaye_ouvert', 'A nuit 3 : impayé inscrit');
SELECT ok((SELECT (impaye->>'montantDu')::int = 550 FROM murs_loyers WHERE titre_id = 'cafe-a'), 'ardoise : 550');
-- Nuit 4 : ardoise grossit, sans nouvel avis
SELECT jour_suivant();
SELECT ok(murs_loyer_prelever('cafe-a') = 'impaye_deja_avise', 'A nuit 4 : ardoise déjà avisée');
SELECT ok((SELECT (impaye->>'montantDu')::int = 1100 AND (impaye->>'jours')::int = 2 FROM murs_loyers WHERE titre_id = 'cafe-a'), 'ardoise : 1100 sur 2 nuits');
SELECT ok((SELECT count(*) FROM mails WHERE dest = 'Expl') = 2, 'un seul avis d''ouverture');

-- Café B, bailleur PJ : impayé signalé au bailleur
UPDATE entreprises SET data = data || '{"caisse":0}' WHERE id = 'cafe-b';
SELECT ok(murs_loyer_prelever('cafe-b') = 'avertissement', 'B : avertissement');
SELECT jour_suivant();
SELECT ok(murs_loyer_prelever('cafe-b') = 'impaye_ouvert', 'B : impayé inscrit');
SELECT ok((SELECT count(*) FROM mails WHERE dest = 'Bailleur') = 1, 'B : bailleur PJ informé');

-- Le bail survit à la vente des murs : le nouveau propriétaire touche le loyer
UPDATE murs_titres SET proprietaire = 'Tiers' WHERE id = 'cafe-b';
UPDATE entreprises SET data = data || '{"caisse":550}' WHERE id = 'cafe-b';
SELECT jour_suivant();
SELECT ok(murs_loyer_prelever('cafe-b') = 'paye', 'B : payé après la vente des murs');
SELECT ok((SELECT liquide FROM personnages_donnees WHERE name = 'Tiers') = 550, 'B : le nouveau propriétaire encaisse');
SELECT ok((SELECT impaye IS NOT NULL AND NOT avertissement FROM murs_loyers WHERE titre_id = 'cafe-b'), 'B : ardoise conservée, avertissement levé');

-- Nouvel exploitant : n'hérite pas de l'ardoise, elle est archivée
UPDATE entreprises SET data = '{"proprietaire":"Pauvre","caisse":0}' WHERE id = 'cafe-a';
SELECT jour_suivant();
SELECT ok(murs_loyer_prelever('cafe-a') = 'avertissement', 'nouvel exploitant : repart d''un avertissement');
SELECT ok((SELECT impaye IS NULL AND jsonb_array_length(ardoises_closes) = 1 FROM murs_loyers WHERE titre_id = 'cafe-a'), 'ardoise précédente archivée');

-- Catalogue : ardoise visible des seules parties
SELECT set_config('banc.moi', 'Expl2', false);
SELECT ok((SELECT (x->'loyer'->'impaye'->>'montantDu')::int = 550 AND (x->'loyer'->>'montantJour')::int = 550
  FROM jsonb_array_elements(immobilier_catalogue()->'titres') x WHERE x->>'id' = 'cafe-b'), 'catalogue : exploitant voit son ardoise');
SELECT set_config('banc.moi', 'Proprio', false);
SELECT ok((SELECT x->'loyer'->'impaye' = 'null'::jsonb
  FROM jsonb_array_elements(immobilier_catalogue()->'titres') x WHERE x->>'id' = 'cafe-b'), 'catalogue : un tiers ne voit pas l''ardoise');
SELECT ok((SELECT x->'loyer'->>'motif' = 'meme_titulaire' AND NOT (x->'loyer'->>'applique')::boolean
  FROM jsonb_array_elements(immobilier_catalogue()->'titres') x WHERE x->>'id' = 'cafe-moi'), 'catalogue : même titulaire non perçu');

-- Droits
SELECT ok(NOT has_function_privilege('authenticated', 'murs_loyers_nuit()', 'EXECUTE'), 'client : passe de nuit interdite');
SELECT ok(NOT has_function_privilege('authenticated', 'murs_loyer_prelever(text)', 'EXECUTE'), 'client : prélèvement interdit');
SELECT ok(has_function_privilege('service_role', 'murs_loyers_nuit()', 'EXECUTE'), 'serveur : passe de nuit permise');
SELECT ok(NOT has_table_privilege('authenticated', 'murs_loyers', 'SELECT'), 'client : table non lisible');
SQL
echo "BANC LOYER MURS/FONDS : TOUT VERT"
