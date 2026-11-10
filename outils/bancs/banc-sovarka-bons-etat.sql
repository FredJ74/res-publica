-- Banc annule des bons d'Etat de Sovarka (a jouer concatene derriere la migration 20261110085000, sans BEGIN/COMMIT).
-- Arnie (seul PJ de Sovarka) est place au guichet de la Banque nationale de Novomirsk le temps du banc.
DO $banc$
DECLARE u uuid; liq0 numeric; res0 numeric; r jsonb; r2 jsonb; r3 jsonb; liq1 numeric; res1 numeric; banque0 numeric; banque1 numeric; pas jsonb; t jsonb;
BEGIN
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  UPDATE public.personnages_donnees SET current_building = 'banque-nationale', current_room = 'accueil_banque' WHERE name = 'Arnie';
  SELECT liquide INTO liq0 FROM public.personnages_donnees WHERE name = 'Arnie';
  SELECT (data->>'reserveJour')::numeric INTO res0 FROM public.budgets_nationaux WHERE id = 'soviet';
  t := public.sovarka_bons_etat_taux_interne();
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_bon_etat_souscrire('banc-bon-1', 1000);
  r2 := public.sovarka_bon_etat_souscrire('banc-bon-1', 1000);
  r3 := public.sovarka_bon_etat_souscrire('banc-bon-2', 999999999);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'souscription refusee: %', r; END IF;
  IF (r2->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu absent: %', r2; END IF;
  IF r3->>'raison' IS DISTINCT FROM 'fonds_insuffisants' THEN RAISE EXCEPTION 'fonds insuffisants non refuses: %', r3; END IF;
  SELECT liquide INTO liq1 FROM public.personnages_donnees WHERE name = 'Arnie';
  SELECT (data->>'reserveJour')::numeric INTO res1 FROM public.budgets_nationaux WHERE id = 'soviet';
  IF res1 - res0 <> 1000 THEN RAISE EXCEPTION 'tresor non credite: % -> %', res0, res1; END IF;
  IF (SELECT count(*) FROM public.sovarka_bons_etat WHERE souscripteur = 'Arnie') <> 1 THEN RAISE EXCEPTION 'double bon'; END IF;
  -- Echeance : Tresor suffisant
  UPDATE public.sovarka_bons_etat SET echeance = public.sovarka_jour_paris() WHERE requete = 'banc-bon-1';
  SELECT coalesce(sum(solde), 0) INTO banque0 FROM public.comptes_bancaires WHERE personnage = 'Arnie' AND banque = 'nationale';
  pas := public.sovarka_bons_etat_passe();
  SELECT coalesce(sum(solde), 0) INTO banque1 FROM public.comptes_bancaires WHERE personnage = 'Arnie' AND banque = 'nationale';
  IF (pas->>'rembourses')::int <> 1 OR (pas->>'planche_a_billets')::int <> 0 THEN RAISE EXCEPTION 'passe: %', pas; END IF;
  IF banque1 - banque0 <> round(1000 * (1 + (r->>'taux')::numeric / 100)) THEN RAISE EXCEPTION 'remboursement % (taux %)', banque1 - banque0, r->>'taux'; END IF;
  IF (public.sovarka_bons_etat_passe()->>'rembourses')::int <> 0 THEN RAISE EXCEPTION 'double remboursement'; END IF;
  -- Planche a billets : Tresor vide
  INSERT INTO public.sovarka_bons_etat (requete, souscripteur, montant, taux, indice_economie, ville, echeance)
  VALUES ('banc-bon-3', 'Arnie', 500, 3, 100, 'capitale', public.sovarka_jour_paris());
  UPDATE public.budgets_nationaux SET data = jsonb_set(data, '{reserveJour}', '0') WHERE id = 'soviet';
  SELECT coalesce(sum(solde), 0) INTO banque0 FROM public.comptes_bancaires WHERE personnage = 'Arnie' AND banque = 'nationale';
  pas := public.sovarka_bons_etat_passe();
  SELECT coalesce(sum(solde), 0) INTO banque1 FROM public.comptes_bancaires WHERE personnage = 'Arnie' AND banque = 'nationale';
  IF (pas->>'planche_a_billets')::int <> 1 OR banque1 - banque0 <> 450 THEN RAISE EXCEPTION 'planche: % / %', pas, banque1 - banque0; END IF;
  IF (SELECT (data->>'reserveJour')::numeric FROM public.budgets_nationaux WHERE id = 'soviet') <> 0 THEN RAISE EXCEPTION 'tresor debite par la planche'; END IF;
  -- Hors banque : refus
  UPDATE public.personnages_donnees SET current_building = 'mairie-capitale' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  r3 := public.sovarka_bon_etat_souscrire('banc-bon-4', 10);
  RESET ROLE;
  IF r3->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'hors banque: %', r3; END IF;
  RAISE EXCEPTION 'banc_ok taux=% indice=% liquide %->%', t->>'taux', t->>'indice', liq0, liq1;
END $banc$;
