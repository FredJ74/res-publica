-- BANC ANNULE -- logements sociaux de Novomirsk (migration 20261106003000). Transaction finie par
-- une exception : rien ne reste. Jean Jaaj domicilie a Novomirsk : offre, demande a la mairie,
-- attribution d'un petit appartement par le moteur commun (porte de l'adjoint court-circuitee, acteur domicilie en Sovarka), premier loyer de 10,
-- courrier en PSK ; Montrouge garde son offre, Krasnov n'en a pas.
DO $$
DECLARE j text := 'Jean Jaaj'; uj uuid; r jsonb; arg0 numeric; dem text;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.path', '/rpc/banc', true);
  DELETE FROM public.locations_actives WHERE id LIKE 'soviet:logements-novomirsk:%';
  UPDATE public.personnages_donnees SET pa = 10, country = 'soviet', current_city = 'capitale', current_building = 'mairie-capitale',
         current_room = NULL, current_street = NULL, domicile = jsonb_build_object('country','soviet','city','capitale') WHERE name = j;
  DELETE FROM public.logements_demandes WHERE demandeur = j AND statut = 'en_attente';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.logements_sociaux_offre();
  IF (r->>'offre')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'offre: %', r; END IF;
  r := public.logement_social_demander('petit');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'demande: %', r; END IF;
  dem := r->>'demandeId';
  RESET ROLE;
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = j;
  r := public.logement_historique_attribuer_interne(j, 'capitale', 'logements-novomirsk', 'petit_appartement_1', dem);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'attribution: %', r; END IF;
  IF arg0 - (SELECT arg FROM public.personnages_donnees WHERE name = j) <> 10 THEN RAISE EXCEPTION 'premier loyer'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.locations_actives WHERE id = 'soviet:logements-novomirsk:petit_appartement_1:capitale'
                  AND data->>'locataire' = j AND data->>'logementSocial' = 'true') THEN RAISE EXCEPTION 'bail absent'; END IF;
  IF position(' PSK'' ELSE' IN pg_get_functiondef('public.logement_historique_attribuer_interne(text,text,text,text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'courrier en FR'; END IF;
  IF NOT public.logements_sociaux_ville_a_offre('republic', 'ville_b') OR public.logements_sociaux_ville_a_offre('soviet', 'ville_b') THEN
    RAISE EXCEPTION 'offres des autres villes'; END IF;
  RAISE EXCEPTION 'banc_logements_novomirsk_vert';
END $$;
