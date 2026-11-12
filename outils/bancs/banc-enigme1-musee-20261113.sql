-- Banc : départ lisible de l'enquête du musée de Luthécia (migration 20261112234900), 13/11/2026.
-- Joue la migration DANS la transaction puis le scénario ; se termine TOUJOURS par une exception
-- portant le rapport : rien ne survit (ni fonction, ni fiche). Compte de test : Arnie.
-- Usage : coller le contenu de la migration à l'endroit marqué, puis exécuter le tout.
BEGIN;
-- >>> MIGRATION 20261112234900_enigme1_musee_serveur.sql ICI <<<
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true); END $f$;
CREATE OR REPLACE FUNCTION pg_temp.aller(p text, r text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'musee-ville-luthecia', current_room = r WHERE name = p;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.aller(text, text) TO PUBLIC;

DO $banc$
DECLARE
  U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie'; v jsonb; rap text := '';
BEGIN
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET enigme1 = '{"etape":"non_commencee","variante":null}'::jsonb,
    inventory = coalesce((SELECT jsonb_agg(o) FROM jsonb_array_elements(inventory) o WHERE o->>'id' IS DISTINCT FROM 'cle-debarras-musee'), '[]'::jsonb)
   WHERE name = A;

  -- 1. Enquête non commencée : pas d'accueil, examen refusé.
  PERFORM pg_temp.aller(A, 'hall'); PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('accueil');
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'premiere')::boolean THEN RAISE EXCEPTION 'ECHEC 1a %', v; END IF;
  PERFORM pg_temp.aller(A, 'salle_maires'); PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('examiner', 'salle_maires');
  IF v->>'raison' IS DISTINCT FROM 'enquete_inactive' THEN RAISE EXCEPTION 'ECHEC 1b %', v; END IF;
  rap := rap || '1 inactive OK ; ';

  -- 2. Enquête ouverte : accueil une seule fois.
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET enigme1 = '{"etape":"declenchee","variante":"maire"}'::jsonb WHERE name = A;
  PERFORM pg_temp.aller(A, 'hall'); PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('accueil');
  IF (v->>'premiere')::boolean IS NOT TRUE OR (v->'enigme'->>'accueilValerie')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'ECHEC 2a %', v; END IF;
  v := public.enigme1_musee('accueil');
  IF (v->>'premiere')::boolean THEN RAISE EXCEPTION 'ECHEC 2b rejouée %', v; END IF;
  rap := rap || '2 accueil unique OK ; ';

  -- 3. Lieu : accueil hors du hall et examen d'une autre salle refusés ; salle hors liste refusée.
  PERFORM pg_temp.aller(A, 'salle_maires'); PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('accueil');
  IF v->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'ECHEC 3a %', v; END IF;
  v := public.enigme1_musee('examiner', 'salle_plumes');
  IF v->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'ECHEC 3b %', v; END IF;
  v := public.enigme1_musee('examiner', 'salle_unions');
  IF v->>'raison' IS DISTINCT FROM 'commande_invalide' THEN RAISE EXCEPTION 'ECHEC 3c %', v; END IF;
  rap := rap || '3 lieux OK ; ';

  -- 4. Examen : une ligne par salle, rejouable sans doublon ; quatre salles.
  v := public.enigme1_musee('examiner', 'salle_maires');
  IF (v->>'nouveau')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'ECHEC 4a %', v; END IF;
  v := public.enigme1_musee('examiner', 'salle_maires');
  IF (v->>'nouveau')::boolean OR jsonb_array_length(v->'enigme'->'cadresVus') <> 1 THEN RAISE EXCEPTION 'ECHEC 4b %', v; END IF;
  PERFORM pg_temp.aller(A, 'salle_criminels'); PERFORM pg_temp.je_suis(U); PERFORM public.enigme1_musee('examiner', 'salle_criminels');
  PERFORM pg_temp.aller(A, 'salle_entrepreneurs'); PERFORM pg_temp.je_suis(U); PERFORM public.enigme1_musee('examiner', 'salle_entrepreneurs');
  PERFORM pg_temp.aller(A, 'salle_plumes'); PERFORM pg_temp.je_suis(U); v := public.enigme1_musee('examiner', 'salle_plumes');
  IF jsonb_array_length(v->'enigme'->'cadresVus') <> 4 OR (v->'enigme'->>'accueilValerie')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'ECHEC 4c %', v; END IF;
  rap := rap || '4 cadres OK ; ';

  -- 5. Débarras : refusé sans clé, résolu avec clé, une seule fois.
  PERFORM pg_temp.aller(A, 'debarras'); PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('debarras');
  IF v->>'raison' IS DISTINCT FROM 'porte_fermee_a_cle' THEN RAISE EXCEPTION 'ECHEC 5a %', v; END IF;
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb) || jsonb_build_array((SELECT objet FROM public.objets_modeles WHERE id = 'enigme:cle')) WHERE name = A;
  PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('debarras');
  IF (v->>'premiere')::boolean IS NOT TRUE OR v->'enigme'->>'etape' <> 'resolue' OR jsonb_array_length(v->'enigme'->'cadresVus') <> 4 THEN RAISE EXCEPTION 'ECHEC 5b %', v; END IF;
  v := public.enigme1_musee('debarras');
  IF (v->>'premiere')::boolean THEN RAISE EXCEPTION 'ECHEC 5c %', v; END IF;
  PERFORM pg_temp.aller(A, 'salle_maires'); PERFORM pg_temp.je_suis(U);
  v := public.enigme1_musee('examiner', 'salle_maires');
  IF v->>'raison' IS DISTINCT FROM 'enquete_inactive' THEN RAISE EXCEPTION 'ECHEC 5d après résolution %', v; END IF;
  rap := rap || '5 débarras OK ; ';

  -- 6. Droits : anon ne peut pas appeler.
  PERFORM pg_temp.serveur();
  IF has_function_privilege('anon', 'public.enigme1_musee(text,text)', 'EXECUTE') THEN RAISE EXCEPTION 'ECHEC 6 anon'; END IF;
  rap := rap || '6 droits OK';
  RAISE EXCEPTION 'BANC VERT (annulé) : %', rap;
END $banc$;
ROLLBACK;
