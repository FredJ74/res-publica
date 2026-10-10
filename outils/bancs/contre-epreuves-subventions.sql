-- CONTRE-EPREUVES DES SUBVENTIONS MUNICIPALES (10 octobre 2026)
--
-- POURQUOI CE FICHIER EXISTE. Cinquante-deux epreuves vertes ne prouvent rien si elles seraient
-- vertes AUSSI sur un code casse. Chaque sabotage ci-dessous retire UNE garantie, rejoue
-- l'epreuve qui la surveille, et EXIGE QU'ELLE ROUGISSE. Une contre-epreuve qui passe est un
-- echec : elle signifie que l'epreuve correspondante ne mesurait rien.
--
-- LE SABOTAGE NE RETAPE JAMAIS LE CORPS D'UNE FONCTION. Il relit la definition en base,
-- remplace un fragment exact, et leve si le remplacement n'a rien change -- sinon on croirait
-- avoir sabote en ayant execute le code intact, et la contre-epreuve rougirait pour rien.
--
-- TOUT EST ANNULE. Les trois blocs sont des transactions a part entiere qui se terminent par
-- ROLLBACK : les fonctions saboteees ne survivent pas une seconde a leur epreuve.
--
-- A LANCER DANS L'ORDRE, un bloc par appel. Chacun doit rendre « LA CONTRE-EPREUVE N EST
-- VERTE. » -- c'est-a-dire : le banc a bien rougi.
--
-- RESULTATS MESURES LE 10 OCTOBRE 2026, et ils valent d'etre lus pour ce qu'ils disent du cout
-- d'une garantie manquante :
--   1. Sans le verdict de territorialite, le maire de ville_a a subventionne un club de la
--      capitale -- la porte a rendu ok:true.
--   2. Sans la soustraction de la reserve, 7 000 FR ont ete ENGAGES sur une enveloppe de 5 000.
--   3. Sans le compare-and-swap (et sans sa garde amont), le club a recu 3 000 FR pour une
--      subvention de 1 500 : le double versement est reel, et c'est exactement ce qu'un
--      double-clic de president aurait produit.
-- Les quatre fragments saboteees ont ete verifies intacts en base apres les trois ROLLBACK.

-- =============================================================================================
-- CONTRE-EPREUVE 1 -- SANS LE VERDICT DE TERRITORIALITE, UN MAIRE SUBVENTIONNE UNE AUTRE VILLE
-- =============================================================================================
BEGIN;
DO $ce$
DECLARE v_def text; v_new text; v jsonb;
BEGIN
  v_def := pg_get_functiondef('public.subvention_proposer(text,text,numeric)'::regprocedure);
  v_new := replace(v_def, 'IF v_refus IS NOT NULL THEN', 'IF false THEN');
  IF v_new = v_def THEN RAISE EXCEPTION 'SABOTAGE 1 impossible : fragment absent'; END IF;
  EXECUTE v_new;

  -- LE DECOR D'ABORD, ET EN SERVEUR. Sans son poste, Marsault serait refuse pour AUTORITE et la
  -- contre-epreuve ne dirait rien du territoire -- c'est le piege des contre-epreuves
  -- « indecises », que les deux garde-fous ci-dessous distinguent d'un vrai echec.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId', 'Marsault'))::text
   WHERE id = 'republic_maire_ville_a';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','maire','name','Maire','city','ville_a')
   WHERE name = 'Marsault';
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 5000)
   WHERE id = 'republic_subventions_ville_a';

  PERFORM set_config('request.jwt.claims',
    '{"sub":"a5a55fc8-64fa-4406-b617-76439d1d4aac","role":"authenticated"}', true);
  PERFORM set_config('role', 'authenticated', true);

  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1000);

  -- L'EPREUVE 2 DU BANC 1 attend 'beneficiaire_hors_commune'. Sabotee, la porte ne doit PLUS le
  -- rendre : si elle le rend encore, l'epreuve surveillait autre chose que ce qu'on croit.
  IF v->>'raison' = 'beneficiaire_hors_commune' THEN
    RAISE EXCEPTION 'CONTRE-EPREUVE 1 ROUGE : le refus territorial survit au sabotage -- '
      'l''epreuve 2 du banc 1 ne mesure pas ce verdict';
  END IF;
  IF (v->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'CONTRE-EPREUVE 1 INDECISE : la porte sabotee refuse pour % -- le sabotage '
      'n''a pas atteint la garantie visee', coalesce(v->>'raison','?');
  END IF;
  RAISE EXCEPTION 'LA CONTRE-EPREUVE 1 EST VERTE : sans le verdict, le maire de ville_a a '
    'subventionne un club de la capitale. L''epreuve 2 du banc 1 mesure bien la territorialite.';
END $ce$;
ROLLBACK;

-- =============================================================================================
-- CONTRE-EPREUVE 2 -- SANS LA RESERVE, L'ENVELOPPE EST ENGAGEE DEUX FOIS
-- =============================================================================================
BEGIN;
DO $ce$
DECLARE v_def text; v_new text; v jsonb; v_total numeric;
BEGIN
  v_def := pg_get_functiondef('public.subvention_proposer(text,text,numeric)'::regprocedure);
  v_new := replace(v_def, 'v_dispo := v_solde - v_reserve;', 'v_dispo := v_solde;');
  IF v_new = v_def THEN RAISE EXCEPTION 'SABOTAGE 2 impossible : fragment absent'; END IF;
  EXECUTE v_new;

  PERFORM set_config('role', 'postgres', true);
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId','Ben','phase','mandat'))::text
   WHERE id = 'republic_maire_capitale';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','maire','name','Maire','city','capitale')
   WHERE name = 'Ben';
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 5000)
   WHERE id = 'republic_subventions_capitale';

  PERFORM set_config('request.jwt.claims',
    '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}', true);
  PERFORM set_config('role', 'authenticated', true);

  PERFORM public.subvention_proposer('club_football', 'olympique-luthecia', 3000);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 4000);

  PERFORM set_config('role', 'postgres', true);
  SELECT coalesce(sum(montant),0) INTO v_total FROM public.subventions_municipales
   WHERE ville = 'capitale' AND statut = 'proposee';

  -- L'EPREUVE 13 DU BANC 1 attend 'fonds_insuffisants' sur la troisieme proposition. Sabotee,
  -- la porte doit laisser engager plus que l'enveloppe.
  IF v->>'raison' = 'fonds_insuffisants' THEN
    RAISE EXCEPTION 'CONTRE-EPREUVE 2 ROUGE : le refus de sur-reservation survit au sabotage';
  END IF;
  IF v_total <= 5000 THEN
    RAISE EXCEPTION 'CONTRE-EPREUVE 2 INDECISE : % engage sur 5000, la sur-reservation n''a pas '
      'eu lieu (verdict : %)', v_total, coalesce(v->>'raison','ok');
  END IF;
  RAISE EXCEPTION 'LA CONTRE-EPREUVE 2 EST VERTE : sans la reserve, % FR ont ete engages sur une '
    'enveloppe de 5000. Les epreuves 13 et 17 du banc 1 mesurent bien la reserve.', v_total;
END $ce$;
ROLLBACK;

-- =============================================================================================
-- CONTRE-EPREUVE 3 -- SANS LE COMPARE-AND-SWAP, UNE SUBVENTION EST VERSEE DEUX FOIS
-- =============================================================================================
BEGIN;
DO $ce$
DECLARE v_def text; v_new text; v jsonb; v_id text; v_club numeric;
BEGIN
  v_def := pg_get_functiondef('public.subvention_repondre(text,text)'::regprocedure);
  v_new := replace(v_def,
    'SET statut = v_statut, clos_par = v_moi, clos_le = now()
   WHERE id = p_id AND statut = ''proposee'';',
    'SET statut = v_statut, clos_par = v_moi, clos_le = now()
   WHERE id = p_id;');
  IF v_new = v_def THEN RAISE EXCEPTION 'SABOTAGE 3 impossible : fragment absent'; END IF;
  EXECUTE v_new;

  -- ET LE GARDE-FOU AMONT AUSSI. `deja_close` est verifie avant le CAS : sans le retirer, la
  -- seconde reponse serait arretee la, et on ne saurait pas si le CAS protege quoi que ce soit.
  v_def := pg_get_functiondef('public.subvention_repondre(text,text)'::regprocedure);
  v_new := replace(v_def, 'IF r.statut <> ''proposee'' THEN', 'IF false THEN');
  IF v_new = v_def THEN RAISE EXCEPTION 'SABOTAGE 3b impossible : fragment absent'; END IF;
  EXECUTE v_new;

  PERFORM set_config('role', 'postgres', true);
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId','Ben','phase','mandat'))::text
   WHERE id = 'republic_maire_capitale';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','maire','name','Maire','city','capitale')
   WHERE name = 'Ben';
  INSERT INTO public.presidents_clubs (id, data, updated_at)
  VALUES ('olympique-luthecia', jsonb_build_object('president','May'), now())
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 5000)
   WHERE id = 'republic_subventions_capitale';

  PERFORM set_config('request.jwt.claims',
    '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}', true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1500);
  v_id := v->>'id';

  PERFORM set_config('request.jwt.claims',
    '{"sub":"3d91b1fa-a22d-41ae-82cf-fef98194b10a","role":"authenticated"}', true);
  PERFORM public.subvention_repondre(v_id, 'accepter');
  v := public.subvention_repondre(v_id, 'accepter');

  PERFORM set_config('role', 'postgres', true);
  SELECT (data->>'caisse')::numeric INTO v_club FROM public.budgets_clubs
   WHERE id = 'olympique-luthecia';

  -- LES EPREUVES 8 ET 10 DU BANC 2 attendent 'deja_close' et une caisse inchangee a 1500.
  IF v->>'raison' = 'deja_close' THEN
    RAISE EXCEPTION 'CONTRE-EPREUVE 3 ROUGE : deja_close survit au sabotage'; END IF;
  IF v_club <= 1500 THEN
    RAISE EXCEPTION 'CONTRE-EPREUVE 3 INDECISE : la caisse vaut % -- le double versement n''a '
      'pas eu lieu (verdict : %)', v_club, coalesce(v->>'raison','ok'); END IF;
  RAISE EXCEPTION 'LA CONTRE-EPREUVE 3 EST VERTE : sans le compare-and-swap, le club a recu % FR '
    'pour une subvention de 1500. Les epreuves 8 et 10 du banc 2 mesurent bien l''unicite de la '
    'transition.', v_club;
END $ce$;
ROLLBACK;
