-- ===========================================================================
-- BANC DU CATALOGUE DES ESCORTS (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- TOUT EST ANNULE : le bloc se termine par RAISE EXCEPTION, donc le personnage
-- de test n'existe jamais. Il emprunte un compte anonyme sans personnage, comme
-- le banc de l'Assemblee -- exiger_acteur reclame une identite reelle et un
-- compte ne porte qu'un personnage.
--
-- CE QU'IL PROUVE :
--   E1  en Republia, l'agence rend ses 7 identites : 4 femmes, 3 hommes
--   E2  le MEME joueur a Novomirsk ne voit AUCUNE escort et AUCUNE agence
--       -- la regle de socle appliquee : un casting n'existe que dans son empire,
--       et un empire sans casting est un etat VALIDE, pas une erreur
--   E3  la RPC ne prend aucun argument d'empire : il est resolu au serveur
--       depuis la position du joueur, jamais transmis par le navigateur
--
-- RESULTAT DU 1er OCTOBRE 2026 :
--   E1 en Republia      ok=true agence=Agence Roxane Velours escorts=7
--   E1 femmes=4
--   E1 hommes=3
--   E1 premiere femme    = Natacha
--   E2 a Novomirsk      ok=true pays=soviet agence=(aucune) escorts=0
--   E3 RPC sans argument d'empire : t
-- ===========================================================================
DO $banc$
DECLARE
  R text := ''; A text := 'zzEscortBanc'; U uuid; v jsonb; n integer;
BEGIN
  SELECT u.id INTO U FROM auth.users u
    LEFT JOIN public.personnages_donnees p ON p.user_id = u.id
   WHERE p.user_id IS NULL LIMIT 1;
  PERFORM set_config('request.jwt.claims',
          json_build_object('sub', U::text, 'role', 'authenticated')::text, true);

  -- E1 : un joueur qui se trouve en Republia
  INSERT INTO public.personnages_donnees (name, country, resources, current_building, current_room)
  VALUES (A, 'republic', jsonb_build_object('pa',20,'arg',9000,'liquide',9000),
          'hotel-republica', 'bar');
  v := public.escorts_agence();
  SELECT count(*) INTO n FROM jsonb_array_elements(v -> 'escorts');
  R := R || format('E1 en Republia      ok=%s agence=%s escorts=%s', v->>'ok', v->>'agence', n) || E'\n';
  SELECT count(*) INTO n FROM jsonb_array_elements(v->'escorts') e WHERE e->>'genre'='F';
  R := R || format('E1 femmes=%s', n) || E'\n';
  SELECT count(*) INTO n FROM jsonb_array_elements(v->'escorts') e WHERE e->>'genre'='H';
  R := R || format('E1 hommes=%s', n) || E'\n';
  R := R || format('E1 premiere femme    = %s',
        (SELECT e->>'nom' FROM jsonb_array_elements(v->'escorts') e
          WHERE e->>'genre'='F' LIMIT 1)) || E'\n';

  -- E2 : le MEME joueur, apres un voyage a Novomirsk. Aucun casting la-bas.
  UPDATE public.personnages_donnees SET country='soviet' WHERE name=A;
  v := public.escorts_agence();
  SELECT count(*) INTO n FROM jsonb_array_elements(v -> 'escorts');
  R := R || format('E2 a Novomirsk      ok=%s pays=%s agence=%s escorts=%s',
        v->>'ok', v->>'pays', coalesce(v->>'agence','(aucune)'), n) || E'\n';

  -- E3 : l'empire ne se transmet pas -- la RPC ne prend aucun argument
  SELECT count(*) INTO n FROM pg_proc p
   WHERE p.proname='escorts_agence' AND p.pronamespace='public'::regnamespace AND p.pronargs=0;
  R := R || format('E3 RPC sans argument d''empire : %s', n=1) || E'\n';

  RAISE EXCEPTION E'\n===== BANC CATALOGUE ESCORTS (tout annule) =====\n%', R;
END $banc$;
