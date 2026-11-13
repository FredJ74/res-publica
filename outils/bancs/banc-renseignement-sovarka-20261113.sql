-- Banc : renseignement de Sovarka (migrations 20261113230000 à 20261113230300).
-- Se termine TOUJOURS par une exception portant le rapport : rien ne survit.
-- Comptes d'essai des agents : Arnie (ministre de la Sécurité du Peuple simulé) et Jean Jaaj
-- (habilité, puis voleur, puis ministre de la Défense simulé).
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true); END $f$;
CREATE OR REPLACE FUNCTION pg_temp.aller(p text, b text, r text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale', current_building = b,
         current_room = r, current_street = NULL, pa = 10, est_emprisonne = NULL WHERE name = p;
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.poste(p text, pp text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.serveur();
  DELETE FROM public.postes_attribues WHERE country = 'soviet' AND (poste_id = pp OR titulaire = p);
  INSERT INTO public.postes_attribues (id, country, poste_id, titulaire, source, updated_at)
  VALUES ('banc-' || pp, 'soviet', pp, p, 'nomination', now());
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id', pp) WHERE name = p;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.aller(text, text, text), pg_temp.poste(text, text) TO PUBLIC;

DO $banc$
DECLARE
  UA text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie';
  UJ text := 'f27c8b19-ce18-4158-8d4d-dd791aec5d9a'; J text := 'Jean Jaaj';
  v jsonb; rap text := ''; n integer;
BEGIN
  PERFORM pg_temp.serveur();
  DELETE FROM public.sovarka_habilitations_ecoute;
  INSERT INTO public.sovarka_ecoutes_rapports (centre, jour, mails, examines)
  VALUES ('novomirsk', public.sovarka_jour_paris() - 1, jsonb_build_array(
    jsonb_build_object('heure', '10:00', 'de', 'Zorg Banc', 'a', 'Pim Banc', 'sujet', 'Rendez-vous', 'texte', 'Ce soir au port.'),
    jsonb_build_object('heure', '11:00', 'de', 'Pim Banc', 'a', 'Autre', 'sujet', 'x', 'texte', 'y')), 2)
  ON CONFLICT (centre, jour) DO UPDATE SET mails = EXCLUDED.mails;
  UPDATE public.caisses_batiments SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{solde}', '10000')
   WHERE id = 'soviet_gouvernement-min_int';
  PERFORM pg_temp.poste(A, 'min_int');

  -- 1. Habilitations : ministre de la Sécurité du Peuple, dans son bureau.
  PERFORM pg_temp.aller(A, 'palais-gouvernement', 'bureau_min_int'); PERFORM pg_temp.je_suis(UA);
  v := public.sovarka_habilitation_accorder(A);
  IF v->>'raison' IS DISTINCT FROM 'pas_soi_meme' THEN RAISE EXCEPTION '1a soi-même : %', v; END IF;
  v := public.sovarka_habilitation_accorder(J);
  IF (v->>'ok')::boolean IS NOT TRUE OR jsonb_array_length(v->'habilites') <> 1 THEN RAISE EXCEPTION '1b accorder : %', v; END IF;
  PERFORM pg_temp.aller(A, 'palais-gouvernement', 'hall'); PERFORM pg_temp.je_suis(UA);
  v := public.sovarka_habilitations_lire();
  IF v->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION '1c lieu : %', v; END IF;
  rap := rap || '1 habilitations OK; ';

  -- 2. Consultation sur place, par nom, 1 PA, rejeu sans double paiement.
  PERFORM pg_temp.aller(J, 'siege-renseignement', 'accueil_renseignement'); PERFORM pg_temp.je_suis(UJ);
  v := public.sovarka_ecoute_archives_consulter('Zorg Banc', 'banc-0');
  IF v->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION '2a hall : %', v; END IF;
  PERFORM pg_temp.aller(J, 'siege-renseignement', 'salle_ecoutes'); PERFORM pg_temp.je_suis(UJ);
  v := public.sovarka_ecoute_archives_consulter('zorg banc', 'banc-1');
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'nb')::int <> 1 THEN RAISE EXCEPTION '2b consulter : %', v; END IF;
  v := public.sovarka_ecoute_archives_consulter('zorg banc', 'banc-1');
  PERFORM pg_temp.serveur();
  SELECT pa INTO n FROM public.personnages_donnees WHERE name = J;
  IF n <> 9 OR (v->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION '2c rejeu : pa=% %', n, v; END IF;
  rap := rap || '2 consultation OK; ';

  -- 3. Retrait.
  PERFORM pg_temp.aller(A, 'palais-gouvernement', 'bureau_min_int'); PERFORM pg_temp.je_suis(UA);
  v := public.sovarka_habilitation_retirer(J);
  PERFORM pg_temp.aller(J, 'siege-renseignement', 'salle_ecoutes'); PERFORM pg_temp.je_suis(UJ);
  v := public.sovarka_ecoute_archives_consulter('Zorg Banc', 'banc-2');
  IF v->>'raison' IS DISTINCT FROM 'pas_habilite' THEN RAISE EXCEPTION '3 retrait : %', v; END IF;
  rap := rap || '3 retrait OK; ';

  -- 4. Équipe de la Sécurité du Peuple : 4 agents à elle, 250 PSK, une opération à la fois.
  PERFORM pg_temp.aller(A, 'palais-gouvernement', 'bureau_min_int'); PERFORM pg_temp.je_suis(UA);
  v := public.renseignement_agents_disponibles();
  IF NOT (v->'agents' @> '[{"vrai_nom":"Arkadi Moltchanov"}]') OR jsonb_array_length(v->'agents') <> 4 THEN RAISE EXCEPTION '4a agents : %', v; END IF;
  v := public.cellule_renseignement_creer('republic');
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'cout')::numeric <> 250 THEN RAISE EXCEPTION '4b créer : %', v; END IF;
  v := public.cellule_renseignement_creer('republic');
  IF v->>'raison' IS DISTINCT FROM 'equipe_deja_en_mission' THEN RAISE EXCEPTION '4c deuxième : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF NOT EXISTS (SELECT 1 FROM public.agents_renseignement WHERE equipe = 'soviet-min_int' AND pnj_id = 'agent-soviet-min_int-coordinateur') THEN
    RAISE EXCEPTION '4d raccordement PNJ'; END IF;
  rap := rap || '4 équipe et prix OK; ';

  -- 5. Le voleur pris à Novomirsk part en salle d'interrogatoire ; un seul interrogatoire.
  PERFORM pg_temp.aller(J, 'siege-renseignement', 'salle_ecoutes');
  UPDATE public.personnages_donnees SET poste = NULL, recherche = '[]'::jsonb WHERE name = J;
  PERFORM public.arrestation_flagrant_interne(J, 'voler_archives_ecoute', false, 'vol_archives_ecoute', 'banc', 1); -- durée posée par le vol (1 jour)
  PERFORM public.renseignement_interrogatoire_placer_interne(J);
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = J AND current_room = 'salle_interrogatoire_renseignement'
                   AND est_emprisonne ? 'interrogatoire' AND (est_emprisonne->>'jours')::int = 1) THEN RAISE EXCEPTION '5a placement'; END IF;
  PERFORM pg_temp.aller(A, 'siege-renseignement', 'salle_interrogatoire_renseignement'); PERFORM pg_temp.je_suis(UA);
  v := public.renseignement_detenus_interrogatoire();
  IF NOT (v->'detenus' @> jsonb_build_array(jsonb_build_object('nom', J))) THEN RAISE EXCEPTION '5b liste : %', v; END IF;
  v := public.renseignement_interroger(J);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION '5c interroger : %', v; END IF;
  v := public.renseignement_interroger(J);
  IF v->>'raison' IS DISTINCT FROM 'pas_en_interrogatoire' THEN RAISE EXCEPTION '5d second : %', v; END IF;
  PERFORM pg_temp.serveur();
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = J AND current_building = 'commissariat'
                   AND current_room = 'prison' AND NOT (est_emprisonne ? 'interrogatoire')) THEN RAISE EXCEPTION '5e cellule'; END IF;
  rap := rap || '5 interrogatoire OK; ';

  -- 6. Défense : rapports d'écoute depuis son bureau seulement ; opérations de l'autre ministère invisibles.
  PERFORM pg_temp.aller(J, 'palais-gouvernement', 'hall'); PERFORM pg_temp.poste(J, 'min_def'); PERFORM pg_temp.je_suis(UJ);
  v := public.sovarka_ecoutes_lire();
  IF v->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION '6a lieu : %', v; END IF;
  PERFORM pg_temp.aller(J, 'palais-gouvernement', 'bureau_min_def'); PERFORM pg_temp.je_suis(UJ);
  v := public.sovarka_ecoutes_lire();
  IF (v->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION '6b bureau : %', v; END IF;
  v := public.cellule_renseignement_mes_cellules();
  IF (v->>'ok')::boolean IS NOT TRUE OR jsonb_array_length(v->'cellules') <> 0 THEN RAISE EXCEPTION '6c cloisonnement : %', v; END IF;
  rap := rap || '6 Défense OK; ';

  PERFORM pg_temp.serveur();
  v := public.pnj_comparer_agents();
  rap := rap || 'socle agents ok=' || (v->>'ok') || ' attendues=' || (v->>'attendues') || ' div=' || (v->'divergences')::text;
  RAISE EXCEPTION 'BANC_RAPPORT %', rap;
END $banc$;
ROLLBACK;
