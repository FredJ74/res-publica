-- Banc annule : perte de jouissance des equipements (migration 20261103040000).
-- A jouer APRES la migration (ou dans la meme transaction). Rien ne reste : exception finale.
DO $$
DECLARE r jsonb; v_id uuid; v_flag timestamptz; n integer; v_pj text;
BEGIN
  SELECT name INTO v_pj FROM public.personnages_donnees WHERE name = 'Jean Jaaj';
  IF v_pj IS NULL THEN RAISE EXCEPTION 'banc: Jean Jaaj introuvable'; END IF;
  -- 1. Equipement dans un bureau sans bail : averti, delai pose.
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet)
  VALUES (v_pj, 'republic', 'capitale', 'centre-affaires', 'banc_bureau_sans_bail', 'box-internet', '{"name":"Box banc"}')
  RETURNING id INTO v_id;
  r := public.equipements_jouissance_nuit();
  SELECT jouissance_perdue_le INTO v_flag FROM public.equipements_installes WHERE id = v_id;
  IF v_flag IS NULL OR (r->>'avertis')::int < 1 THEN RAISE EXCEPTION 'banc 1: pas averti %', r; END IF;
  -- 2. Rejeu la meme nuit : rien ne change, pas de saisie.
  r := public.equipements_jouissance_nuit();
  IF NOT EXISTS (SELECT 1 FROM public.equipements_installes WHERE id = v_id) THEN RAISE EXCEPTION 'banc 2: saisi trop tot'; END IF;
  -- 3. 48 h plus tard : saisi par la commune (bureau du centre d'affaires).
  UPDATE public.equipements_installes SET jouissance_perdue_le = now() - interval '48 hours' WHERE id = v_id;
  r := public.equipements_jouissance_nuit();
  IF EXISTS (SELECT 1 FROM public.equipements_installes WHERE id = v_id) THEN RAISE EXCEPTION 'banc 3: pas saisi %', r; END IF;
  SELECT count(*) INTO n FROM public.equipements_saisis WHERE ancien_proprietaire = v_pj AND piece = 'banc_bureau_sans_bail'
    AND nouveau_proprietaire = 'ville:republic:capitale';
  IF n <> 1 THEN RAISE EXCEPTION 'banc 3: journal de saisie %', n; END IF;
  -- 4. Bail valide (bureau prestige de Jean Jaaj) : jamais averti, delai efface s'il existait.
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet, jouissance_perdue_le)
  VALUES (v_pj, 'republic', 'capitale', 'centre-affaires', 'bureau_prestige', 'box-internet', '{"name":"Box banc"}', now())
  RETURNING id INTO v_id;
  r := public.equipements_jouissance_nuit();
  SELECT jouissance_perdue_le INTO v_flag FROM public.equipements_installes WHERE id = v_id;
  IF v_flag IS NOT NULL OR (r->>'retablis')::int < 1 THEN RAISE EXCEPTION 'banc 4: delai non efface %', r; END IF;
  -- 5. Lot dynamique d'un terrain detenu par un PJ : transfert au proprietaire du terrain.
  IF public.local_proprietaire_foncier_interne('republic', 'capitale', 'centre-affaires', 'bureau_prestige') <> 'ville:republic:capitale' THEN
    RAISE EXCEPTION 'banc 5: foncier du centre d''affaires'; END IF;
  -- 6. Chef d'organisation proprietaire : a_moi.
  IF NOT public.equipement_a_moi_interne('orga:orga_1792355539137', (SELECT o.data::jsonb->>'chef' FROM public.organisations o WHERE o.id = 'orga_1792355539137')) THEN
    RAISE EXCEPTION 'banc 6: chef non reconnu'; END IF;
  IF public.equipement_a_moi_interne('orga:orga_1792355539137', 'Personne Inconnue') THEN RAISE EXCEPTION 'banc 6: tiers reconnu'; END IF;
  -- 7. Droits : la passe de nuit n'est pas executable par l'ecran.
  IF has_function_privilege('authenticated', 'public.equipements_jouissance_nuit()', 'EXECUTE') THEN RAISE EXCEPTION 'banc 7: nuit ouverte a l''ecran'; END IF;
  RAISE EXCEPTION 'BANC OK : rien ne doit rester';
END $$;
