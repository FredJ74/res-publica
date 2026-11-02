-- BANC ANNULÉ — étape B des organisations (Claude, 02/11/2026).
-- À jouer APRÈS les migrations 20261102000900..001300 dans la même transaction (voir
-- outils/bancs/banc-organisations-etape-b.sh, qui les concatène), puis tout est annulé par
-- l'exception finale, qui porte le relevé. Rien ne doit rester.
-- Acteur : Angie Porcelana (testeuse), au rôle authenticated.
DO $banc$
DECLARE v_uid uuid; r jsonb; rel jsonb := '{}'::jsonb; v_org text; v_gg text := 'greve_generale_banc_etape_b';
  v_infl numeric; v_err text; v_pa_avant integer;
BEGIN
  SELECT user_id INTO v_uid FROM public.personnages_donnees WHERE name = 'Angie Porcelana';
  -- Décor (postgres) : un local loué au nom d'Angie, où elle se trouve.
  INSERT INTO public.locations_actives (id, country, data) VALUES ('republic:centre-commercial:banc_b:capitale', 'republic',
    jsonb_build_object('city', 'capitale', 'roomId', 'banc_b', 'country', 'republic', 'locataire', 'Angie Porcelana',
                       'buildingId', 'centre-commercial', 'orgaAutorisee', true));
  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'centre-commercial',
         current_room = 'banc_b', pa = greatest(coalesce(pa, 0), 10) WHERE name = 'Angie Porcelana';

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  r := public.organisation_vie_commande('orgcmd-banc-b-0001', NULL, 'fonder', '{"type":"syndicale","nom":"Banc B","corpsMetier":"police"}');
  rel := rel || jsonb_build_object('fonder', coalesce(r->>'ok', r->>'raison')); v_org := r->>'organisation';
  r := public.organisation_vie_commande('orgcmd-banc-b-0001', NULL, 'fonder', '{"type":"syndicale","nom":"Banc B","corpsMetier":"police"}');
  rel := rel || jsonb_build_object('fonder_rejeu', r->>'rejeu', 'meme_orga', (r->>'organisation') = v_org);
  r := public.organisation_vie_commande('orgcmd-banc-b-0002', NULL, 'fonder', '{"type":"syndicale","nom":"Banc B2"}');
  rel := rel || jsonb_build_object('fonder_type_deja', r->>'raison');
  r := public.organisation_vie_commande('orgcmd-banc-b-0003', NULL, 'fonder', '{"type":"supporters","nom":"Banc S"}');
  rel := rel || jsonb_build_object('fonder_supporters', r->>'raison');
  r := public.organisation_vie_commande('orgcmd-banc-b-0004', NULL, 'fonder', '{"type":"politique","nom":"Banc P"}');
  rel := rel || jsonb_build_object('fonder_local_occupe', r->>'raison');
  RESET ROLE;
  rel := rel || jsonb_build_object('blob', (SELECT data::jsonb - 'creeLe' - 'id' FROM public.organisations WHERE id = v_org));
  PERFORM set_config('role', 'authenticated', true);

  r := public.organisation_vie_commande('orgcmd-banc-b-0010', v_org, 'greve_lancer', '{"type":"pays","cibleValue":"republic","cibleLabel":"Républia","revendications":"Banc"}');
  rel := rel || jsonb_build_object('greve_trop_petit', r->>'raison');
  RESET ROLE;
  UPDATE public.organisations SET data = jsonb_set(data::jsonb, '{membres}', data::jsonb->'membres' ||
    '[{"nom":"PNJ 1 (PNJ)"},{"nom":"PNJ 2 (PNJ)"},{"nom":"PNJ 3 (PNJ)"},{"nom":"PNJ 4 (PNJ)"}]'::jsonb)::text WHERE id = v_org;
  SELECT pa INTO v_pa_avant FROM public.personnages_donnees WHERE name = 'Angie Porcelana';
  PERFORM set_config('role', 'authenticated', true);
  r := public.organisation_vie_commande('orgcmd-banc-b-0011', v_org, 'greve_lancer', '{"type":"pays","cibleValue":"republic","cibleLabel":"Républia","revendications":"Banc"}');
  RESET ROLE;
  rel := rel || jsonb_build_object('greve_lancer', coalesce(r->>'ok', r->>'raison'), 'greve_pa', v_pa_avant - (SELECT pa FROM public.personnages_donnees WHERE name = 'Angie Porcelana'));
  PERFORM set_config('role', 'authenticated', true);
  r := public.organisation_vie_commande('orgcmd-banc-b-0012', v_org, 'greve_lancer', '{"type":"pays","cibleValue":"republic","cibleLabel":"Républia","revendications":"Banc"}');
  rel := rel || jsonb_build_object('greve_deja', r->>'raison');
  r := public.organisation_vie_commande('orgcmd-banc-b-0013', v_org, 'greve_terminer', '{}');
  rel := rel || jsonb_build_object('greve_terminer', r->>'ok', 'greve_rendue', r->'greve'->>'revendications');

  r := public.organisation_vie_commande('orgcmd-banc-b-0020', 'orga_syndicat_dockers_republic_ville_a', 'dockers_assurer', '{}');
  RESET ROLE;
  rel := rel || jsonb_build_object('dockers', r->>'ok', 'dockers_chef', (SELECT data::jsonb->>'chef' FROM public.organisations WHERE id = 'orga_syndicat_dockers_republic_ville_a'));
  PERFORM set_config('role', 'authenticated', true);

  -- Grève générale : la table (encore écrite par l'écran) dicte, la synchronisation recopie.
  RESET ROLE;
  INSERT INTO public.greves_generales (id, country, statut, initiateur, syndicat_initiateur_id, revendications, participants, jours_actifs)
  VALUES (v_gg, 'republic', 'consultation', 'Angie Porcelana', v_org, 'Banc',
          jsonb_build_array(jsonb_build_object('orgaId', v_org, 'statut', 'accepte'),
                            jsonb_build_object('orgaId', 'orga_syndicat_dockers_republic_ville_a', 'statut', 'refuse')), 0);
  PERFORM set_config('role', 'authenticated', true);
  r := public.greve_generale_synchroniser(v_gg);
  RESET ROLE;
  rel := rel || jsonb_build_object('gg_consultation', (SELECT data::jsonb->>'greveGeneraleStatut' FROM public.organisations WHERE id = v_org),
    'gg_consultation_dockers', (SELECT data::jsonb->>'greveGeneraleStatut' FROM public.organisations WHERE id = 'orga_syndicat_dockers_republic_ville_a'));
  PERFORM set_config('role', 'authenticated', true);
  RESET ROLE; UPDATE public.greves_generales SET statut = 'active' WHERE id = v_gg; PERFORM set_config('role', 'authenticated', true);
  r := public.greve_generale_synchroniser(v_gg);
  RESET ROLE;
  rel := rel || jsonb_build_object('gg_active', (SELECT data::jsonb->>'greveGeneraleEnCoursId' FROM public.organisations WHERE id = v_org),
    'gg_active_dockers', coalesce((SELECT data::jsonb->>'greveGeneraleStatut' FROM public.organisations WHERE id = 'orga_syndicat_dockers_republic_ville_a'), 'null'));
  PERFORM set_config('role', 'authenticated', true);
  RESET ROLE; UPDATE public.greves_generales SET statut = 'terminee' WHERE id = v_gg; PERFORM set_config('role', 'authenticated', true);
  r := public.greve_generale_synchroniser(v_gg);
  RESET ROLE;
  rel := rel || jsonb_build_object('gg_terminee', coalesce((SELECT data::jsonb->>'greveGeneraleStatut' FROM public.organisations WHERE id = v_org), 'null'));
  PERFORM set_config('role', 'authenticated', true);

  -- Militant : compté dans SON syndicat ; un syndicat dont on n'est pas membre est refusé.
  r := public.militant_recruter('Banc Militant (PNJ)', 'orga_syndicat_dockers_republic_ville_a', 'capitale', 'universite', 'salle_reunion', 'recruter_militants', 0, 0);
  rel := rel || jsonb_build_object('militant_autre_syndicat', coalesce(r->>'raison', r->>'ok'));
  r := public.militant_recruter('Banc Militant (PNJ)', v_org, 'capitale', 'universite', 'salle_reunion', 'recruter_militants', 0, 0);
  RESET ROLE;
  rel := rel || jsonb_build_object('militant', coalesce(r->>'ok', r->>'raison'),
    'militant_membre', (SELECT count(*) FROM jsonb_array_elements((SELECT data::jsonb->'membres' FROM public.organisations WHERE id = v_org)) m
                         WHERE m->>'nom' = 'Banc Militant (PNJ)' AND (m->>'estPnj')::boolean));
  PERFORM set_config('role', 'authenticated', true);

  -- Rumeur contre l'organisation : l'influence baisse de la perte tirée par le serveur.
  r := public.rumeur_lancer('organisation', v_org, 'Banc', 'Banc', 0, 0);
  RESET ROLE;
  SELECT (data::jsonb->>'influence')::numeric INTO v_infl FROM public.organisations WHERE id = v_org;
  PERFORM set_config('role', 'authenticated', true);
  rel := rel || jsonb_build_object('rumeur', coalesce(r->>'ok', r->>'raison'), 'rumeur_reussie', r->>'reussi', 'rumeur_coherente',
    CASE WHEN (r->>'reussi')::boolean THEN v_infl = 50 - (r->>'perte')::numeric ELSE v_infl = 50 END);

  -- Supporters : cotisation + inscription en un geste, puis refus du doublon.
  r := public.club_supporters_adherer('caisse-banc-b-0030-abcdef', 'olympique-luthecia', 'Alfredo Mifassole (PNJ)');
  RESET ROLE;
  rel := rel || jsonb_build_object('supporters', coalesce(r->>'ok', '') || '/' || coalesce(r->>'raison', ''),
    'supporters_chef', (SELECT data::jsonb->>'chef' FROM public.organisations WHERE id = 'orga_supporters_republic_capitale'));
  PERFORM set_config('role', 'authenticated', true);
  r := public.club_supporters_adherer('caisse-banc-b-0031-abcdef', 'olympique-luthecia', 'Angie Porcelana');
  rel := rel || jsonb_build_object('supporters_doublon', r->>'raison');

  -- Fermeture : l'écran ne peut plus écrire la table.
  BEGIN
    UPDATE public.organisations SET data = data WHERE id = v_org; v_err := 'update_accepte';
  EXCEPTION WHEN insufficient_privilege THEN v_err := 'update_refuse'; END;
  rel := rel || jsonb_build_object('ecran_update', v_err);
  BEGIN
    INSERT INTO public.organisations (id, country_origine, data) VALUES ('orga_banc_b_x', 'republic', '{}'); v_err := 'insert_accepte';
  EXCEPTION WHEN insufficient_privilege THEN v_err := 'insert_refuse'; END;
  rel := rel || jsonb_build_object('ecran_insert', v_err);

  RAISE EXCEPTION 'BANC_ANNULE %', rel;
END $banc$;
