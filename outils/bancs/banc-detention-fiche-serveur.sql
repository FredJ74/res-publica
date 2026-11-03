-- Banc annulé de 20261103124500_detention_fiche_serveur_seul : à jouer APRÈS la migration,
-- dans la même transaction ; l'exception finale annule tout. Personnage d'essai : Angie Porcelana.
DO $$
DECLARE u uuid; n text := 'Angie Porcelana'; e jsonb; q jsonb; m int;
  peine jsonb := '{"jours": 5, "jourFin": 99, "raison": "Banc", "debutTs": 1790000000000, "city": "capitale", "country": "republic"}';
BEGIN
  -- Sauvegarde générale de l'écran : pas un appel /rpc/.
  PERFORM set_config('request.path', '/personnages', true);
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;

  -- 1. Détenu (posé par le serveur) : l'écran vide la peine et le QHS, change son moral.
  UPDATE public.personnages_donnees SET est_emprisonne = peine,
         detention_qhs = '{"enQHS": true, "paLimite1Jour": false}', moral = 40 WHERE name = n;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  UPDATE public.personnages SET est_emprisonne = NULL, detention_qhs = NULL, moral = 41 WHERE name = n;
  RESET ROLE;
  SELECT est_emprisonne, detention_qhs, moral INTO e, q, m FROM public.personnages_donnees WHERE name = n;
  IF e IS DISTINCT FROM peine THEN RAISE EXCEPTION 'banc 1a: peine effacée par l''écran: %', e; END IF;
  IF q IS NULL THEN RAISE EXCEPTION 'banc 1b: QHS effacé par l''écran'; END IF;
  IF m <> 41 THEN RAISE EXCEPTION 'banc 1c: champ ordinaire refusé (moral %)', m; END IF;

  -- 2. L'écran raccourcit la peine et pose motifDesertionSeul (fusion à trois voies).
  SET LOCAL ROLE authenticated;
  UPDATE public.personnages
     SET est_emprisonne = peine || '{"jours": 0.01, "motifDesertionSeul": true}',
         fiche_base = jsonb_build_object('est_emprisonne', peine)
   WHERE name = n;
  RESET ROLE;
  SELECT est_emprisonne INTO e FROM public.personnages_donnees WHERE name = n;
  IF e IS DISTINCT FROM peine THEN RAISE EXCEPTION 'banc 2: peine réécrite par l''écran: %', e; END IF;

  -- 3. Libre : l'écran ne peut pas non plus s'inscrire une peine.
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, detention_qhs = NULL WHERE name = n;
  SET LOCAL ROLE authenticated;
  UPDATE public.personnages SET est_emprisonne = peine WHERE name = n;
  RESET ROLE;
  SELECT est_emprisonne INTO e FROM public.personnages_donnees WHERE name = n;
  IF e IS NOT NULL THEN RAISE EXCEPTION 'banc 3: peine posée par l''écran'; END IF;

  -- 4. Une fonction serveur écrit toujours la peine (constat purgée refusé : peine absente).
  SET LOCAL ROLE authenticated;
  IF public.detention_clore_purgee()->>'raison' IS DISTINCT FROM 'non_detenu' THEN
    RAISE EXCEPTION 'banc 4: clôture sans peine';
  END IF;
  RESET ROLE;
  RAISE EXCEPTION 'BANC OK : peine et QHS conservés, moral écrit, raccourci refusé, inscription refusée';
END $$;
