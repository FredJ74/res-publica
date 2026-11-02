-- BANC ANNULÉ — blocus syndical au serveur (Claude, 02/11/2026).
-- À jouer APRÈS migrations/20261102135437_blocus_syndical_serveur.sql dans la même transaction
-- (voir banc-blocus-syndical.sh, qui les concatène) : l'exception finale porte le relevé et
-- annule tout. Rien ne doit rester.
-- Joué en production le 02/11/2026 (avant application) : tous les refus et effets attendus.
-- Acteurs : Angie Porcelana (Secrétaire Générale d'un syndicat témoin), Jean Népa (simple
-- adhérent, puis passant), Vince Kubrick (commissaire de Luthécia le temps du banc), Arnie (maire).
DO $banc$
DECLARE
  v_angie uuid; v_jean uuid; v_vince uuid; r jsonb; rel jsonb := '{}'::jsonb;
  v_org text := 'orga_banc_blocus'; i integer; v_fn text; v_pa integer; v_cost integer;
  v_pop_avant numeric;
BEGIN
  SELECT user_id INTO v_angie FROM public.personnages_donnees WHERE name = 'Angie Porcelana';
  SELECT user_id INTO v_jean  FROM public.personnages_donnees WHERE name = 'Jean Népa';
  SELECT user_id INTO v_vince FROM public.personnages_donnees WHERE name = 'Vince Kubrick';

  -- Décor (postgres).
  INSERT INTO public.organisations (id, country_origine, data) VALUES (v_org, 'republic',
    jsonb_build_object('id', v_org, 'type', 'syndicale', 'nom', 'Syndicat du Banc', 'country', 'republic',
      'chef', 'Angie Porcelana', 'membres', jsonb_build_array(
        jsonb_build_object('nom', 'Angie Porcelana', 'gradeIdx', 3),
        jsonb_build_object('nom', 'Jean Népa', 'gradeIdx', 1)))::text);
  FOR i IN 1..3 LOOP
    INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj, ville, building_id, room_id, pa, statut,
        car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    SELECT 'militant-banc-' || i, 'militant', 'beta', 'Militant Banc ' || i, 'republic', 'Angie Porcelana',
           'capitale', 'banque-nationale', 'accueil_banque', 12, 'actif',
           f.car_int, f.car_cha, f.car_vol, f.car_per, f.car_dup, f.car_ent
      FROM public.pnj_metiers_profils f WHERE f.metier = 'militant';
    INSERT INTO public.pnj_militants_metier (pnj_id, organisation_id, grade, rejoint_le)
    VALUES ('militant-banc-' || i, v_org, 'Militant (PNJ)', now());
  END LOOP;
  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'banque-nationale',
         current_room = 'accueil_banque', current_street = NULL, pa = 20
   WHERE name IN ('Angie Porcelana', 'Jean Népa');
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id', 'commissaire', 'city', 'capitale'),
         current_city = 'capitale', current_building = 'commissariat', current_room = 'accueil_police',
         current_street = NULL, pa = 80
   WHERE name = 'Vince Kubrick';
  SELECT o.fn, c.pa, c.cost INTO v_fn, v_pa, v_cost FROM public.blocus_ordres_batiments o
    JOIN public.ordres_couts c ON c.fn = o.fn
   WHERE o.ville = 'capitale' AND o.batiment = 'banque-nationale' AND c.pa > 0 AND c.cost = 0 LIMIT 1;
  rel := rel || jsonb_build_object('ordre_temoin', v_fn,
    'catalogue', (SELECT count(*) FROM public.blocus_ordres_batiments),
    'mobiliser_police_au_catalogue', EXISTS (SELECT 1 FROM public.blocus_ordres_batiments WHERE fn = 'mobiliser_police'));

  -- Organiser. request.path imite l'appel du navigateur (/rpc/...) : sans lui, le garde POP de la
  -- fiche (personnages_fusionner_pop) prendrait le banc pour une sauvegarde de l'écran.
  PERFORM set_config('request.path', '/rpc/banc_blocus', true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_jean, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := public.blocus_syndical_organiser(v_org, 3, 'Banc');
  rel := rel || jsonb_build_object('adherent_organise', r->>'raison');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_angie, 'role', 'authenticated')::text, true);
  r := public.blocus_syndical_organiser(v_org, 1, 'Banc');
  rel := rel || jsonb_build_object('un_militant', r->>'raison');
  r := public.blocus_syndical_organiser(v_org, 4, 'Banc');
  rel := rel || jsonb_build_object('quatre_militants', r->>'raison');
  FOR i IN 1..40 LOOP
    r := public.blocus_syndical_organiser(v_org, 3, 'Contre le banc d''essai');
    EXIT WHEN (r->>'reussi')::boolean IS TRUE OR (r->>'ok')::boolean IS NOT TRUE;
  END LOOP;
  rel := rel || jsonb_build_object('organise', r->>'reussi', 'essais', i, 'taux', r->>'taux', 'intensite', r->>'intensite');
  r := public.blocus_syndical_organiser(v_org, 3, 'Banc');
  rel := rel || jsonb_build_object('deja_bloque', r->>'raison');
  r := public.batiment_etat_sous_cle_ecrire('republic', 'capitale', 'banque-nationale', 'blocus', 'null'::jsonb);
  rel := rel || jsonb_build_object('ecran_leve', r->>'raison');
  r := public.blocus_syndicaux_actifs('republic');
  rel := rel || jsonb_build_object('liste', jsonb_array_length(r), 'liste_ville', r->0->>'city');

  -- Effets sur le bâtiment : première pièce seulement, ordres du bâtiment refusés.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_jean, 'role', 'authenticated')::text, true);
  r := public.payer_ordre('Jean Népa', v_fn, v_pa, v_cost);
  rel := rel || jsonb_build_object('ordre_batiment', r->>'raison');
  r := public.blocus_syndical_renouveler('capitale', 'banque-nationale');
  rel := rel || jsonb_build_object('adherent_renouvelle', r->>'raison');
  RESET ROLE;
  r := public.navigation_interieure_personnage_interne('Jean Népa', 'banque-nationale', 'coffre_privatif', true);
  rel := rel || jsonb_build_object('piece_interieure', coalesce(r->>'raison', r->>'ok'));
  r := public.navigation_interieure_personnage_interne('Jean Népa', 'banque-nationale', 'accueil_banque', true);
  rel := rel || jsonb_build_object('premiere_piece', coalesce(r->>'raison', r->>'ok'));

  -- Renouveler (Angie, à distance : on la sort du bâtiment).
  UPDATE public.personnages_donnees SET current_building = NULL, current_room = NULL WHERE name = 'Angie Porcelana';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_angie, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := public.blocus_syndical_renouveler('capitale', 'banque-nationale');
  rel := rel || jsonb_build_object('renouvele', r->>'ok');

  -- Commissaire.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_vince, 'role', 'authenticated')::text, true);
  r := public.blocus_syndical_intervenir('capitale', 'banque-nationale', 'disperser');
  rel := rel || jsonb_build_object('hors_bureau', r->>'raison');
  RESET ROLE;
  UPDATE public.personnages_donnees SET current_room = 'bureau_commissaire' WHERE name = 'Vince Kubrick';
  SELECT (resources->>'pop')::numeric INTO v_pop_avant FROM public.personnages_donnees WHERE name = 'Vince Kubrick';
  PERFORM set_config('role', 'authenticated', true);
  r := public.blocus_syndical_intervenir('capitale', 'banque-nationale', 'reprimer');
  rel := rel || jsonb_build_object('reprimer', r->>'ok', 'reprimer_leve', r->>'leve', 'reprimer_pop', r->>'pop',
    'pop_avant', v_pop_avant, 'pa_apres_reprimer', r#>>'{paiement,pa}');
  FOR i IN 1..30 LOOP
    r := public.blocus_syndical_intervenir('capitale', 'banque-nationale', 'disperser');
    EXIT WHEN (r->>'leve')::boolean IS TRUE OR (r->>'ok')::boolean IS NOT TRUE;
  END LOOP;
  rel := rel || jsonb_build_object('disperse', r->>'leve', 'disperser_essais', i, 'disperser_taux', r->>'taux',
    'disperser_raison', r->>'raison');
  r := public.blocus_syndical_intervenir('capitale', 'banque-nationale', 'disperser');
  rel := rel || jsonb_build_object('plus_de_blocus', r->>'raison');
  RESET ROLE;
  rel := rel || jsonb_build_object('palmares', (SELECT data::jsonb->'blocusReussis' FROM public.organisations WHERE id = v_org),
    'repressions', (SELECT data::jsonb->'repressionsSubies' FROM public.organisations WHERE id = v_org),
    'mail_dispersion', (SELECT count(*) FROM public.mails m WHERE m.to_player = 'Angie Porcelana' AND m.subject = 'Blocus dispersé'));
  r := public.navigation_interieure_personnage_interne('Jean Népa', 'banque-nationale', 'coffre_privatif', true);
  rel := rel || jsonb_build_object('piece_apres_levee', coalesce(r->>'raison', r->>'ok'));

  -- Nuit : un blocus périmé est levé ; un blocus actif coûte du POP au maire de la ville.
  PERFORM public.blocus_ecrire_interne('republic', 'capitale', 'banque-nationale', jsonb_build_object(
    'syndicatId', v_org, 'syndicatNom', 'Syndicat du Banc', 'intensite', 28, 'leaderActuel', 'Angie Porcelana',
    'lanceLe', 0, 'dernierRenouvellementTimestamp', floor(extract(epoch FROM now()) * 1000) - 26 * 3600000));
  PERFORM public.blocus_ecrire_interne('republic', 'capitale', 'mairie', jsonb_build_object(
    'syndicatId', v_org, 'syndicatNom', 'Syndicat du Banc', 'intensite', 60, 'leaderActuel', 'Angie Porcelana',
    'lanceLe', 0, 'dernierRenouvellementTimestamp', floor(extract(epoch FROM now()) * 1000)));
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id', 'maire', 'city', 'capitale') WHERE name = 'Arnie';
  SELECT (resources->>'pop')::numeric INTO v_pop_avant FROM public.personnages_donnees WHERE name = 'Arnie';
  rel := rel || jsonb_build_object('nuit_expirer', public.blocus_nuit_expirer()->'leves',
    'nuit_effets', public.blocus_nuit_effets()->'appliques',
    'maire_pop_avant', v_pop_avant,
    'maire_pop_apres', (SELECT resources->>'pop' FROM public.personnages_donnees WHERE name = 'Arnie'),
    'reste_banque', public.blocus_actif_interne('republic', 'capitale', 'banque-nationale') IS NOT NULL,
    'reste_mairie', public.blocus_actif_interne('republic', 'capitale', 'mairie') IS NOT NULL);

  RAISE EXCEPTION 'banc blocus annule : %', rel;
END $banc$;
