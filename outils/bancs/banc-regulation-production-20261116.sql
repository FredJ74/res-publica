-- Banc annulé de la régulation de la production (16/11/2026), à jouer après la migration
-- 20261116020000_regulation_production_recolte.sql. Essais sur Arnie, puis exception qui annule tout.
DO $banc$
DECLARE a text; u text; r jsonb; pa0 int; pa1 int; t text := '';
BEGIN
  SELECT name, user_id::text INTO a, u FROM public.personnages_donnees WHERE name ILIKE 'Arnie%' AND user_id IS NOT NULL LIMIT 1;
  IF a IS NULL THEN RAISE EXCEPTION 'banc : Arnie introuvable'; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', u, true);
  PERFORM set_config('request.path', '/rpc/recolte_effectuer', true);
  -- Starovka, champ de pétrole, inventaire vide, 20 PA.
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'ville_a', current_building = 'zone-production',
         current_room = 'zone_recolte', pa = 20, inventory = '[]'::jsonb, poste = NULL WHERE name = a;
  DELETE FROM public.production_regulations WHERE pays = 'soviet' AND ville = 'ville_a';
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = a;
  r := public.recolte_effectuer('Pétrole', 2, 0);
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = a;
  t := t || ' | récolte ok=' || (r->>'ok') || ' q=' || (r->>'quantite') || ' pa ' || pa0 || '->' || pa1;
  r := public.recolte_effectuer('Pétrole', 1, 0); r := public.recolte_effectuer('Pétrole', 1, 0);
  t := t || ' | 3e récolte ok=' || (r->>'ok');
  -- Régulation : maximum 3 par joueur.
  INSERT INTO public.production_regulations (pays, ville, matiere, max_par_joueur) VALUES ('soviet', 'ville_a', 'Pétrole', 3);
  r := public.recolte_effectuer('Pétrole', 1, 0);
  t := t || ' | 4e refus=' || coalesce(r->>'raison', 'aucun');
  -- Plafond ville atteint.
  UPDATE public.production_regulations SET max_par_joueur = NULL, plafond_ville = 3 WHERE pays = 'soviet' AND ville = 'ville_a';
  r := public.recolte_effectuer('Pétrole', 1, 0);
  t := t || ' | plafond ville refus=' || coalesce(r->>'raison', 'aucun');
  -- Lecture.
  r := public.regulation_production_lire();
  t := t || ' | lire adjoint=' || (r->>'est_adjoint') || ' ville_jour=' || (r#>>'{matieres,0,recoltes_ville_jour}') || ' par_pa=' || (r#>>'{matieres,0,par_pa}');
  -- Fixer : non adjoint refusé.
  r := public.regulation_production_fixer('Pétrole', 5, NULL);
  t := t || ' | fixer non-adjoint=' || coalesce(r->>'raison', 'ok');
  -- Prix : trading et fournisseurs étrangers.
  t := t || ' | prix soviet pétrole=' || (SELECT prix_base FROM public.ressources_economie_pays('soviet') WHERE cle = 'petrole')
         || ' fournisseur soviet=' || (SELECT prix_unitaire FROM public.fournisseurs_etrangers() WHERE pays = 'soviet' AND ressource = 'petrole');
  RAISE EXCEPTION 'BANC_RESULTAT%', t;
END $banc$;
