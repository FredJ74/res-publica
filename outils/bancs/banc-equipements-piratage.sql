-- Banc annule (RAISE EXCEPTION 'BANC OK' final). A, connecte dans son bureau (INT 60 : 95 %), pirate un registre
-- (rapport par mail + dossier range), la banque de B, puis l'ordinateur de B et copie son dossier ; refus sans connexion.
DO $$
DECLARE a text; ua uuid; b text; r jsonb; v_essais integer; v_doss uuid; v_nb0 integer;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  INSERT INTO public.locations_actives (id, country, data) VALUES ('republic:banc-bureau:bureau_banc:capitale', 'republic', jsonb_build_object('locataire', 'pj:' || a))
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'ordinateur-complet', '{"id":"obj-ordi-banc-a","generique_id":"ordinateur-complet"}'),
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'box-internet', '{"id":"obj-box-banc-a","generique_id":"box-internet"}'),
    (b, 'republic', 'capitale', 'banc-bureau-b', 'bureau_b', 'ordinateur-complet', '{"id":"obj-ordi-banc-b","generique_id":"ordinateur-complet"}');
  INSERT INTO public.dossiers_informatiques (objet_id, support, type, titre, contenu, auteur)
  VALUES ('obj-ordi-banc-b', 'ordinateur', 'piratage', 'Secret de B', 'Le contenu secret de B', b) RETURNING id INTO v_doss;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'banc-bureau', current_room = 'bureau_banc',
    current_street = NULL, pa = 40, stats = jsonb_set(coalesce(stats, '{}'::jsonb), '{INT}', '60') WHERE name = a;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/pirater', true);
  SET LOCAL ROLE authenticated;
  v_essais := 0;
  LOOP v_essais := v_essais + 1; r := public.pirater('registre', 'armes', NULL); EXIT WHEN (r->>'reussi')::boolean OR v_essais >= 4; END LOOP;
  IF (r->>'reussi')::boolean IS NOT TRUE OR r->>'dossier' IS NULL THEN RESET ROLE; RAISE EXCEPTION 'registre: %', r; END IF;
  v_essais := 0;
  LOOP v_essais := v_essais + 1; r := public.pirater('banque', b, NULL); EXIT WHEN (r->>'reussi')::boolean OR v_essais >= 4; END LOOP;
  IF (r->>'reussi')::boolean IS NOT TRUE OR position(b IN r->>'texte') = 0 THEN RESET ROLE; RAISE EXCEPTION 'banque: %', r; END IF;
  v_essais := 0;
  LOOP v_essais := v_essais + 1; r := public.pirater('caserne', '', NULL); EXIT WHEN (r->>'reussi')::boolean OR v_essais >= 4; END LOOP;
  IF (r->>'reussi')::boolean IS NOT TRUE THEN RESET ROLE; RAISE EXCEPTION 'caserne: %', r; END IF;
  v_essais := 0;
  LOOP v_essais := v_essais + 1; r := public.pirater('ordinateur', b, NULL); EXIT WHEN (r->>'reussi')::boolean OR v_essais >= 4; END LOOP;
  IF (r->>'reussi')::boolean IS NOT TRUE OR jsonb_array_length(r->'dossiers') < 1 THEN RESET ROLE; RAISE EXCEPTION 'ordinateur: %', r; END IF;
  r := public.piratage_dossier_agir(b, v_doss, 'copier');
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'copie' IS NULL OR r->>'contenu' <> 'Le contenu secret de B' THEN RESET ROLE; RAISE EXCEPTION 'copier: %', r; END IF;
  r := public.piratage_dossier_agir(b, v_doss, 'detruire');
  IF r->>'raison' IS DISTINCT FROM 'acces_expire' THEN RESET ROLE; RAISE EXCEPTION 'second usage accepte: %', r; END IF;
  r := public.dossiers_lire();
  IF jsonb_array_length(r->'dossiers') < 4 THEN RESET ROLE; RAISE EXCEPTION 'dossiers: %', r; END IF;
  RESET ROLE;
  IF (SELECT count(*) FROM public.personnages_donnees, jsonb_array_elements(historique_crimes) t WHERE name = a AND t->>'acte' = 'pirater') < 4 THEN
    RAISE EXCEPTION 'traces de piratage absentes'; END IF;
  UPDATE public.personnages_donnees SET current_building = 'banc-ailleurs', current_room = 'salle' WHERE name = a;
  SET LOCAL ROLE authenticated;
  r := public.pirater('caserne', '', NULL);
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'pas_de_connexion' THEN RAISE EXCEPTION 'hors bureau: %', r; END IF;
  RAISE EXCEPTION 'BANC OK : registre, banque, caserne, ordinateur (copie unique), dossiers ranges, traces, refus hors bureau';
END $$;
