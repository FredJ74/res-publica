-- Banc annule des fermes, des oeufs, de la distillerie et du fourreur de Sovarka (a jouer concatene derriere la
-- migration 20261110123000, sans BEGIN/COMMIT). Se termine toujours par une exception : rien ne reste.
DO $banc$
DECLARE u uuid; r1 jsonb; r2 jsonb; r3 jsonb; r4 jsonb; r5 jsonb; r6 jsonb; r7 jsonb; r8 jsonb; r9 jsonb; r10 jsonb; r11 jsonb;
        inv jsonb; pa0 integer; b0 integer; v_fonds text; n integer;
BEGIN
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'ville_a', current_building = 'ferme-starovka', current_room = 'cour_ferme',
    current_street = NULL, pa = 20, inventory = '[]'::jsonb WHERE name = 'Arnie';
  SELECT pa, coalesce(bonus_pa_differe, 0) INTO pa0, b0 FROM public.personnages_donnees WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/sovarka_ferme_travailler', true);  -- sinon la garde d'inventaire annule les depots
  SET LOCAL ROLE authenticated;
  r1 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f001', 'renne');
  r2 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f001', 'renne');
  r3 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f002', 'traire');
  r4 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f003', 'oeufs');
  RESET ROLE;
  IF (r1->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'renne: %', r1; END IF;
  IF (r2->>'ok')::boolean IS NOT TRUE OR (SELECT pa FROM public.personnages_donnees WHERE name = 'Arnie') <> pa0 - 6 THEN RAISE EXCEPTION 'rejeu renne: %', r2; END IF;
  IF r4->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'oeufs a Starovka: %', r4; END IF;
  SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = 'Arnie';
  IF public.inventaire_quantite(inv, 'viande') <> 3 OR public.inventaire_quantite(inv, 'textile') <> 2 OR public.inventaire_quantite(inv, 'bois') <> 1
     OR public.inventaire_quantite(inv, 'laitages') <> 2 THEN RAISE EXCEPTION 'produits Starovka: %', inv; END IF;

  UPDATE public.personnages_donnees SET current_city = 'ville_b', current_building = 'ferme-krasnov' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  r5 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f004', 'oeufs');
  r6 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f005', 'oeufs');
  r7 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f006', 'poulet');
  r8 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f007', 'lapin');
  r9 := public.sovarka_ferme_travailler('00000000-0000-4000-8000-00000000f008', 'legumes');
  r10 := public.sovarka_oeufs_manger('00000000-0000-4000-8000-00000000f009');
  r11 := public.sovarka_oeufs_manger('00000000-0000-4000-8000-00000000f009');
  RESET ROLE;
  IF (r5->>'ok')::boolean IS NOT TRUE OR (r6->>'ok')::boolean IS NOT TRUE OR (r7->>'ok')::boolean IS NOT TRUE
     OR (r8->>'ok')::boolean IS NOT TRUE OR (r9->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'Krasnov: % % % % %', r5, r6, r7, r8, r9; END IF;
  IF (r10->>'ok')::boolean IS NOT TRUE OR (r11->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'manger oeufs: % / %', r10, r11; END IF;
  SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = 'Arnie';
  IF public.inventaire_quantite(inv, 'oeufs') <> 1 OR public.inventaire_quantite(inv, 'viande') <> 6 OR public.inventaire_quantite(inv, 'textile') <> 3
     OR public.inventaire_quantite(inv, 'fruits_legumes') <> 1 THEN RAISE EXCEPTION 'produits Krasnov: %', inv; END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = 'Arnie') <> pa0 - 6 - 2 - 2 - 2 - 1 THEN RAISE EXCEPTION 'PA Krasnov'; END IF;
  IF (SELECT bonus_pa_differe FROM public.personnages_donnees WHERE name = 'Arnie') <> least(30, b0 + 2) THEN RAISE EXCEPTION 'bonus oeufs'; END IF;

  -- Maisons : Stepan peut demander les oeufs (2 unites = 6 oeufs), Dolgor 2 viandes.
  SELECT count(*) INTO n FROM jsonb_array_elements(public.sovarka_maison_interne('ville_b', 'maison-krasnov')->'besoins') e
   WHERE EXISTS (SELECT 1 FROM public.ressources_economie r WHERE r.cle = e->>'cle') OR e->>'cle' IN ('oeufs', 'vodka');
  IF n <> 4 THEN RAISE EXCEPTION 'besoins Krasnov tirables: %', n; END IF;
  IF NOT (public.sovarka_maison_interne('ville_a', 'maison-starovka')->'besoins' @> '[{"cle":"viande","qte":2}]') THEN RAISE EXCEPTION 'Dolgor'; END IF;

  -- Type Distillerie refuse hors de la distillerie de Krasnov.
  SELECT id INTO v_fonds FROM public.entreprises WHERE data->>'proprietaire' = 'Arnie' AND coalesce((data->>'version')::numeric, 0) >= 2 LIMIT 1;
  IF v_fonds IS NOT NULL THEN
    SET LOCAL ROLE authenticated;
    r1 := public.fonds_definir_types('Arnie', v_fonds, ARRAY['distillerie']);
    RESET ROLE;
    IF r1->>'raison' IS DISTINCT FROM 'type_reserve_distillerie' THEN RAISE EXCEPTION 'type distillerie hors local: %', r1; END IF;
  END IF;
  RAISE EXCEPTION 'banc_ok fonds_teste=% inventaire=%', v_fonds IS NOT NULL, inv;
END $banc$;
