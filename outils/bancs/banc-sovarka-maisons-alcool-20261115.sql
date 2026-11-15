-- Banc annulé (lève une exception à la fin) : la vodka demandée accepte l'alcool de l'entrepôt, l'alcool demandé
-- accepte la vodka. Jouer APRÈS le corps de la migration 20261115020000 (même transaction, sans BEGIN/COMMIT).
-- Attendu : stepan=t (alcool rendu pour « 1 bouteille de vodka »), kouzma=t (vodka rendue pour « 1 alcool »),
-- bois_refuse=service_incomplet (les autres clés restent exactes), inventaire vidé des bouteilles.
DO $banc$
DECLARE pj text; uid text; r1 jsonb; r2 jsonb; r3 jsonb; inv1 jsonb; inv2 jsonb;
BEGIN
  SELECT p.name, p.user_id::text INTO pj, uid FROM public.personnages p JOIN public.personnages_donnees d ON d.name = p.name
   WHERE p.user_id IS NOT NULL AND d.country = 'soviet' LIMIT 1;
  IF pj IS NULL THEN RAISE EXCEPTION 'BANC : aucun PJ de Sovarka'; END IF;
  DELETE FROM public.sovarka_maisons_hospitalite WHERE personnage = pj AND jour = public.sovarka_jour_paris();
  DELETE FROM public.sovarka_maisons_demandes WHERE personnage = pj;

  -- 1. Stepan demande la vodka ; le PJ n'a que l'alcool de l'entrepôt.
  UPDATE public.personnages_donnees SET current_city = 'ville_b', current_building = 'maison-krasnov', pa = 20,
    inventory = '[{"name":"Alcool","stackKey":"alcool","stackable":true,"qty":1}]'::jsonb WHERE name = pj;
  INSERT INTO public.sovarka_maisons_demandes VALUES (pj, 'maison-krasnov', '{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}', now() + interval '1 hour');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/sovarka_maison_agir', true);
  PERFORM set_config('role', 'authenticated', true);
  r1 := public.sovarka_maison_agir('banc-alcool-1', 'service');
  PERFORM set_config('role', 'postgres', true);
  SELECT inventory INTO inv1 FROM public.personnages_donnees WHERE name = pj;

  -- 2. Kouzma demande l'alcool ; le PJ n'a que de la vodka (autre jour d'hospitalité simulé).
  DELETE FROM public.sovarka_maisons_hospitalite WHERE personnage = pj AND jour = public.sovarka_jour_paris();
  DELETE FROM public.hotel_nuitees WHERE building_id = 'maison-krasnov' AND personnage_id = (SELECT id FROM public.personnages_donnees WHERE name = pj);
  UPDATE public.personnages_donnees SET current_building = 'maison-krasnov-eglise',
    inventory = '[{"name":"Vodka","stackKey":"vodka","stackable":true,"qty":1},{"name":"Bois","stackKey":"bois","stackable":true,"qty":1}]'::jsonb WHERE name = pj;
  INSERT INTO public.sovarka_maisons_demandes VALUES (pj, 'maison-krasnov-eglise', '{"cle":"alcool","qte":1,"label":"1 alcool"}', now() + interval '1 hour');
  PERFORM set_config('role', 'authenticated', true);
  r2 := public.sovarka_maison_agir('banc-alcool-2', 'service');
  PERFORM set_config('role', 'postgres', true);
  SELECT inventory INTO inv2 FROM public.personnages_donnees WHERE name = pj;

  -- 3. Une autre clé reste exacte : 3 bois demandés, 1 bois possédé.
  DELETE FROM public.sovarka_maisons_hospitalite WHERE personnage = pj AND jour = public.sovarka_jour_paris();
  INSERT INTO public.sovarka_maisons_demandes VALUES (pj, 'maison-krasnov-eglise', '{"cle":"bois","qte":3,"label":"3 bois"}', now() + interval '1 hour')
    ON CONFLICT (personnage, maison) DO UPDATE SET service = EXCLUDED.service, expire_le = EXCLUDED.expire_le;
  PERFORM set_config('role', 'authenticated', true);
  r3 := public.sovarka_maison_agir('banc-alcool-3', 'service');
  PERFORM set_config('role', 'postgres', true);

  RAISE EXCEPTION 'BANC stepan=% (%) inv1=% | kouzma=% (%) inv2=% | bois_refuse=%',
    r1->>'ok', coalesce(r1->>'raison', ''), inv1, r2->>'ok', coalesce(r2->>'raison', ''), inv2, r3->>'raison';
END $banc$;
