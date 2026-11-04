-- A jouer APRES le corps de la migration 20261104121000, dans la meme transaction annulee.
-- Poste de l'aeroport (3 douaniers groupes, detecteurs), relève de minuit, contrôle des voyageurs :
-- fouille a l'aeroport, aucune fouille au port pour un non-recherche.
DO $$
DECLARE n text := 'Jean Jaaj'; r jsonb; v_chef text; v_inv jsonb; arme jsonb := '{"name":"Pistolet banc","type":"arme","legal":false}';
BEGIN
  -- Poste en place.
  IF (SELECT count(*) FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
      WHERE m.famille = 'douanier' AND m.statut = 'actif' AND m.pa > 0 AND pe.building_id = 'centre-multinodal-luthecia'
        AND pe.room_id = 'hall_douanes') <> 3 THEN RAISE EXCEPTION 'poste: pas 3 douaniers'; END IF;
  IF jsonb_array_length(public.douane_agents_presents_interne('republic', 'capitale', 'centre-multinodal-luthecia', 'hall_douanes')) <> 1 THEN
    RAISE EXCEPTION 'poste: pas un seul groupe'; END IF;
  IF position('douane_agents_presents_interne' IN pg_get_functiondef('public.police_detection_contexte_interne(text,text,text,text,boolean)'::regprocedure)) = 0
     OR position('douane_voyageurs_v1' IN pg_get_functiondef('public.douane_controle_groupe_interne(text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'patchs absents'; END IF;

  -- Relève : un douanier hors de combat est remplacé.
  SELECT id INTO v_chef FROM public.pnj_membres WHERE famille = 'douanier' AND building_id = 'centre-multinodal-luthecia' AND leader_pnj_id IS NOT NULL LIMIT 1;
  UPDATE public.pnj_membres SET pa = 0 WHERE id = v_chef;
  r := public.douane_aeroport_relever_interne();
  IF (r->>'remplaces')::integer <> 1 OR (r->>'gardes')::integer <> 2 THEN RAISE EXCEPTION 'releve: %', r; END IF;
  IF (SELECT count(*) FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
      WHERE m.famille = 'douanier' AND m.statut = 'actif' AND m.pa > 0 AND pe.room_id = 'hall_douanes') <> 3 THEN
    RAISE EXCEPTION 'releve: pas 3 douaniers'; END IF;

  -- Contrôle des voyageurs (Jean non recherché dans ce banc).
  IF EXISTS (SELECT 1 FROM public.douane_recherches_interne(n)) THEN RAISE EXCEPTION 'banc: Jean est recherche, choisir un autre PJ'; END IF;
  DELETE FROM public.groupes_pj_adhesions WHERE chef = n OR membre = n;
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb) || jsonb_build_array(arme),
    country = 'republic', current_city = 'ville_a', current_building = 'port-sainte-marie', current_room = 'quai_principal', current_street = NULL
   WHERE name = n;
  r := public.douane_controle_groupe_interne(n, 'bateau');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'port: %', r; END IF;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = n;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE e->>'name' = 'Pistolet banc') THEN RAISE EXCEPTION 'port: voyageur non recherche fouille'; END IF;

  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'centre-multinodal-luthecia', current_room = 'hall_douanes' WHERE name = n;
  r := public.douane_controle_groupe_interne(n, 'avion');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'aeroport: %', r; END IF;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = n;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE e->>'name' = 'Pistolet banc') THEN RAISE EXCEPTION 'aeroport: arme non saisie'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (poste 3 douaniers, releve, port sans fouille, aeroport fouille)';
END $$;
