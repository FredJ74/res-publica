-- Banc : relecture de Fred du 13/11/2026 (migration 20261113193000).
-- Se termine TOUJOURS par une exception portant le rapport : rien ne survit.
-- Comptes de test : Arnie (titulaire) et Jean Jaaj (colocataire), personnages d'essai des agents.
-- Appartement témoin : Novomirsk, logements-novomirsk / grand_appartement_1 (comme le banc du 12/11).
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '/rpc/banc', true); END $f$;
CREATE OR REPLACE FUNCTION pg_temp.aller(p text, b text, r text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale', current_building = b,
         current_room = r, current_street = NULL, pa = 10 WHERE name = p;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.aller(text, text, text) TO PUBLIC;

DO $banc$
DECLARE
  UA text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie';
  UJ text := 'f27c8b19-ce18-4158-8d4d-dd791aec5d9a'; J text := 'Jean Jaaj';
  IMM text := 'logements-novomirsk'; B text := 'grand_appartement_1'; BID text := 'soviet:logements-novomirsk:grand_appartement_1:capitale';
  DYN text := 'terrain-banc-relecture'; DB text := 'logement_1'; DBID text := 'soviet:terrain-banc-relecture:logement_1:capitale';
  s_salon uuid := gen_random_uuid(); s_ch2 uuid := gen_random_uuid();
  v jsonb; rap text := '';
BEGIN
  PERFORM pg_temp.serveur();
  DELETE FROM public.logements_colocations WHERE colocataire IN (A, J);
  DELETE FROM public.logements_premium WHERE ville = 'capitale' AND batiment IN (IMM, DYN) AND piece IN (B, DB);
  DELETE FROM public.logements_premium_demandes WHERE bail_id IN (BID, DBID);
  INSERT INTO public.locations_actives (id, country, data) VALUES (BID, 'soviet', jsonb_build_object(
    'country', 'soviet', 'city', 'capitale', 'buildingId', IMM, 'roomId', B, 'localLabel', 'Grand appartement n°1',
    'prix', 20, 'locataire', A, 'logementSocial', true, 'typeLogement', 'grand', 'bonusMoralSommeil', 5, 'bonusSanteSommeil', 7))
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  INSERT INTO public.logements_colocations (bail_id, pays, ville, batiment, piece, titulaire, colocataire)
  VALUES (BID, 'soviet', 'capitale', IMM, B, A, J);

  -- 1. Le colocataire demande l'option ; le titulaire ne peut pas « demander » ; une seule demande à la fois.
  PERFORM pg_temp.aller(A, IMM, B); PERFORM pg_temp.je_suis(UA);
  v := public.logement_premium_demander();
  IF v->>'raison' IS DISTINCT FROM 'reserve_colocataire' THEN RAISE EXCEPTION 'ECHEC 1a titulaire demande : %', v; END IF;
  PERFORM pg_temp.aller(J, IMM, B); PERFORM pg_temp.je_suis(UJ);
  v := public.logement_premium_demander();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR v->>'titulaire' <> A THEN RAISE EXCEPTION 'ECHEC 1b demande : %', v; END IF;
  v := public.logement_premium_demander();
  IF v->>'raison' IS DISTINCT FROM 'demande_en_cours' THEN RAISE EXCEPTION 'ECHEC 1c double demande : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player = A AND subject = 'Option premium demandée'
                  AND body LIKE '%[[act:premium_oui|' || BID || ']]%' AND body LIKE '%[[act:premium_non|' || BID || ']]%') THEN
    RAISE EXCEPTION 'ECHEC 1d courrier a boutons absent'; END IF;
  rap := rap || '1 demande OK ; ';

  -- 2. La fenêtre « Mon logement » montre la demande au titulaire.
  PERFORM pg_temp.aller(A, IMM, B); PERFORM pg_temp.je_suis(UA);
  v := public.logement_etat();
  IF v->'premium_demande'->>'colocataire' IS DISTINCT FROM J THEN RAISE EXCEPTION 'ECHEC 2 etat : %', v; END IF;
  rap := rap || '2 etat OK ; ';

  -- 3. Seul le titulaire répond ; un refus ne pose pas l'option et prévient le colocataire.
  PERFORM pg_temp.je_suis(UJ);
  v := public.logement_premium_demande_repondre(BID, true);
  IF v->>'raison' IS DISTINCT FROM 'reserve_titulaire' THEN RAISE EXCEPTION 'ECHEC 3a coloc repond : %', v; END IF;
  PERFORM pg_temp.aller(A, IMM, 'salle'); PERFORM pg_temp.je_suis(UA);
  v := public.logement_premium_demande_repondre(BID, false);
  PERFORM pg_temp.serveur();
  IF (v->>'accepte')::boolean IS DISTINCT FROM false
     OR EXISTS (SELECT 1 FROM public.logements_premium WHERE ville = 'capitale' AND batiment = IMM AND piece = B)
     OR NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player = J AND subject = 'Option premium refusée') THEN
    RAISE EXCEPTION 'ECHEC 3b refus : %', v; END IF;
  rap := rap || '3 refus OK ; ';

  -- 4. Nouvelle demande, acceptée depuis le hall (où qu'il soit) : option active, 2 chambres.
  PERFORM pg_temp.aller(J, IMM, B); PERFORM pg_temp.je_suis(UJ);
  v := public.logement_premium_demander();
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'ECHEC 4a redemande : %', v; END IF;
  PERFORM pg_temp.aller(A, IMM, 'salle'); PERFORM pg_temp.je_suis(UA);
  v := public.logement_premium_demande_repondre(BID, true);
  PERFORM pg_temp.serveur();
  IF (v->>'accepte')::boolean IS DISTINCT FROM true
     OR (SELECT chambres FROM public.logements_premium WHERE ville = 'capitale' AND batiment = IMM AND piece = B) IS DISTINCT FROM 2::smallint THEN
    RAISE EXCEPTION 'ECHEC 4b acceptation : %', v; END IF;
  PERFORM pg_temp.je_suis(UA);
  v := public.logement_premium_demande_repondre(BID, true);
  IF v->>'raison' IS DISTINCT FROM 'aucune_demande' THEN RAISE EXCEPTION 'ECHEC 4c rejeu : %', v; END IF;
  rap := rap || '4 acceptation OK ; ';

  -- 5. Deux niveaux de serrure : entrée de l'appartement (clé des deux occupants) + chambre 2 (clé du colocataire seul).
  PERFORM pg_temp.serveur();
  INSERT INTO public.serrures (id, statut, fermee, cible, pays, ville, batiment, piece, bail_ref, bail_titulaire, poseur, posee_le, achetee_par)
  VALUES (s_salon, 'posee', true, 'lieu', 'soviet', 'capitale', IMM, B, BID, A, A, now(), A),
         (s_ch2, 'posee', true, 'lieu', 'soviet', 'capitale', IMM, B || '_chambre_2', BID, A, J, now(), J);
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb)
         || jsonb_build_array(jsonb_build_object('type', 'cle_serrure', 'serrureId', s_salon::text, 'name', 'Clé (banc)'))
   WHERE name = A;
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb)
         || jsonb_build_array(jsonb_build_object('type', 'cle_serrure', 'serrureId', s_salon::text, 'name', 'Clé (banc)'),
                              jsonb_build_object('type', 'cle_serrure', 'serrureId', s_ch2::text, 'name', 'Clé (banc)'))
   WHERE name = J;
  IF public.serrure_porte_fermee_interne(A, 'soviet', 'capitale', IMM, B)
     OR public.serrure_porte_fermee_interne(J, 'soviet', 'capitale', IMM, B)
     OR NOT public.serrure_porte_fermee_interne('Personne (banc)', 'soviet', 'capitale', IMM, B)
     OR NOT public.serrure_porte_fermee_interne(A, 'soviet', 'capitale', IMM, B || '_chambre_2')
     OR public.serrure_porte_fermee_interne(J, 'soviet', 'capitale', IMM, B || '_chambre_2')
     OR public.serrure_porte_fermee_interne(J, 'soviet', 'capitale', IMM, B || '_chambre_1') THEN
    RAISE EXCEPTION 'ECHEC 5 deux serrures'; END IF;
  IF (SELECT count(*) FROM public.serrures WHERE id IN (s_salon, s_ch2) AND statut = 'posee') <> 2 THEN
    RAISE EXCEPTION 'ECHEC 5b serrure tombee a tort'; END IF;
  rap := rap || '5 deux serrures OK ; ';

  -- 6. Logement construit en cours de partie (immeuble de mairie de Sovarka) : option et chambre.
  PERFORM pg_temp.serveur();
  INSERT INTO public.locations_actives (id, country, data) VALUES (DBID, 'soviet', jsonb_build_object(
    'country', 'soviet', 'city', 'capitale', 'buildingId', DYN, 'roomId', DB, 'localLabel', 'Logement n°1',
    'prix', 10, 'locataire', A, 'logementSocial', true, 'type', 'petit', 'bonusMoralSommeil', 3, 'bonusSanteSommeil', 4))
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  IF public.navigation_piece_referencee_interne('soviet', 'capitale', DYN, DB || '_chambre_1') THEN
    RAISE EXCEPTION 'ECHEC 6a chambre sans option'; END IF;
  PERFORM pg_temp.aller(A, DYN, DB); PERFORM pg_temp.je_suis(UA);
  v := public.logement_premium_activer();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR (v->>'chambres')::int <> 1 THEN RAISE EXCEPTION 'ECHEC 6b activation : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF NOT public.navigation_piece_referencee_interne('soviet', 'capitale', DYN, DB || '_chambre_1')
     OR public.navigation_piece_referencee_interne('soviet', 'capitale', DYN, DB || '_chambre_2')
     OR (SELECT chambres FROM public.logements_premium WHERE ville = 'capitale' AND batiment = DYN AND piece = DB) IS DISTINCT FROM 1::smallint
     OR public.equipements_emplacements_interne('soviet', 'capitale', DYN, DB || '_chambre_1') <> 6 THEN
    RAISE EXCEPTION 'ECHEC 6c chambre dynamique'; END IF;
  rap := rap || '6 logement dynamique OK ; ';

  -- 7. Repas chez l'habitant : +1 PA.
  IF (SELECT montant FROM public.pa_bonus_differes WHERE source = 'repas_habitant') <> 1 THEN RAISE EXCEPTION 'ECHEC 7 repas'; END IF;
  rap := rap || '7 repas +1 OK ; ';

  -- 8. Lecture du « trinquer » pour l'IA : une seule fois, alcool nommé.
  INSERT INTO public.sovarka_maisons_actes (acteur, requete, resultat, cree_le) VALUES
    (A, 'banc-trinquer', jsonb_build_object('ok', true, 'action', 'trinquer', 'habitant', 'Dolgor Tsybikova', 'alcool', 'vodka', 'reaction', 'x'), now());
  PERFORM pg_temp.je_suis(UA);
  v := public.sovarka_maison_trinquer_lire('banc-trinquer');
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR v->>'alcool' <> 'vodka' OR v->>'habitant' <> 'Dolgor Tsybikova' THEN
    RAISE EXCEPTION 'ECHEC 8a lecture : %', v; END IF;
  v := public.sovarka_maison_trinquer_lire('banc-trinquer');
  IF v->>'raison' IS DISTINCT FROM 'deja_demandee' THEN RAISE EXCEPTION 'ECHEC 8b second appel : %', v; END IF;
  PERFORM pg_temp.je_suis(UJ);
  v := public.sovarka_maison_trinquer_lire('banc-trinquer');
  IF v->>'raison' IS DISTINCT FROM 'acte_introuvable' THEN RAISE EXCEPTION 'ECHEC 8c acte d autrui : %', v; END IF;
  rap := rap || '8 trinquer IA OK ; ';

  RAISE EXCEPTION 'BANC VERT (annule) : %', rap;
END $banc$;
ROLLBACK;

-- 9. Vol d'archives (à jouer séparément, annulé aussi) : joué le 13/11 au Poste de Vigilance Glaciale
--    (Starovka, malus 5) : espion DIS 100 / VOL 16 / DUP 16 → taux 73 (= 78 − 5) ; moyen 50/8/8 → 40 (= 45 − 5).
BEGIN;
DO $b$
DECLARE J text := 'Jean Jaaj'; UJ text := 'f27c8b19-ce18-4158-8d4d-dd791aec5d9a'; v jsonb; w jsonb; m int;
BEGIN
  UPDATE public.personnages_donnees SET country='soviet', current_city='ville_a', current_building='poste-vigilance-glaciale',
    current_room=NULL, current_street=NULL, pa=10,
    resources = coalesce(resources,'{}'::jsonb) || '{"dis":100}'::jsonb, stats = coalesce(stats,'{}'::jsonb) || '{"VOL":16,"DUP":16}'::jsonb
   WHERE name = J;
  m := least(33, public.crime_malus_isn_interne('soviet','ville_a') + public.securite_malus_lieu_interne(J));
  PERFORM set_config('request.jwt.claims', json_build_object('sub', UJ, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
  v := public.sovarka_ecoute_archives_voler('banc-archives-1');
  PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true);
  UPDATE public.personnages_donnees SET pa = 10, resources = resources || '{"dis":50}'::jsonb, stats = stats || '{"VOL":8,"DUP":8}'::jsonb WHERE name = J;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', UJ, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  w := public.sovarka_ecoute_archives_voler('banc-archives-2');
  IF (v->>'taux')::int <> 78 - m OR (w->>'taux')::int <> greatest(5, 45 - m) THEN
    RAISE EXCEPTION 'ECHEC 9 formule : opti % (attendu %), moyen % (attendu %)', v->>'taux', 78 - m, w->>'taux', greatest(5, 45 - m); END IF;
  RAISE EXCEPTION 'BANC 9 VERT (annule) : malus %, opti %, moyen %', m, v->>'taux', w->>'taux';
END $b$;
ROLLBACK;
