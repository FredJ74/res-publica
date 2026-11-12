-- BANC ANNULE -- escorts Roxane Velours, rumeur et presse, espionnage, service d'étage (migration 20261112005000).
-- A jouer APRES la migration (ou concaténé derrière elle), dans une transaction qui finit par une exception :
-- rien ne reste. Acteurs : Arnie (locataire de l'appartement n°1 de la Résidence), Jean Jaaj (ministre de la
-- Sécurité du Peuple simulé).
DO $$
DECLARE a text := 'Arnie'; j text := 'Jean Jaaj'; ua uuid; uj uuid; r jsonb; req uuid := gen_random_uuid();
  arg0 numeric; arg1 numeric; pop0 numeric; pop1 numeric; v_trace text; n integer; caisse0 numeric; caisse1 numeric; i integer;
BEGIN
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = a;
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale', current_street = NULL, pa = 20, liquide = 20000,
         current_building = 'residence-imperiale-novomirsk', current_room = 'hall_residence',
         resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{pop}', '50') WHERE name = a;
  UPDATE public.pnj_membres SET statut = 'disparu', leader_pj = NULL WHERE proprietaire_pj = a AND famille = 'employe';
  DELETE FROM public.residence_locations WHERE locataire = a OR piece = 'appartement_1';
  INSERT INTO public.residence_locations (piece, locataire, fin) VALUES ('appartement_1', a, now() + interval '2 days');

  -- 1. Hors de son appartement : refus nommé.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.escort_standard_devis('une escort');
  IF r->>'raison' IS DISTINCT FROM 'reserve_au_locataire' THEN RAISE EXCEPTION 'hors appartement: %', r; END IF;
  RESET ROLE;
  UPDATE public.personnages_donnees SET current_room = 'appartement_1' WHERE name = a;

  -- 2. Demandes libres : incomprise, genre imprécis, puis deux femmes et un homme.
  SET LOCAL ROLE authenticated;
  r := public.escort_standard_devis('Bonsoir');
  IF r->>'raison' IS DISTINCT FROM 'demande_incomprise' THEN RAISE EXCEPTION 'incomprise: %', r; END IF;
  r := public.escort_standard_devis('2 escorts');
  IF r->>'raison' IS DISTINCT FROM 'genre_imprecis' THEN RAISE EXCEPTION 'imprecis: %', r; END IF;
  r := public.escort_standard_devis('Deux femmes et un homme, je vous prie.');
  IF (r->>'nombre')::int <> 3 OR (r->>'montant')::int <> 2400 THEN RAISE EXCEPTION 'devis: %', r; END IF;
  RESET ROLE;
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = a;
  SET LOCAL ROLE authenticated;
  r := public.escort_standard_valider(req, 2, 1);
  IF (r->>'ok')::boolean IS NOT TRUE OR jsonb_array_length(r->'escorts') <> 3 THEN RAISE EXCEPTION 'validation: %', r; END IF;
  r := public.escort_standard_valider(req, 2, 1);
  IF (r->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r; END IF;
  RESET ROLE;
  SELECT arg INTO arg1 FROM public.personnages_donnees WHERE name = a;
  IF arg0 - arg1 <> 2400 THEN RAISE EXCEPTION 'paiement: % -> %', arg0, arg1; END IF;
  SELECT count(*) INTO n FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id = m.id
   WHERE m.proprietaire_pj = a AND m.statut = 'actif' AND m.leader_pj = a AND em.job = 'escort' AND em.cout_jour = 800;
  IF n <> 3 THEN RAISE EXCEPTION 'escorts embauchés: %', n; END IF;
  SELECT trace_id INTO v_trace FROM public.escort_appels WHERE requete = req;
  IF NOT EXISTS (SELECT 1 FROM public.actions_tracables WHERE id = v_trace AND type_action = 'appel_escort' AND auteur = a
                  AND cible LIKE 'residence|%' AND country = 'soviet') THEN RAISE EXCEPTION 'trace absente'; END IF;

  -- 3. Rumeur : trois écoutes = −9 POP, projets d'article (Sovarka, et pays du poste s'il est étranger).
  SELECT (resources->>'pop')::numeric INTO pop0 FROM public.personnages_donnees WHERE name = a;
  PERFORM public.escort_scandale_ecoute_interne(v_trace);
  PERFORM public.escort_scandale_ecoute_interne(v_trace);
  IF EXISTS (SELECT 1 FROM public.interieur_dossiers WHERE donnees->>'trace' = v_trace) THEN RAISE EXCEPTION 'presse trop tôt'; END IF;
  PERFORM public.escort_scandale_ecoute_interne(v_trace);
  SELECT (resources->>'pop')::numeric INTO pop1 FROM public.personnages_donnees WHERE name = a;
  IF pop0 - pop1 <> 9 THEN RAISE EXCEPTION 'POP: % -> %', pop0, pop1; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.interieur_dossiers WHERE donnees->>'trace' = v_trace AND pays = 'soviet' AND type = 'projet_article'
                  AND contenu LIKE '%Roxane Velours dans son appartement de la Résidence impériale%') THEN RAISE EXCEPTION 'projet Sovarka absent'; END IF;
  PERFORM public.escort_scandale_ecoute_interne(v_trace);
  IF (SELECT count(*) FROM public.interieur_dossiers WHERE donnees->>'trace' = v_trace AND pays = 'soviet') <> 1 THEN RAISE EXCEPTION 'projet en double'; END IF;
  SELECT (resources->>'pop')::numeric INTO pop1 FROM public.personnages_donnees WHERE name = a;
  IF pop0 - pop1 <> 12 THEN RAISE EXCEPTION 'POP après la 4e écoute: % -> %', pop0, pop1; END IF;

  -- 4. Le ministre PJ : courrier, lecture, publication.
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source, updated_at)
  VALUES ('soviet_min_int_national', 'soviet', 'min_int', NULL, j, now(), 'banc', now()) ON CONFLICT (id) DO UPDATE SET titulaire = j, updated_at = now();
  UPDATE public.personnages_donnees SET poste = '{"id":"min_int","name":"Ministre de l''Intérieur"}' WHERE name = j;
  UPDATE public.escort_scandales SET journalistes_prevenus = false WHERE trace_id = v_trace;
  DELETE FROM public.interieur_dossiers WHERE donnees->>'trace' = v_trace;
  PERFORM public.escort_scandale_ecoute_interne(v_trace);
  IF NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player = j AND subject LIKE 'Projet d''article — Soirée velours%') THEN RAISE EXCEPTION 'courrier au ministre absent'; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.interieur_dossiers_lire();
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'pays' <> 'soviet' THEN RAISE EXCEPTION 'lecture: %', r; END IF;
  SELECT (d->>'id')::bigint INTO n FROM jsonb_array_elements(r->'dossiers') d WHERE d->>'type' = 'projet_article' AND d->>'statut' = 'nouveau' LIMIT 1;
  r := public.interieur_projet_decider(n, 'attente');
  IF r->>'statut' IS DISTINCT FROM 'en_attente' THEN RAISE EXCEPTION 'attente: %', r; END IF;
  r := public.interieur_projet_decider(n, 'publier');
  IF r->>'statut' IS DISTINCT FROM 'publie' THEN RAISE EXCEPTION 'publication: %', r; END IF;
  RESET ROLE;
  IF NOT EXISTS (SELECT 1 FROM public.journal_articles_en_attente WHERE id = 'scandale-escort-' || n AND country = 'soviet'
                  AND origine = 'scandale_escort' AND integree_le IS NULL) THEN RAISE EXCEPTION 'article absent du journal'; END IF;
  -- Un autre que le ministre : refus.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.interieur_dossiers_lire();
  IF r->>'raison' IS DISTINCT FROM 'poste_requis' THEN RAISE EXCEPTION 'lecture non ministre: %', r; END IF;
  RESET ROLE;

  -- 5. Secret confié à une escort en Sovarka : transmis au ministre.
  INSERT INTO public.renseignements_connus (id, titulaire, contenu, source, categorie, mode_acquisition, jour_acquisition,
                                            jour_derniere_reactivation, jour_expiration)
  VALUES ('rc_banc_' || replace(gen_random_uuid()::text, '-', ''), 'Roxane', a || ' a confié : « banc »', a, 'personnel', 'confidence', 1, 1, 99);
  IF NOT EXISTS (SELECT 1 FROM public.interieur_dossiers WHERE type = 'secret_escort' AND cible = a AND contenu LIKE '%banc%') THEN
    RAISE EXCEPTION 'secret non transmis'; END IF;

  -- 6. Piratage nocturne : ordinateur dans l'inventaire, un dossier, 25 % par nuit.
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb)
         || '[{"id":"obj-banc-ordinateur","generique_id":"ordinateur-complet","name":"Ordinateur"}]'::jsonb WHERE name = a;
  INSERT INTO public.dossiers_informatiques (objet_id, support, type, titre, contenu, auteur)
  VALUES ('obj-banc-ordinateur', 'ordinateur', 'faux_document', 'Plan secret du banc', 'contenu du banc', a);
  FOR i IN 1..80 LOOP
    DELETE FROM public.escort_piratages_nuits WHERE nom = a;
    PERFORM public.escort_piratage_nuit_interne(a);
    EXIT WHEN EXISTS (SELECT 1 FROM public.interieur_dossiers WHERE type = 'dossier_pirate' AND cible = a);
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM public.interieur_dossiers WHERE type = 'dossier_pirate' AND cible = a AND contenu = 'contenu du banc') THEN
    RAISE EXCEPTION 'piratage jamais réussi en 80 nuits'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_informatiques WHERE objet_id = 'obj-banc-ordinateur') THEN RAISE EXCEPTION 'original perdu'; END IF;
  PERFORM public.escort_piratage_nuit_interne(a);
  IF (SELECT count(*) FROM public.escort_piratages_nuits WHERE nom = a) <> 1 THEN RAISE EXCEPTION 'deux tirages la même nuit'; END IF;

  -- 7. Service d'étage : carte, commande, 20 PSK de service à la caisse de l'hôtel.
  SELECT (data->>'caisse')::numeric INTO caisse0 FROM public.entreprises WHERE id = 'brasserie-soviet-capitale-hotel-republica';
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockProduits,cafe_boisson}', '5') WHERE id = 'brasserie-soviet-capitale-hotel-republica';
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = a;
  SET LOCAL ROLE authenticated;
  r := public.service_etage_carte();
  IF (r->>'ok')::boolean IS NOT TRUE OR jsonb_array_length(r->'carte') < 3 THEN RAISE EXCEPTION 'carte: %', r; END IF;
  r := public.service_etage_commander(req, 'cafe_boisson');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'service')::int <> 20 THEN RAISE EXCEPTION 'commande: %', r; END IF;
  RESET ROLE;
  SELECT arg INTO arg1 FROM public.personnages_donnees WHERE name = a;
  SELECT (data->>'caisse')::numeric INTO caisse1 FROM public.entreprises WHERE id = 'brasserie-soviet-capitale-hotel-republica';
  IF arg0 - arg1 <> 27 THEN RAISE EXCEPTION 'prix du café servi: % (7 + 20 attendus)', arg0 - arg1; END IF;
  IF caisse1 - caisse0 < 20 THEN RAISE EXCEPTION 'caisse de l''hôtel: % -> %', caisse0, caisse1; END IF;

  RAISE EXCEPTION 'BANC_OK escorts Roxane Velours';
END $$;
