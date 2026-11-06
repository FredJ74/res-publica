-- A jouer APRES le corps de la migration 20261105110100, dans la meme transaction annulee.
-- BANC (annulé) : un PJ réel fait commissaire de Luthécia le temps de la transaction.
DO $$
DECLARE a text; ua uuid; b text; r jsonb; i integer; vu_ok boolean := false; vu_ko boolean := false; refuse boolean := false;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE user_id IS NOT NULL AND name <> a ORDER BY name LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.filature_mener(b, false);
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'autorite_insuffisante' THEN RAISE EXCEPTION 'sans poste: %', r; END IF;

  UPDATE public.postes_attribues SET titulaire = a WHERE country = 'republic' AND poste_id = 'commissaire' AND city = 'capitale';
  IF NOT FOUND THEN
    INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source)
    VALUES ('banc-commissaire', 'republic', 'commissaire', 'capitale', a, now(), 'banc');
  END IF;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'commissariat',
    poste = '{"id":"commissaire","city":"capitale"}'::jsonb WHERE name = a;

  SET LOCAL ROLE authenticated;
  FOR i IN 1..30 LOOP
    r := public.filature_mener(b, false);
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'filature: %', r; END IF;
    IF (r->>'abouti')::boolean THEN
      IF jsonb_typeof(r->'deplacements') <> 'array' THEN RAISE EXCEPTION 'registre absent: %', r; END IF;
      vu_ok := true;
    ELSE
      IF r ? 'deplacements' THEN RAISE EXCEPTION 'registre livre sur un echec: %', r; END IF;
      vu_ko := true;
    END IF;
    IF (r->>'taux')::int NOT BETWEEN 10 AND 90 THEN RAISE EXCEPTION 'taux hors bornes: %', r; END IF;
    EXIT WHEN vu_ok AND vu_ko;
  END LOOP;
  r := public.chasse_homme_mener(b, 'banc-inexistant', 'capitale', false);
  BEGIN
    PERFORM public.filature_deplacements(b);
  EXCEPTION WHEN insufficient_privilege THEN refuse := true;
  END;
  RESET ROLE;
  IF NOT refuse THEN RAISE EXCEPTION 'filature_deplacements encore appelable directement'; END IF;
  IF NOT (vu_ok OR vu_ko) THEN RAISE EXCEPTION 'aucun jet'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (commissaire %, cible %, reussite vue %, echec vu %, chasse %)', a, b, vu_ok, vu_ko, r;
END $$;
