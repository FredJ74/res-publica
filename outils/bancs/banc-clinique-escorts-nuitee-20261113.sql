-- Banc : escorts en clinique, nuitée créditée au sommeil, service d'étage serveur (migration 20261113013000), 13/11/2026.
-- Joue la migration dans la transaction puis le scénario ; finit TOUJOURS par une exception : rien ne reste.
-- Coller la migration à l'endroit marqué. Compte de test : Arnie, chambre 5 de la clinique de Luthécia.
-- >>> MIGRATION 20261113013000_clinique_escorts_nuitee_serveur.sql ICI <<<
DO $banc$
DECLARE U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie'; L text := 'republic:clinique-privee:chambre_5:capitale';
  v jsonb; n integer; rec record; rap text := ''; noms text;
BEGIN
  DELETE FROM public.locations_actives WHERE id = L;
  DELETE FROM public.clinique_nuitees WHERE personnage = A;
  UPDATE public.pnj_membres SET statut = 'renvoye' WHERE proprietaire_pj = A AND famille = 'employe';
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'clinique-privee',
    current_room = 'chambre_5', current_street = NULL, hospitalisation = NULL, pa = 10, hp = 50, moral = 50,
    pa_repos_le = NULL, bonus_pa_differe = 0, liquide = 20000, est_emprisonne = NULL, detention_qhs = NULL WHERE name = A;
  INSERT INTO public.locations_actives (id, country, data)
  VALUES (L, 'republic', jsonb_build_object('buildingId', 'clinique-privee', 'roomId', 'chambre_5', 'city', 'capitale',
    'locataire', A, 'reservationClinique', true));
  INSERT INTO public.clinique_nuitees (personnage, country, room_id, reservee_le)
  VALUES (A, 'republic', 'chambre_5', (now() AT TIME ZONE 'Europe/Paris')::date);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', U, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- 1. Devis : en clinique, une femme et un homme au plus (Irina, Boris).
  v := public.escort_standard_devis('trois femmes et deux hommes');
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'femmes')::int <> 1 OR (v->>'hommes')::int <> 1 THEN RAISE EXCEPTION 'ECHEC 1 devis %', v; END IF;
  rap := rap || '1 devis 1+1 OK ; ';
  v := public.escort_standard_valider(gen_random_uuid(), 1, 1);
  SELECT string_agg(e->>'nom', ',' ORDER BY e->>'nom') INTO noms FROM jsonb_array_elements(v->'escorts') e;
  IF (v->>'ok')::boolean IS NOT TRUE OR noms IS DISTINCT FROM 'Boris,Irina' THEN RAISE EXCEPTION 'ECHEC 2 valider %', v; END IF;
  rap := rap || '2 Irina et Boris engagés OK ; ';

  -- 3. Sommeil : la nuitée est créditée dans le même appel.
  v := public.pa_repos_nocturne(A);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'ECHEC 3 repos %', v; END IF;
  SELECT pa, hp, moral INTO rec FROM public.personnages_donnees WHERE name = A;
  IF rec.pa <> 24 OR rec.hp <> 60 OR rec.moral <> 53 THEN RAISE EXCEPTION 'ECHEC 3 fiche pa % hp % moral %', rec.pa, rec.hp, rec.moral; END IF;
  rap := rap || '3 sommeil 10+12+2 PA, +10 santé, +3 moral OK ; ';
  v := public.clinique_nuitee_consommer();
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'rejeu')::boolean IS NOT TRUE OR (v->>'pa')::int <> 24 THEN RAISE EXCEPTION 'ECHEC 4 relecture %', v; END IF;
  rap := rap || '4 relecture sans second crédit OK ; ';

  -- 5. Le crédit de bonus différé n'est plus ouvert aux joueurs.
  BEGIN
    v := public.pa_bonus_differe_crediter(A, 'service_etage_hotel');
    RAISE EXCEPTION 'ECHEC 5 crédit libre %', v;
  EXCEPTION WHEN insufficient_privilege THEN rap := rap || '5 crédit libre refusé OK ; ';
  END;

  -- 6. Service d'étage : refusé hors hôtel et sans réservation.
  v := public.hotel_service_etage_commander();
  IF v->>'raison' IS DISTINCT FROM 'service_indisponible' THEN RAISE EXCEPTION 'ECHEC 6 hors hôtel %', v; END IF;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET current_building = 'hotel-republica', current_room = 'chambre' WHERE name = A;
  DELETE FROM public.hotel_nuitees WHERE personnage_id = (SELECT id FROM public.personnages_donnees WHERE name = A);
  PERFORM set_config('role', 'authenticated', true);
  v := public.hotel_service_etage_commander();
  IF v->>'raison' IS DISTINCT FROM 'chambre_non_reservee' THEN RAISE EXCEPTION 'ECHEC 6 sans réservation %', v; END IF;
  rap := rap || '6 service d''étage refusé sans chambre OK ; ';

  -- 7. Hors clinique, en Sovarka : Ludmilla est désormais tirable ; jamais Irina.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET country = 'soviet', current_building = 'residence-imperiale-novomirsk' WHERE name = A;
  SELECT count(*) INTO n FROM public.escort_disponibles_interne(A, 'F') WHERE nom = 'Ludmilla Bonaskova';
  IF n <> 1 THEN RAISE EXCEPTION 'ECHEC 7 Ludmilla absente'; END IF;
  SELECT count(*) INTO n FROM public.escort_disponibles_interne(A, 'F') WHERE pays = 'clinique';
  IF n <> 0 THEN RAISE EXCEPTION 'ECHEC 7 infirmière hors clinique'; END IF;
  UPDATE public.personnages_donnees SET country = 'republic' WHERE name = A;
  SELECT count(*) INTO n FROM public.escort_disponibles_interne(A, 'F') WHERE pays <> 'republic';
  IF n <> 0 THEN RAISE EXCEPTION 'ECHEC 7 Républia inchangée'; END IF;
  rap := rap || '7 tirages par lieu OK ; ';

  -- 8. Projet d'article : lieu clinique nommé.
  IF position('chambre de clinique' IN pg_get_functiondef('public.escort_scandale_presse_interne(text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'ECHEC 8 presse'; END IF;
  rap := rap || '8 presse OK';
  RAISE EXCEPTION 'BANC VERT (annulé) : %', rap;
END $banc$;
