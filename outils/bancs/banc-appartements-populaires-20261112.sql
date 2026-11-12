-- Banc : appartements populaires (migration 20261112221500), 12/11/2026.
-- Se termine TOUJOURS par une exception portant le rapport : rien ne survit.
-- Comptes de test : Arnie (titulaire) et Jean Jaaj (colocataire), personnages d'essai des agents.
-- Appartement témoin : Novomirsk, logements-novomirsk / grand_appartement_1 (aucun bail réel au 12/11).
BEGIN;
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
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale', current_building = 'logements-novomirsk',
         current_room = r, current_street = NULL, pa = 10, pa_repos_le = NULL, bonus_pa_differe = 0
   WHERE name = p;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.aller(text, text) TO PUBLIC;

DO $banc$
DECLARE
  UA text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie';
  UJ text := 'f27c8b19-ce18-4158-8d4d-dd791aec5d9a'; J text := 'Jean Jaaj';
  B text := 'grand_appartement_1'; BID text := 'soviet:logements-novomirsk:grand_appartement_1:capitale';
  v jsonb; g0 integer; rap text := '';
BEGIN
  PERFORM pg_temp.serveur();
  DELETE FROM public.logements_colocations WHERE colocataire IN (A, J);
  INSERT INTO public.locations_actives (id, country, data) VALUES (BID, 'soviet', jsonb_build_object(
    'country', 'soviet', 'city', 'capitale', 'buildingId', 'logements-novomirsk', 'roomId', B, 'localLabel', 'Grand appartement n°1',
    'prix', 20, 'locataire', A, 'logementSocial', true, 'typeLogement', 'grand', 'bonusMoralSommeil', 5, 'bonusSanteSommeil', 7));

  -- 0. Gain de référence hors appartement (hall).
  PERFORM pg_temp.aller(A, 'salle'); PERFORM pg_temp.je_suis(UA);
  v := public.pa_repos_nocturne(A);
  IF v->'logement' <> 'null'::jsonb THEN RAISE EXCEPTION 'ECHEC 0 bonus dans le hall : %', v; END IF;
  g0 := (v->>'gain')::integer;

  -- 1. Gratuit : +1 PA dans la pièce unique, moral/santé du logement.
  PERFORM pg_temp.aller(A, B); PERFORM pg_temp.je_suis(UA);
  v := public.pa_repos_nocturne(A);
  IF (v->>'gain')::integer <> g0 + 1 OR (v->'logement'->>'moral')::int <> 5 OR (v->'logement'->>'sante')::int <> 7 THEN
    RAISE EXCEPTION 'ECHEC 1 sommeil gratuit : % (ref %)', v, g0; END IF;
  rap := rap || '1 +1 PA gratuit OK ; ';

  -- 2. Emplacements gratuits : 5 pour un grand, 3 pour un petit.
  PERFORM pg_temp.serveur();
  IF public.equipements_emplacements_interne('soviet', 'capitale', 'logements-novomirsk', B) <> 5
     OR public.equipements_emplacements_interne('soviet', 'capitale', 'logements-novomirsk', 'petit_appartement_1') <> 3 THEN
    RAISE EXCEPTION 'ECHEC 2 emplacements gratuits'; END IF;
  rap := rap || '2 emplacements 5/3 OK ; ';

  -- 3. Colocation : refus sans grand appartement, puis désignation (2 PA), jouissance du colocataire.
  PERFORM pg_temp.aller(A, B); PERFORM pg_temp.je_suis(UA);
  v := public.logement_coloc_designer(A);
  IF v->>'raison' IS DISTINCT FROM 'pas_soi_meme' THEN RAISE EXCEPTION 'ECHEC 3a soi-meme : %', v; END IF;
  v := public.logement_coloc_designer(J);
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'ECHEC 3b designer : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF (SELECT pa FROM public.personnages_donnees WHERE name = A) <> 8 THEN RAISE EXCEPTION 'ECHEC 3c 2 PA non debites'; END IF;
  IF NOT public.local_jouissance_interne(J, 'soviet', 'capitale', 'logements-novomirsk', B) THEN RAISE EXCEPTION 'ECHEC 3d jouissance coloc'; END IF;
  PERFORM pg_temp.je_suis(UA);
  v := public.logement_coloc_designer(J);
  IF v->>'raison' IS DISTINCT FROM 'deja_un_colocataire' THEN RAISE EXCEPTION 'ECHEC 3e second coloc : %', v; END IF;
  -- le colocataire dort aussi avec le bonus
  PERFORM pg_temp.aller(J, B); PERFORM pg_temp.je_suis(UJ);
  v := public.pa_repos_nocturne(J);
  IF v->'logement' = 'null'::jsonb OR v->'logement'->>'role' <> 'colocataire' THEN RAISE EXCEPTION 'ECHEC 3f sommeil coloc : %', v; END IF;
  rap := rap || '3 colocation OK ; ';

  -- 4. Premium : chambres, emplacements 3/6, navigation, sommeil au salon sans bonus.
  PERFORM pg_temp.aller(A, B); PERFORM pg_temp.je_suis(UA);
  v := public.logement_premium_activer();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR (v->>'chambres')::int <> 2 THEN RAISE EXCEPTION 'ECHEC 4a premium : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF public.equipements_emplacements_interne('soviet', 'capitale', 'logements-novomirsk', B) <> 3
     OR public.equipements_emplacements_interne('soviet', 'capitale', 'logements-novomirsk', B || '_chambre_1') <> 6
     OR NOT public.navigation_piece_referencee_interne('soviet', 'capitale', 'logements-novomirsk', B || '_chambre_2')
     OR public.navigation_piece_referencee_interne('soviet', 'capitale', 'logements-novomirsk', B || '_chambre_3')
     OR public.navigation_piece_referencee_interne('soviet', 'capitale', 'logements-novomirsk', 'petit_appartement_1_chambre_1') THEN
    RAISE EXCEPTION 'ECHEC 4b chambres/emplacements'; END IF;
  PERFORM pg_temp.aller(A, B); PERFORM pg_temp.je_suis(UA);
  v := public.pa_repos_nocturne(A);
  IF v->'logement' <> 'null'::jsonb THEN RAISE EXCEPTION 'ECHEC 4c bonus au salon : %', v; END IF;
  PERFORM pg_temp.aller(A, B || '_chambre_1'); PERFORM pg_temp.je_suis(UA);
  v := public.pa_repos_nocturne(A);
  IF (v->>'gain')::integer <> g0 + 1 THEN RAISE EXCEPTION 'ECHEC 4d bonus en chambre : %', v; END IF;
  rap := rap || '4 premium OK ; ';

  -- 5. Jouissance par chambre et droits de décor.
  PERFORM pg_temp.serveur();
  IF NOT public.local_jouissance_interne(J, 'soviet', 'capitale', 'logements-novomirsk', B || '_chambre_2')
     OR public.local_jouissance_interne(J, 'soviet', 'capitale', 'logements-novomirsk', B || '_chambre_1')
     OR public.local_jouissance_interne(A, 'soviet', 'capitale', 'logements-novomirsk', B || '_chambre_2')
     OR NOT public.local_jouissance_interne(A, 'soviet', 'capitale', 'logements-novomirsk', B || '_chambre_1')
     OR NOT public.logement_decor_droit_interne(A, 'soviet', 'capitale', 'logements-novomirsk', B)
     OR public.logement_decor_droit_interne(A, 'soviet', 'capitale', 'logements-novomirsk', B || '_chambre_2')
     OR NOT public.logement_decor_droit_interne(J, 'soviet', 'capitale', 'logements-novomirsk', B || '_chambre_2')
     OR public.logement_decor_droit_interne(J, 'soviet', 'capitale', 'logements-novomirsk', B) THEN
    RAISE EXCEPTION 'ECHEC 5 jouissance/decors par chambre'; END IF;
  rap := rap || '5 chambres et decors OK ; ';

  -- 6. Etat de la fenêtre « Mon logement ».
  PERFORM pg_temp.aller(J, B || '_chambre_2'); PERFORM pg_temp.je_suis(UJ);
  v := public.logement_etat();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR v->>'role' <> 'colocataire' OR jsonb_array_length(v->'pieces') <> 3 THEN
    RAISE EXCEPTION 'ECHEC 6 etat : %', v; END IF;
  rap := rap || '6 etat OK ; ';

  -- 7. Départ du titulaire : offre de reprise, attribution bloquée, reprise acceptée.
  PERFORM pg_temp.serveur();
  DELETE FROM public.locations_actives WHERE id = BID;
  IF NOT EXISTS (SELECT 1 FROM public.logements_reprises WHERE bail_id = BID AND colocataire = J AND statut = 'en_attente')
     OR EXISTS (SELECT 1 FROM public.logements_colocations WHERE bail_id = BID) THEN RAISE EXCEPTION 'ECHEC 7a reprise non offerte'; END IF;
  IF NOT public.local_jouissance_interne(J, 'soviet', 'capitale', 'logements-novomirsk', B) THEN RAISE EXCEPTION 'ECHEC 7b jouissance pendant offre'; END IF;
  PERFORM pg_temp.je_suis(UJ);
  v := public.logement_reprendre_bail(true);
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'ECHEC 7c reprise : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF (SELECT data->>'locataire' FROM public.locations_actives WHERE id = BID) IS DISTINCT FROM J
     OR NOT EXISTS (SELECT 1 FROM public.logements_premium WHERE piece = B AND ville = 'capitale' AND batiment = 'logements-novomirsk')
     OR public.local_jouissance_interne(A, 'soviet', 'capitale', 'logements-novomirsk', B) THEN RAISE EXCEPTION 'ECHEC 7d bail repris'; END IF;
  -- l'ancien titulaire n'est plus rien : son matériel reviendrait au nouveau titulaire
  IF public.logement_abandon_beneficiaire_interne('soviet', 'capitale', 'logements-novomirsk', B, A) IS DISTINCT FROM 'pj:' || J THEN
    RAISE EXCEPTION 'ECHEC 7e beneficiaire materiel'; END IF;
  rap := rap || '7 reprise OK ; ';

  -- 8. Le colocataire part de lui-même (gratuit).
  PERFORM pg_temp.aller(J, B); PERFORM pg_temp.je_suis(UJ);
  PERFORM pg_temp.serveur();
  INSERT INTO public.logements_colocations (bail_id, pays, ville, batiment, piece, titulaire, colocataire)
  VALUES (BID, 'soviet', 'capitale', 'logements-novomirsk', B, J, A);
  PERFORM pg_temp.aller(A, 'salle'); PERFORM pg_temp.je_suis(UA);
  v := public.logement_coloc_partir();
  PERFORM pg_temp.serveur();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR EXISTS (SELECT 1 FROM public.logements_colocations WHERE bail_id = BID) THEN
    RAISE EXCEPTION 'ECHEC 8 depart coloc : %', v; END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = A) <> 10 THEN RAISE EXCEPTION 'ECHEC 8b depart non gratuit'; END IF;
  rap := rap || '8 depart gratuit OK ; ';

  RAISE EXCEPTION 'BANC VERT (annule) : %', rap;
END $banc$;
ROLLBACK;
